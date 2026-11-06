import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'upgrade.dart';
import 'chat.dart' show asList;
import 'widgets.dart';

String rs(dynamic v) {
  final n = (v is num) ? v : num.tryParse('$v') ?? 0;
  final s = n == n.roundToDouble() ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
  return 'Rs $s';
}

Future<void> openUrl(BuildContext c, String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {
    if (c.mounted) toast(c, 'Could not open the link.');
  }
}

// ---------------- Targets and sales ----------------

class TargetsScreen extends StatefulWidget {
  const TargetsScreen({super.key});
  @override
  State<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends State<TargetsScreen> {
  Map<String, dynamic>? p;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('targets/current');
      if (mounted) {
        setState(() {
          p = Map<String, dynamic>.from(d as Map);
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _setTargets() async {
    final per = p?['personal'] as Map? ?? {};
    final team = p?['team'] as Map? ?? {};
    final a = TextEditingController(text: '${per['target_amount'] ?? 0}');
    final c = TextEditingController(text: '${per['target_closings'] ?? 0}');
    final t = TextEditingController(text: '${team['target_amount'] ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set this month\'s targets'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field(a, 'My sales target (Rs)', type: TextInputType.number),
            field(c, 'My closings target (number)', type: TextInputType.number),
            field(t, 'Team sales target (Rs)', type: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.put('targets/current', {
        'personal_target_amount': a.text.trim(),
        'personal_target_closings': int.tryParse(c.text.trim()) ?? 0,
        'team_target_amount': t.text.trim(),
      });
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _addSale() async {
    final a = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a sale'),
        content: field(a, 'Sale amount (Rs)', type: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('sales', {'amount': a.text.trim()});
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Widget _bar(String title, dynamic percent, String line) {
    final pc = (percent is num) ? percent.toDouble() : 0.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: (pc / 100).clamp(0.0, 1.0), minHeight: 10, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 8),
          Text('$pc% done'),
          Text(line, style: const TextStyle(color: Colors.black54)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final per = p?['personal'] as Map?;
    final team = p?['team'] as Map?;
    return Scaffold(
      appBar: AppBar(title: const Text('Targets and sales')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _addSale, icon: const Icon(Icons.add), label: const Text('Add sale')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
          if (p == null && error == null) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
          if (p != null) ...[
            Text('${p!['month']}  •  ${p!['days_left']} days left', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            _bar('My sales', per?['percent'], 'Sold ${rs(per?['sold_amount'])} of ${rs(per?['target_amount'])}\nRemaining ${rs(per?['remaining_amount'])}  •  Need ${rs(per?['daily_pace_needed'])} per day'),
            _bar('My closings', ((per?['target_closings'] ?? 0) as num) > 0 ? (((per?['closings'] ?? 0) as num) * 100 / (per!['target_closings'] as num)).clamp(0, 100) : 0, '${per?['closings']} of ${per?['target_closings']} closings'),
            _bar('Team sales', team?['percent'], 'Team sold ${rs(team?['sold_amount'])} of ${rs(team?['target_amount'])}'),
            if (team != null && (team['members'] as List).isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('Team members (joined with your referral code)', style: TextStyle(fontWeight: FontWeight.w700)),
              ...(team['members'] as List).map((m) => ListTile(dense: true, title: Text(m['name'].toString()), trailing: Text(rs(m['sold_amount'])))),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _setTargets, icon: const Icon(Icons.flag_outlined), label: const Text('Set targets')),
            const SizedBox(height: 80),
          ],
        ]),
      ),
    );
  }
}

// ---------------- V-Card ----------------

class VCardScreen extends StatefulWidget {
  const VCardScreen({super.key});
  @override
  State<VCardScreen> createState() => _VCardScreenState();
}

class _VCardScreenState extends State<VCardScreen> {
  final username = TextEditingController();
  final bio = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final email = TextEditingController();
  String? shareUrl;
  bool isPublic = true;
  bool full = false;
  List<Map<String, String>> links = [];
  List<Map<String, String>> products = [];
  bool loading = true;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _fill(Map<String, dynamic> v) {
    username.text = (v['username'] ?? '').toString();
    bio.text = (v['bio'] ?? '').toString();
    phone.text = (v['phone'] ?? '').toString();
    whatsapp.text = (v['whatsapp'] ?? '').toString();
    email.text = (v['email'] ?? '').toString();
    shareUrl = v['share_url'] as String?;
    isPublic = v['is_public'] == true;
    full = v['is_full_card'] == true;
    links = ((v['social_links'] ?? []) as List).map((e) => {'label': '${(e as Map)['label']}', 'url': '${e['url']}'}).toList();
    products = ((v['products'] ?? []) as List).map((e) => {'name': '${(e as Map)['name']}', 'price': '${e['price'] ?? ''}', 'url': '${e['url'] ?? ''}'}).toList();
  }

  Future<void> _load() async {
    try {
      final v = Map<String, dynamic>.from(await Api.get('vcard') as Map);
      _fill(v);
    } on ApiException catch (e) {
      error = e.message;
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{
        'username': username.text.trim(),
        'bio': bio.text.trim(),
        'phone': phone.text.trim(),
        'whatsapp': whatsapp.text.trim(),
        'email': email.text.trim(),
        'is_public': isPublic,
      };
      if (full) {
        body['social_links'] = links;
        body['products'] = products;
      }
      final v = Map<String, dynamic>.from(await Api.put('vcard', body) as Map);
      setState(() => _fill(v));
      if (mounted) toast(context, 'V-Card saved.');
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _addLink() async {
    final l = TextEditingController();
    final u = TextEditingController(text: 'https://');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a link'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          field(l, 'Name (e.g. Instagram)'),
          field(u, 'Link', type: TextInputType.url),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && l.text.trim().isNotEmpty) {
      setState(() => links.add({'label': l.text.trim(), 'url': u.text.trim()}));
    }
  }

  Future<void> _addProduct() async {
    final n = TextEditingController();
    final pr = TextEditingController();
    final u = TextEditingController(text: 'https://');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a product'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field(n, 'Product name'),
            field(pr, 'Price (optional)'),
            field(u, 'Link (optional)', type: TextInputType.url),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && n.text.trim().isNotEmpty) {
      final link = u.text.trim() == 'https://' ? '' : u.text.trim();
      setState(() => products.add({'name': n.text.trim(), 'price': pr.text.trim(), 'url': link}));
    }
  }

  Widget _lockedSection(String title, IconData icon) {
    return Card(
      color: Colors.grey.shade100,
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700)),
        subtitle: const Text('Pro feature. Tap to upgrade.'),
        trailing: const Icon(Icons.lock, color: Colors.grey),
        onTap: () => goUpgrade(context, '$title is available on the Pro plan.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My digital V-Card')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (shareUrl != null)
                Card(
                  child: ListTile(
                    title: Text(shareUrl!, style: const TextStyle(fontSize: 14)),
                    subtitle: const Text('Your card link. Share it with clients.'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: shareUrl!));
                          if (context.mounted) toast(context, 'Link copied.');
                        },
                      ),
                      IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => openUrl(context, shareUrl!)),
                    ]),
                  ),
                ),
              const SizedBox(height: 10),
              field(username, 'Card name in link (small letters, numbers)'),
              field(bio, 'About me', lines: 3),
              field(phone, 'Phone', type: TextInputType.phone),
              field(whatsapp, 'WhatsApp number', type: TextInputType.phone),
              field(email, 'Email', type: TextInputType.emailAddress),
              SwitchListTile(value: isPublic, onChanged: (v) => setState(() => isPublic = v), title: const Text('Card is public')),
              if (full) ...[
                const Text('Links', style: TextStyle(fontWeight: FontWeight.w700)),
                ...links.asMap().entries.map((e) => ListTile(
                      dense: true,
                      title: Text(e.value['label'] ?? ''),
                      subtitle: Text(e.value['url'] ?? ''),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => links.removeAt(e.key))),
                    )),
                TextButton.icon(onPressed: _addLink, icon: const Icon(Icons.add), label: const Text('Add link')),
                const Text('Products', style: TextStyle(fontWeight: FontWeight.w700)),
                ...products.asMap().entries.map((e) => ListTile(
                      dense: true,
                      title: Text(e.value['name'] ?? ''),
                      subtitle: Text(e.value['price'] ?? ''),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => products.removeAt(e.key))),
                    )),
                TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add), label: const Text('Add product')),
              ] else ...[
                _lockedSection('Links on my card', Icons.link),
                _lockedSection('Products on my card', Icons.shopping_bag_outlined),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
              BigButton('Save V-Card', busy: busy, onTap: _save),
            ]),
    );
  }
}

