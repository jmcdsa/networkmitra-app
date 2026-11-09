import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'poster_editor.dart';
import 'upgrade.dart';
import 'widgets.dart';

/// Posters and ready message templates.
class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Posters and templates'),
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Posters'), Tab(text: 'Templates')]),
        ),
        body: const TabBarView(children: [_TodayTab(), _PostersTab(), _TemplatesTab()]),
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
    final cats = ['All', ...{...items.map((e) => e['category'].toString())}];
    final shown = cat == 'All' ? items : items.where((e) => e['category'] == cat).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Use my own poster from gallery'),
          onPressed: () async {
            final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
            if (x != null && context.mounted) {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => OwnPosterScreen(file: File(x.path))));
            }
          },
        ),
      ),
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
        child: items.isEmpty
            ? const Center(child: Text('No ready posters yet. You can use your own poster above.'))
            : RefreshIndicator(
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

/// One poster with my details on it, ready to share.
class PosterScreen extends StatelessWidget {
  final Map<String, dynamic> poster;
  const PosterScreen({super.key, required this.poster});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(poster['title'].toString())),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PosterEditor(
          usePath: 'posters/${poster['id']}/use',
          background: Image.network(poster['image_url'].toString(), width: double.infinity, fit: BoxFit.fitWidth,
              loadingBuilder: (c, w, p) => p == null ? w : const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
              errorBuilder: (_, __, ___) => const SizedBox(height: 200, child: Center(child: Icon(Icons.broken_image)))),
        ),
      ]),
    );
  }
}

/// A poster made from the user's own picture from the gallery.
class OwnPosterScreen extends StatelessWidget {
  final File file;
  const OwnPosterScreen({super.key, required this.file});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My poster')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PosterEditor(fileTag: 'mine', background: Image.file(file, width: double.infinity, fit: BoxFit.fitWidth)),
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
  List<Map<String, dynamic>> mine = [];
  Map<String, dynamic> limits = {};
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
      final m = await Api.get('me/templates');
      mine = asList(m['items']);
      limits = Map<String, dynamic>.from(m['limits'] as Map);
      error = null;
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? t]) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MyTemplateEditor(existing: t, limits: limits)));
    if (ok == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this template?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await Api.delete('me/templates/${t['id']}');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(error!)));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          const Expanded(child: Text('My templates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Create')),
        ]),
        const SizedBox(height: 4),
        Text(
          limits['links_allowed'] == true
              ? 'Pro: up to ${limits['max_chars']} letters, links allowed.'
              : 'Free: up to ${limits['max_chars']} letters, no links (${limits['max_count']} templates). Pro gives longer messages and links.',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 6),
        if (mine.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('You have not made any template yet.')),
        for (final t in mine)
          Card(
            child: ListTile(
              title: Text(t['title'].toString()),
              subtitle: Text(t['body'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateScreen(t: {'id': t['id'], 'title': t['title'], 'body_en': t['body'], 'body_hi': ''}, own: true))),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _edit(t) : _delete(t),
                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'del', child: Text('Delete'))],
              ),
            ),
          ),
        const Divider(height: 28),
        const Text('Ready-made templates', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (items.isEmpty) const Text('No ready-made templates yet.'),
        for (final t in items)
          Card(
            child: ListTile(
              title: Text(t['title'].toString()),
              subtitle: Text('${t['category']}  -  ${(t['body_en'].toString().isNotEmpty ? t['body_en'] : t['body_hi'])}', maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplateScreen(t: t))),
            ),
          ),
      ]),
    );
  }
}

final RegExp _linkRe = RegExp(r'(https?://|www\.|\bt\.me/|\bwa\.me/|\b[a-z0-9][a-z0-9-]*\.(com|in|co|net|org|me|io|app|link|ly|store|shop|xyz|info|biz|online|site|page|live|gl|be)\b)', caseSensitive: false);

/// Write or edit my own message template.
class MyTemplateEditor extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final Map<String, dynamic> limits;
  const MyTemplateEditor({super.key, this.existing, required this.limits});
  @override
  State<MyTemplateEditor> createState() => _MyTemplateEditorState();
}

