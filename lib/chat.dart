import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'widgets.dart';

List<Map<String, dynamic>> asList(dynamic d) =>
    (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// The "Chats" tab: chats, people of my company (community) and connection requests.
class ChatHubTab extends StatelessWidget {
  const ChatHubTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(tabs: [Tab(text: 'Chats'), Tab(text: 'Community'), Tab(text: 'Requests')]),
        Expanded(child: TabBarView(children: [ChatListPage(), CommunityPage(), RequestsPage()])),
      ]),
    );
  }
}

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Map<String, dynamic>> items = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('conversations');
      if (!mounted) return;
      setState(() {
        items = asList(d);
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

  Future<void> _open(Map<String, dynamic> c) async {
    final other = c['other_user'] is Map ? (c['other_user'] as Map)['id'] as int? : null;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(convId: c['id'] as int, title: c['title'].toString(), otherUserId: other),
    ));
    _load();
  }

  Future<void> _newGroup() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewGroupScreen()));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: _newGroup, icon: const Icon(Icons.group_add), label: const Text('New group')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.only(bottom: 90), children: [
                if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                if (items.isEmpty && error == null)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No chats yet. Open "Community", connect with someone and start chatting.', textAlign: TextAlign.center))),
                ...items.map((c) {
                  final last = c['last_message'] is Map ? c['last_message'] as Map : null;
                  final unread = (c['unread'] ?? 0) as int;
                  final isGroup = c['type'] == 'group';
                  return ListTile(
                    leading: CircleAvatar(child: Icon(isGroup ? Icons.group : Icons.person)),
                    title: Text(c['title'].toString(), style: TextStyle(fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500)),
                    subtitle: Text(last == null ? (isGroup ? '${c['member_count']} members' : 'Say hello') : '${last['mine'] == true ? 'You: ' : ''}${last['body']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: unread > 0 ? CircleAvatar(radius: 11, child: Text('$unread', style: const TextStyle(fontSize: 11))) : null,
                    onTap: () => _open(c),
                  );
                }),
              ]),
            ),
    );
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});
  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final search = TextEditingController();
  List<Map<String, dynamic>> items = [];
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('community/users', query: {'q': search.text.trim(), 'per_page': '50'});
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

  Future<void> _connect(Map<String, dynamic> u) async {
    try {
      await Api.post('connections', {'user_id': u['id']});
      if (mounted) toast(context, 'Done.');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _message(Map<String, dynamic> u) async {
    try {
      final c = await Api.post('conversations', {'type': 'direct', 'user_id': u['id']});
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(convId: c['id'] as int, title: u['name'].toString(), otherUserId: u['id'] as int),
      ));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Widget _action(Map<String, dynamic> u) {
    switch (u['connection']) {
      case 'connected':
        return FilledButton.tonal(onPressed: () => _message(u), child: const Text('Message'));
      case 'pending_sent':
        return const Text('Requested', style: TextStyle(color: Colors.black54));
      case 'pending_received':
        return FilledButton(onPressed: () => _connect(u), child: const Text('Accept'));
      default:
        return OutlinedButton(onPressed: () => _connect(u), child: const Text('Connect'));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: const InputDecoration(hintText: 'Search people of your company', prefixIcon: Icon(Icons.search)),
        ),
      ),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
      Expanded(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(children: [
                  if (items.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No one found yet. People of your company appear here after they join.', textAlign: TextAlign.center))),
                  ...items.map((u) => ListTile(
                        leading: CircleAvatar(child: Text(u['name'].toString().isEmpty ? '?' : u['name'].toString()[0].toUpperCase())),
                        title: Text(u['name'].toString()),
                        subtitle: Text((u['city'] ?? '').toString()),
                        trailing: _action(u),
                      )),
                ]),
              ),
      ),
    ]);
  }
}

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  List<Map<String, dynamic>> incoming = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('connections', query: {'status': 'incoming'});
      if (!mounted) return;
      setState(() {
        incoming = asList(d);
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Future<void> _answer(Map<String, dynamic> c, String action) async {
    try {
      await Api.put('connections/${c['id']}', {'action': action});
      if (mounted) toast(context, action == 'accept' ? 'Connected.' : 'Request rejected.');
      _load();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (incoming.isEmpty && error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No new requests.'))),
        ...incoming.map((c) {
          final u = Map<String, dynamic>.from(c['user'] as Map);
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(u['name'].toString()),
            subtitle: Text((u['city'] ?? '').toString()),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _answer(c, 'reject')),
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _answer(c, 'accept')),
            ]),
          );
        }),
      ]),
    );
  }
}