// ---------------- Knowledge base ----------------

class KbTab extends StatefulWidget {
  const KbTab({super.key});
  @override
  State<KbTab> createState() => _KbTabState();
}

class _KbTabState extends State<KbTab> {
  List<Map<String, dynamic>> cats = [];
  List<Map<String, dynamic>> items = [];
  final search = TextEditingController();
  int? cat;
  String lang = 'en';
  bool saved = false;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load(reloadCats: true);
  }

  Future<void> _load({bool reloadCats = false}) async {
    try {
      if (reloadCats) {
        cats = asList(await Api.get('kb/categories', query: {'lang': lang}));
      }
      final q = <String, String>{'lang': lang, 'per_page': '100'};
      if (cat != null) q['category'] = '$cat';
      if (search.text.trim().isNotEmpty) q['q'] = search.text.trim();
      if (saved) q['bookmarked'] = '1';
      final d = await Api.get('kb/items', query: q);
      if (!mounted) return;
      setState(() {
        items = asList(d['items']);
        error = null;
        loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  IconData _icon(String t) => t == 'video' ? Icons.play_circle_outline : (t == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.article_outlined);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search)),
            ),
          ),
          const SizedBox(width: 8),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'en', label: Text('EN')), ButtonSegment(value: 'hi', label: Text('हिं'))],
            selected: {lang},
            onSelectionChanged: (s) {
              lang = s.first;
              _load(reloadCats: true);
            },
          ),
        ]),
      ),
      SizedBox(
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(padding: const EdgeInsets.all(4), child: FilterChip(label: const Text('Saved'), selected: saved, onSelected: (v) { saved = v; _load(); })),
          Padding(padding: const EdgeInsets.all(4), child: ChoiceChip(label: const Text('All'), selected: cat == null, onSelected: (_) { cat = null; _load(); })),
          ...cats.map((c) => Padding(
                padding: const EdgeInsets.all(4),
                child: ChoiceChip(label: Text(c['name'].toString()), selected: cat == c['id'], onSelected: (_) { cat = c['id'] as int; _load(); }),
              )),
        ]),
      ),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(children: [
                  if (items.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Nothing here yet.'))),
                  ...items.map((i) => ListTile(
                        leading: Icon(_icon(i['type'].toString())),
                        title: Text((i['title'] ?? '').toString()),
                        subtitle: i['summary'] != null ? Text(i['summary'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis) : null,
                        trailing: i['is_bookmarked'] == true ? const Icon(Icons.bookmark, color: Color(0xFF0F766E)) : null,
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KbItemScreen(id: i['id'] as int, lang: lang)));
                          _load();
                        },
                      )),
                ]),
              ),
      ),
    ]);
  }
}

