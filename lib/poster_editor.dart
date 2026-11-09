import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'upgrade.dart';
import 'widgets.dart';

enum _El { photo, name, mobile, company, logo }

class _ElState {
  bool visible;
  double dx, dy, scale;
  _ElState(this.visible, this.dx, this.dy, this.scale);
  Map<String, dynamic> toJson() => {'v': visible, 'x': dx, 'y': dy, 's': scale};
}

Map<_El, _ElState> _defaults() => {
      _El.photo: _ElState(true, 0.04, 0.80, 1.0),
      _El.name: _ElState(true, 0.30, 0.80, 1.0),
      _El.mobile: _ElState(true, 0.30, 0.87, 1.0),
      _El.company: _ElState(true, 0.30, 0.93, 1.0),
      _El.logo: _ElState(false, 0.76, 0.03, 1.0),
    };

const _label = {_El.photo: 'Photo', _El.name: 'Name', _El.mobile: 'Mobile', _El.company: 'Company', _El.logo: 'Logo'};
const _colors = [Colors.white, Colors.black, Color(0xFFFFD54F), Color(0xFFFF8A65)];

/// Shows a poster (picture, or gradient with text) with the user's details on it.
/// Free: name and mobile in a fixed bar. Pro: photo, logo, name, mobile and company can be
/// shown, hidden, moved and resized freely.
class PosterEditor extends StatefulWidget {
  final Widget background;
  final String? usePath; // POST this before sharing, to count the use against the plan (null = do not count)
  final String fileTag;
  const PosterEditor({super.key, required this.background, this.usePath, this.fileTag = 'poster'});
  @override
  State<PosterEditor> createState() => _PosterEditorState();
}

class _PosterEditorState extends State<PosterEditor> {
  final _key = GlobalKey();
  final Map<_El, _ElState> st = _defaults();
  _El? selected;
  int colorIx = 0;
  bool textBg = true;
  File? logo, photo;
  bool busy = false;
  late final TextEditingController name, mobile, company;

  bool get pro => featureOn('poster_edit');

