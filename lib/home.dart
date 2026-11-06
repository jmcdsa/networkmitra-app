import 'package:flutter/material.dart';
import 'api.dart';
import 'auth_screens.dart';
import 'chat.dart';
import 'clients.dart';
import 'more.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[const DashboardTab(), const ClientsTab(), const ChatHubTab(), const KbTab(), const ProfileTab()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
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
        Text('Hello, $name', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
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

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Api.user ?? {};
    final p = Api.plan ?? {};
    final co = u['company'] is Map ? (u['company'] as Map)['name'] : '';
    final feats = p['features'] is Map ? Map<String, dynamic>.from(p['features'] as Map) : <String, dynamic>{};
    return ListView(padding: const EdgeInsets.all(16), children: [
      const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 40)),
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
            ...feats.entries.where((e) => e.value is Map && e.value['enabled'] == true && e.value['limit'] != null).map((e) {
              final v = e.value as Map;
              final used = v['used'] != null ? '${v['used']} / ' : 'limit ';
              return Text('${e.key}: $used${v['limit']}');
            }),
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
            await Api.post('auth/logout', {});
          } catch (_) {}
          await Api.setToken(null);
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        },
      ),
    ]);
  }
}
