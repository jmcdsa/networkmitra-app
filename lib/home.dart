import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'api.dart';
import 'badge.dart';
import 'auth_screens.dart';
import 'chat.dart';
import 'clients.dart';
import 'more.dart';
import 'notifications.dart';
import 'push.dart';
import 'upgrade.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int tab = 0;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatBadge.refresh();
    PushService.start();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => ChatBadge.refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ChatBadge.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[const DashboardTab(), const ClientsTab(), const ChatHubTab(), const KbTab(), const ProfileTab()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: ChatBadge.count,
              builder: (_, n, __) => Badge(
                isLabelVisible: n > 0,
                backgroundColor: Colors.red,
                label: Text(n > 99 ? '99+' : '$n'),
                child: const Icon(Icons.chat_bubble_outline),
              ),
            ),
            label: 'Chats',
          ),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> today = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Api.get('crm/summary');
      final f = await Api.get('followups', query: {'due': 'today'});
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(s as Map);
        today = (f as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  Widget _stat(String label, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFF0F766E)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (Api.user?['name'] ?? '').toString();
    final s = summary;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Text('Hello, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
        ]),
        const SizedBox(height: 14),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        if (s != null) ...[
          Row(children: [
            _stat('Total clients', '${s['total_clients']}', Icons.people),
            _stat('Closed (won)', '${s['closed_won']}', Icons.emoji_events_outlined),
          ]),
          Row(children: [
            _stat('Conversion', '${s['conversion_percent']}%', Icons.trending_up),
            _stat('Win rate', '${s['win_rate_percent']}%', Icons.percent),
          ]),
          const SizedBox(height: 10),
          const Text('Clients by stage', style: TextStyle(fontWeight: FontWeight.w700)),
          ...((s['by_status'] as List).map((b) => ListTile(
                dense: true,
                title: Text(b['name'].toString()),
                trailing: Text('${b['count']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ))),
        ],
        Card(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined, color: Color(0xFF0F766E)),
            title: const Text('My targets and sales'),
            subtitle: const Text('See progress, add a sale'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TargetsScreen())),
          ),
        ),
        const SizedBox(height: 10),
        const Text("Today's follow-ups", style: TextStyle(fontWeight: FontWeight.w700)),
        if (today.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Nothing due today.')),
        ...today.map((f) => Card(
              child: ListTile(
                title: Text(f['lead_name'].toString()),
                subtitle: Text('${fmtDate(f['due_at'] as String?)}${(f['note'] ?? '').toString().isEmpty ? '' : '\n${f['note']}'}'),
                isThreeLine: (f['note'] ?? '').toString().isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    try {
                      await Api.put('followups/${f['id']}', {'done': true});
                      _load();
                    } on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  },
                ),
              ),
            )),
      ]),
    );
  }
}

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  @override
  void initState() {
    super.initState();
    Api.refreshMe().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
      if (x == null) return;
      final d = await Api.upload('me/photo', 'photo', x.path);
      Api.user?['photo_url'] = d['photo_url'];
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } catch (_) {
      if (mounted) toast(context, 'Could not use this photo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = Api.user ?? {};
    final p = Api.plan ?? {};
    final co = u['company'] is Map ? (u['company'] as Map)['name'] : '';
    final feats = p['features'] is Map ? Map<String, dynamic>.from(p['features'] as Map) : <String, dynamic>{};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Center(
        child: GestureDetector(
          onTap: _pickPhoto,
          child: CircleAvatar(
            radius: 42,
            backgroundImage: u['photo_url'] != null ? NetworkImage(u['photo_url'].toString()) : null,
            child: u['photo_url'] == null ? const Icon(Icons.add_a_photo_outlined, size: 32) : null,
          ),
        ),
      ),
      const Center(child: Text('Tap to change photo', style: TextStyle(fontSize: 11, color: Colors.black45))),
      const SizedBox(height: 10),
      Center(child: Text((u['name'] ?? '').toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
      Center(child: Text((u['email'] ?? '').toString())),
      Center(child: Text('$co')),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Plan: ${p['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (p['ends_at'] != null) Text('Valid until ${fmtDate(p['ends_at'] as String?)}'),
            const SizedBox(height: 8),
            ...kFeatureNames.entries.where((e) => feats.containsKey(e.key)).map((e) {
              final v = Map<String, dynamic>.from(feats[e.key] as Map);
              final on = v['enabled'] == true;
              String line = limitText(v);
              if (on && v['limit'] != null && v['used'] != null) line = '${v['used']} / ${v['limit']} used';
              return InkWell(
                onTap: on ? null : () => goUpgrade(context, '${e.value} is available on the Pro plan.'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(on ? Icons.check_circle : Icons.lock, size: 18, color: on ? Colors.green : Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: TextStyle(color: on ? null : Colors.grey))),
                    Text(on ? line : 'Pro', style: TextStyle(fontSize: 12, color: on ? Colors.black54 : Colors.grey)),
                  ]),
                ),
              );
            }),
            if (!isPro) ...[
              const SizedBox(height: 8),
              FilledButton(onPressed: () => goUpgrade(context), child: const Text('See Pro plan')),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          leading: const Icon(Icons.badge_outlined, color: Color(0xFF0F766E)),
          title: const Text('My digital V-Card'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VCardScreen())),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined, color: Color(0xFF0F766E)),
          title: const Text('Targets and sales'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TargetsScreen())),
        ),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
        onPressed: () async {
          try {
            await Api.post('auth/logout', {'push_token': PushService.token ?? ''});
          } catch (_) {}
          await Api.setToken(null);
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        },
      ),
    ]);
  }
}