  @override
  void initState() {
    super.initState();
    final u = Api.user ?? {};
    name = TextEditingController(text: (u['name'] ?? '').toString());
    mobile = TextEditingController(text: (u['mobile'] ?? '').toString());
    final co = u['company'];
    company = TextEditingController(text: co is Map ? (co['name'] ?? '').toString() : '');
    for (final c in [name, mobile, company]) {
      c.addListener(() => setState(() {}));
    }
    _restore();
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    company.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final lp = sp.getString('poster_logo');
      if (lp != null && File(lp).existsSync()) logo = File(lp);
      final pp = sp.getString('poster_photo');
      if (pp != null && File(pp).existsSync()) photo = File(pp);
      final raw = sp.getString('poster_layout');
      if (raw != null) {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        colorIx = (m['c'] as int?) ?? 0;
        textBg = (m['b'] as bool?) ?? true;
        for (final e in _El.values) {
          final s = m[e.name];
          if (s is Map) st[e] = _ElState(s['v'] == true, (s['x'] as num).toDouble(), (s['y'] as num).toDouble(), (s['s'] as num).toDouble());
        }
      }
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString('poster_layout', jsonEncode({'c': colorIx, 'b': textBg, for (final e in _El.values) e.name: st[e]!.toJson()}));
    } catch (_) {}
  }

  Future<File?> _pick(String prefKey) async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 90);
      if (x == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final f = await File(x.path).copy('${dir.path}/$prefKey${DateTime.now().millisecondsSinceEpoch}.png');
      final sp = await SharedPreferences.getInstance();
      await sp.setString(prefKey, f.path);
      return f;
    } catch (_) {
      if (mounted) toast(context, 'Could not use that picture.');
      return null;
    }
  }

  Future<void> _share() async {
    if (busy) return;
    setState(() {
      busy = true;
      selected = null;
    });
    try {
      final p = widget.usePath;
      if (p != null) await Api.post(p, {});
      await WidgetsBinding.instance.endOfFrame;
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${widget.fileTag}_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)]);
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Could not prepare the poster. Please try again.');
    }
    if (mounted) setState(() => busy = false);
  }

  Widget _chip(Widget child) {
    if (!textBg) return child;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
      child: child,
    );
  }

  Widget _element(_El e) {
    final s = st[e]!;
    final tc = _colors[colorIx];
    final shadow = textBg ? null : const [Shadow(blurRadius: 4, color: Colors.black87)];
    switch (e) {
      case _El.photo:
        final url = (Api.user?['photo_url'] ?? '').toString();
        final size = 64.0 * s.scale;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), color: Colors.black26),
          child: ClipOval(
            child: photo != null
                ? Image.file(photo!, fit: BoxFit.cover)
                : (url.isNotEmpty ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)) : const Icon(Icons.person, color: Colors.white)),
          ),
        );
      case _El.name:
        return _chip(Text(name.text, style: TextStyle(color: tc, fontSize: 20 * s.scale, fontWeight: FontWeight.w800, shadows: shadow)));
      case _El.mobile:
        return _chip(Text(mobile.text, style: TextStyle(color: tc, fontSize: 16 * s.scale, fontWeight: FontWeight.w600, shadows: shadow)));
      case _El.company:
        return _chip(Text(company.text, style: TextStyle(color: tc, fontSize: 14 * s.scale, shadows: shadow)));
      case _El.logo:
        return logo == null ? const SizedBox.shrink() : SizedBox(width: 80.0 * s.scale, child: Image.file(logo!, fit: BoxFit.contain));
    }
  }

  bool _shown(_El e) {
    if (!st[e]!.visible) return false;
    if (e == _El.logo && logo == null) return false;
    if (e == _El.name) return name.text.trim().isNotEmpty;
    if (e == _El.mobile) return mobile.text.trim().isNotEmpty;
    if (e == _El.company) return company.text.trim().isNotEmpty;
    return true;
  }

  Widget _freeFooter() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0B3B37),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        if (mobile.text.trim().isNotEmpty) Text(mobile.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ]),
    );
  }

  Widget _canvas() {
    if (!pro) {
      return RepaintBoundary(key: _key, child: Column(children: [widget.background, _freeFooter()]));
    }
    return RepaintBoundary(
      key: _key,
      child: Stack(children: [
        widget.background,
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth, h = c.maxHeight;
            return Stack(clipBehavior: Clip.none, children: [
              // tapping the empty area clears the selection
              Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => setState(() => selected = null))),
              for (final e in _El.values)
                if (_shown(e))
                  Positioned(
                    left: st[e]!.dx * w,
                    top: st[e]!.dy * h,
                    child: GestureDetector(
                      onTap: () => setState(() => selected = e),
                      onPanStart: (_) => setState(() => selected = e),
                      onPanUpdate: (d) => setState(() {
                        st[e]!.dx = (st[e]!.dx + d.delta.dx / w).clamp(-0.05, 0.98).toDouble();
                        st[e]!.dy = (st[e]!.dy + d.delta.dy / h).clamp(-0.05, 0.98).toDouble();
                      }),
                      onPanEnd: (_) => _save(),
                      child: Container(
                        decoration: selected == e ? BoxDecoration(border: Border.all(color: Colors.amberAccent, width: 2)) : null,
                        child: _element(e),
                      ),
                    ),
                  ),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _proControls() {
    final sel = selected;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Show on poster', style: TextStyle(fontWeight: FontWeight.w700)),
      Wrap(spacing: 8, children: [
        for (final e in _El.values)
          FilterChip(
            label: Text(_label[e]!),
            selected: st[e]!.visible,
            onSelected: (v) async {
              if (e == _El.logo && v && logo == null) {
                final f = await _pick('poster_logo');
                if (f == null) return;
                logo = f;
              }
              setState(() {
                st[e]!.visible = v;
                selected = v ? e : null;
              });
              _save();
            },
          ),
      ]),
      const SizedBox(height: 6),
      const Text('Drag anything on the poster to move it. Tap it to resize.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      if (sel != null)
        Row(children: [
          Text('Size: ${_label[sel]}'),
          Expanded(
            child: Slider(
              min: 0.5,
              max: 3.0,
              value: st[sel]!.scale.clamp(0.5, 3.0).toDouble(),
              onChanged: (v) => setState(() => st[sel]!.scale = v),
              onChangeEnd: (_) => _save(),
            ),
          ),
        ]),
      const SizedBox(height: 6),
      Row(children: [
        const Text('Text colour  '),
        for (int i = 0; i < _colors.length; i++)
          GestureDetector(
            onTap: () {
              setState(() => colorIx = i);
              _save();
            },
            child: Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: _colors[i], shape: BoxShape.circle, border: Border.all(color: colorIx == i ? Colors.teal : Colors.black26, width: colorIx == i ? 3 : 1)),
            ),
          ),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Dark background behind text'),
        value: textBg,
        onChanged: (v) {
          setState(() => textBg = v);
          _save();
        },
      ),
      Wrap(spacing: 8, children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.person),
          label: const Text('Change photo'),
          onPressed: () async {
            final f = await _pick('poster_photo');
            if (f != null) setState(() => photo = f);
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.business),
          label: Text(logo == null ? 'Add logo' : 'Change logo'),
          onPressed: () async {
            final f = await _pick('poster_logo');
            if (f != null) {
              setState(() {
                logo = f;
                st[_El.logo]!.visible = true;
              });
              _save();
            }
          },
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text('Reset'),
          onPressed: () {
            setState(() {
              st
                ..clear()
                ..addAll(_defaults());
              colorIx = 0;
              textBg = true;
              selected = null;
              photo = null;
            });
            _save();
          },
        ),
      ]),
      const SizedBox(height: 10),
      field(name, 'Name on poster'),
      field(mobile, 'Mobile on poster', type: TextInputType.phone),
      field(company, 'Company on poster'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _canvas(),
      const SizedBox(height: 14),
      if (pro)
        _proControls()
      else
        Card(
          color: const Color(0xFFFFF4E5),
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Your name and mobile are added automatically.'),
            subtitle: const Text('With Pro you can add your photo and logo, and move, resize or hide anything on the poster.'),
            trailing: TextButton(onPressed: () => goUpgrade(context, 'Poster editing (photo, logo and layout) is available on the Pro plan.'), child: const Text('Get Pro')),
          ),
        ),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: busy ? null : _share, icon: const Icon(Icons.share), label: Text(busy ? 'Please wait...' : 'Share poster')),
    ]);
  }
}