class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key});
  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final title = TextEditingController();
  List<Map<String, dynamic>> people = [];
  final Set<int> picked = {};
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('connections');
      setState(() => people = asList(d).map((c) => Map<String, dynamic>.from(c['user'] as Map)).toList());
    } on ApiException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _create() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Api.post('conversations', {'type': 'group', 'title': title.text.trim(), 'member_ids': picked.toList()});
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: title, decoration: const InputDecoration(labelText: 'Group name'))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Choose from your connections'))),
        Expanded(
          child: ListView(children: [
            if (people.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('You have no connections yet.')),
            ...people.map((u) => CheckboxListTile(
                  value: picked.contains(u['id'] as int),
                  title: Text(u['name'].toString()),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      picked.add(u['id'] as int);
                    } else {
                      picked.remove(u['id'] as int);
                    }
                  }),
                )),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(color: Colors.red))),
            BigButton('Create group', busy: busy, onTap: _create),
          ]),
        ),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final int convId;
  final String title;
  final int? otherUserId;
  const ChatScreen({super.key, required this.convId, required this.title, this.otherUserId});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, dynamic>> msgs = [];
  final text = TextEditingController();
  final scroll = ScrollController();
  Timer? timer;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load(first: true);
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  int get _lastId => msgs.isEmpty ? 0 : msgs.last['id'] as int;

  Future<void> _load({bool first = false}) async {
    try {
      final q = <String, String>{};
      if (!first && _lastId > 0) q['after_id'] = '$_lastId';
      final d = await Api.get('conversations/${widget.convId}/messages', query: q);
      final fresh = asList(d['items']);
      if (!mounted) return;
      if (fresh.isNotEmpty) {
        setState(() {
          msgs.addAll(fresh.where((m) => !msgs.any((x) => x['id'] == m['id'])));
          error = null;
        });
        _toBottom();
      } else if (first) {
        setState(() => error = null);
      }
    } on ApiException catch (e) {
      if (mounted && first) setState(() => error = e.message);
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final t = text.text.trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final m = Map<String, dynamic>.from(await Api.post('conversations/${widget.convId}/messages', {'body': t}) as Map);
      text.clear();
      setState(() {
        if (!msgs.any((x) => x['id'] == m['id'])) msgs.add(m);
      });
      _toBottom();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _block() async {
    final id = widget.otherUserId;
    if (id == null) return;
    try {
      await Api.post('blocks', {'user_id': id});
      if (!mounted) return;
      toast(context, 'User blocked.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _report(Map<String, dynamic>? msg) async {
    final reportedId = msg != null ? msg['sender_id'] as int : widget.otherUserId;
    if (reportedId == null) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'What is wrong?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send report')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final body = <String, dynamic>{'user_id': reportedId, 'reason': c.text.trim()};
      if (msg != null) body['message_id'] = msg['id'];
      await Api.post('reports', body);
      if (mounted) toast(context, 'Thank you. The report was sent to the admin.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        if (widget.otherUserId != null)
          PopupMenuButton<String>(
            onSelected: (v) => v == 'block' ? _block() : _report(null),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
      ]),
      body: Column(children: [
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            itemCount: msgs.length,
            itemBuilder: (_, i) {
              final m = msgs[i];
              final mine = m['mine'] == true;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: GestureDetector(
                  onLongPress: mine ? null : () => _report(m),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: mine ? const Color(0xFFD7F0EC) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!mine) Text(m['sender_name'].toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F766E))),
                      if (m['type'] == 'image' && m['file_url'] != null)
                        Padding(padding: const EdgeInsets.only(bottom: 4), child: Image.network(m['file_url'].toString(), width: 220)),
                      if ((m['body'] ?? '').toString().isNotEmpty) Text(m['body'].toString()),
                      Text(fmtDate(m['created_at'] as String?), style: const TextStyle(fontSize: 10, color: Colors.black45)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: text,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Type a message', contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: sending ? null : _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
