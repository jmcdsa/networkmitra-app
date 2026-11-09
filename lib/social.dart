import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'widgets.dart';

/// Posters and ready message templates.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Posters and templates'),
          bottom: const TabBar(tabs: [Tab(text: 'Posters'), Tab(text: 'Message templates')]),
        ),
        body: const TabBarView(children: [_PostersTab(), _TemplatesTab()]),
      ),
    );
  }
}

class _PostersTab extends StatefulWidget {
  const _PostersTab();
  @override
  State<_PostersTab> createState() => _PostersTabState();
}

class _PostersTabState extends State<_PostersTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;
  String cat = 'All';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('posters');
      items = asList(d['items']);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    if (items.isEmpty) return const Center(child: Text('No posters yet. Please check again soon.'));
    final cats = ['All', ...{...items.map((e) => e['category'].toString())}];
    final shown = cat == 'All' ? items : items.where((e) => e['category'] == cat).toList();
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: cats
              .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c)),
                  ))
              .toList(),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9),
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final p = shown[i];
              return InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PosterScreen(poster: p))),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: Image.network(p['image_url'].toString(), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(p['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    ]);
  }
}

/// One poster with my photo, name and number at the bottom, ready to share.
class PosterScreen extends StatefulWidget {
  final Map<String, dynamic> poster;
  const PosterScreen({super.key, required this.poster});
  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final _key = GlobalKey();
  late final TextEditingController name;
  late final TextEditingController mobile;
  late final TextEditingController company;
  bool busy = false;

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
  }

  @override
  void dispose() {
    name.dispose();
    mobile.dispose();
    company.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await Api.post('posters/${widget.poster['id']}/use', {}); // counts against the plan; a limit opens the Upgrade page
      final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await b.toImage(pixelRatio: 3);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/poster_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(f.path)]);
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Could not prepare the poster. Please try again.');
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final photo = (Api.user?['photo_url'] ?? '').toString();
    return Scaffold(
      appBar: AppBar(title: Text(widget.poster['title'].toString())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RepaintBoundary(
          key: _key,
          child: Column(children: [
            Image.network(widget.poster['image_url'].toString(), width: double.infinity, fit: BoxFit.fitWidth,
                loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
                errorBuilder: (_, __, ___) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image)))),
            Container(
              color: const Color(0xFF0B3B37),
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                    if (mobile.text.trim().isNotEmpty) Text(mobile.text, style: const TextStyle(color: Colors.white, fontSize: 15)),
                    if (company.text.trim().isNotEmpty) Text(company.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        field(name, 'Name on poster'),
        field(mobile, 'Mobile on poster', type: TextInputType.phone),
        field(company, 'Company on poster'),
        FilledButton.icon(onPressed: busy ? null : _share, icon: const Icon(Icons.share), label: Text(busy ? 'Please wait...' : 'Share poster')),
        const SizedBox(height: 6),
        const Text('Your photo comes from Profile. Change it there.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]),
    );
  }
}

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();
  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('templates');
      items = asList(d['items']);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    if (items.isEmpty) return const Center(child: Text('No templates yet. Please check again soon.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final t = items[i];
          final body = (t['body_en'].toString().isNotEmpty ? t['body_en'] : t['body_hi']).toString();
          return Card(
            child: ListTile(
              title: Text(t['title'].toString()),
              subtitle: Text('${t['category']}  -  $body', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateScreen(t: t))),
            ),
          );
        },
      ),
    );
  }
}

class TemplateScreen extends StatefulWidget {
  final Map<String, dynamic> t;
  const TemplateScreen({super.key, required this.t});
  @override
  State<TemplateScreen> createState() => _TemplateScreenState();
}

class _TemplateScreenState extends State<TemplateScreen> {
  late String lang;
  final text = TextEditingController();

  String _fill(String s) {
    final u = Api.user ?? {};
    final co = u['company'];
    return s
        .replaceAll('{name}', (u['name'] ?? '').toString())
        .replaceAll('{mobile}', (u['mobile'] ?? '').toString())
        .replaceAll('{company}', co is Map ? (co['name'] ?? '').toString() : '');
  }

  void _setLang(String l) {
    lang = l;
    text.text = _fill(widget.t[l == 'hi' ? 'body_hi' : 'body_en'].toString());
  }

  @override
  void initState() {
    super.initState();
    _setLang(widget.t['body_en'].toString().isNotEmpty ? 'en' : 'hi');
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<bool> _count() async {
    try {
      await Api.post('templates/${widget.t['id']}/use', {});
      return true;
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final both = widget.t['body_en'].toString().isNotEmpty && widget.t['body_hi'].toString().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(widget.t['title'].toString())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (both)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'hi', label: Text('Hindi'))],
              selected: {lang},
              onSelectionChanged: (s) => setState(() => _setLang(s.first)),
            ),
          ),
        TextField(controller: text, maxLines: 12, minLines: 6, decoration: const InputDecoration(border: OutlineInputBorder(), helperText: 'You can edit the message before sharing.')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
              onPressed: () async {
                if (await _count()) {
                  await Clipboard.setData(ClipboardData(text: text.text));
                  if (mounted) toast(context, 'Copied.');
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              onPressed: () async {
                if (await _count()) await Share.share(text.text);
              },
            ),
          ),
        ]),
      ]),
    );
  }
}