class KbItemScreen extends StatefulWidget {
  final int id;
  final String lang;
  const KbItemScreen({super.key, required this.id, required this.lang});
  @override
  State<KbItemScreen> createState() => _KbItemScreenState();
}

class _KbItemScreenState extends State<KbItemScreen> {
  Map<String, dynamic>? item;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('kb/items/${widget.id}', query: {'lang': widget.lang});
      if (mounted) setState(() => item = Map<String, dynamic>.from(d as Map));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _bookmark() async {
    final it = item;
    if (it == null) return;
    try {
      if (it['is_bookmarked'] == true) {
        await Api.delete('kb/bookmarks/${widget.id}');
      } else {
        await Api.post('kb/bookmarks', {'kb_item_id': widget.id});
      }
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = item;
    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge base'), actions: [
        if (it != null) IconButton(icon: Icon(it['is_bookmarked'] == true ? Icons.bookmark : Icons.bookmark_border), onPressed: _bookmark),
      ]),
      body: it == null
          ? Center(child: error != null ? Text(error!) : const CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Text((it['title'] ?? '').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (it['video_url'] != null) FilledButton.icon(onPressed: () => openUrl(context, it['video_url'].toString()), icon: const Icon(Icons.play_arrow), label: const Text('Watch video')),
              if (it['file_url'] != null) FilledButton.icon(onPressed: () => openUrl(context, it['file_url'].toString()), icon: const Icon(Icons.picture_as_pdf), label: const Text('Open PDF')),
              const SizedBox(height: 12),
              if (it['body'] != null) SelectableText(it['body'].toString(), style: const TextStyle(fontSize: 16, height: 1.5)),
            ]),
    );
  }
}