class _MyTemplateEditorState extends State<MyTemplateEditor> {
  late final TextEditingController title = TextEditingController(text: (widget.existing?['title'] ?? '').toString());
  late final TextEditingController body = TextEditingController(text: (widget.existing?['body'] ?? '').toString());
  bool saving = false;

  int get maxChars => (widget.limits['max_chars'] as int?) ?? 300;
  bool get linksOk => widget.limits['links_allowed'] == true;

  Future<void> _save() async {
    final t = title.text.trim(), b = body.text.trim();
    if (t.isEmpty || b.isEmpty) {
      toast(context, 'Write a title and a message.');
      return;
    }
    if (!linksOk && _linkRe.hasMatch('$t $b')) {
      toast(context, 'Links are not allowed on the Free plan. Remove the link or upgrade to Pro.');
      return;
    }
    setState(() => saving = true);
    try {
      final id = widget.existing?['id'];
      final data = {'title': t, 'body': b};
      if (id == null) {
        await Api.post('me/templates', data);
      } else {
        await Api.put('me/templates/$id', data);
      }
      if (mounted) Navigator.pop(context, true);
      return;
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New template' : 'Edit template')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: title, maxLength: 80, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          maxLines: 10,
          minLines: 6,
          maxLength: maxChars,
          decoration: InputDecoration(
            labelText: 'Message',
            border: const OutlineInputBorder(),
            helperMaxLines: 3,
            helperText: linksOk
                ? 'You can use {name}, {mobile} and {company}. Links are allowed.'
                : 'You can use {name}, {mobile} and {company}. Links are not allowed on Free.',
          ),
        ),
        if (!linksOk)
          TextButton(onPressed: () => goUpgrade(context, 'Longer messages and links in your templates are available on the Pro plan.'), child: const Text('Pro: longer messages and links')),
        const SizedBox(height: 8),
        FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving...' : 'Save')),
      ]),
    );
  }
}

class TemplateScreen extends StatefulWidget {
  final Map<String, dynamic> t;
  final bool own; // my own template: not counted against the plan
  const TemplateScreen({super.key, required this.t, this.own = false});
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
    if (widget.own) return true;
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

const List<List<Color>> _themes = [
  [Color(0xFF0F766E), Color(0xFF134E4A)],
  [Color(0xFF7C3AED), Color(0xFF4C1D95)],
  [Color(0xFFEA580C), Color(0xFF9A3412)],
  [Color(0xFF2563EB), Color(0xFF1E3A8A)],
  [Color(0xFFBE185D), Color(0xFF831843)],
  [Color(0xFF15803D), Color(0xFF14532D)],
];

/// A new ready poster every day, made automatically. Nothing for the owner to upload.
class _TodayTab extends StatefulWidget {
  const _TodayTab();
  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? quote;
  int theme = 0;
  bool loading = true;
  String? error;
  String lang = 'en';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('daily');
      theme = (d['theme'] as int?) ?? 0;
      if (d['quote'] != null) {
        quote = Map<String, dynamic>.from(d['quote'] as Map);
        lang = quote!['text_en'].toString().isNotEmpty ? 'en' : 'hi';
      }
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
    if (quote == null) return const Center(child: Text('Today\'s poster is not ready yet.'));
    final both = quote!['text_en'].toString().isNotEmpty && quote!['text_hi'].toString().isNotEmpty;
    final text = quote![lang == 'hi' ? 'text_hi' : 'text_en'].toString();
    final colors = _themes[theme % _themes.length];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Today\'s poster', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('A new one comes every day. Share it with your clients and team.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        if (both)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'hi', label: Text('Hindi'))],
              selected: {lang},
              onSelectionChanged: (v) => setState(() => lang = v.first),
            ),
          ),
        PosterEditor(
          key: ValueKey('today$lang'),
          usePath: 'daily/use',
          fileTag: 'today',
          background: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
              child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, height: 1.4, fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      ]),
    );
  }
}
