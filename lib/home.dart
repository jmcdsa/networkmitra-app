import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'whatsapp.dart';
import 'social.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'api.dart';
import 'badge.dart';
import 'call.dart';
import 'auth_screens.dart';
import 'chat.dart';
import 'clients.dart';
import 'dashboard.dart';
import 'ads.dart';
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
  Timer? _callPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatBadge.refresh();
    PushService.start();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => ChatBadge.refresh());
    CallWatcher.check();
    _callPoll = Timer.periodic(const Duration(seconds: 3), (_) => CallWatcher.check());
    HomeConfig.load();
    HomeNav.request.addListener(_onNav);
  }

  void _onNav() {
    final t = HomeNav.request.value;
    if (t != null && mounted) {
      setState(() => tab = t);
      HomeNav.request.value = null;
    }
  }

  @override
  void dispose() {
    HomeNav.request.removeListener(_onNav);
    _poll?.cancel();
    _callPoll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatBadge.refresh();
      CallWatcher.check();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[const DashboardTab(), const ClientsTab(), const ChatHubTab(), const KbTab(), const SocialScreen(), const ProfileTab()];
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (tab != 0) {
          setState(() => tab = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBack == null || now.difference(_lastBack!) > const Duration(seconds: 2)) {
          _lastBack = now;
          toast(context, 'Press back again to exit');
        } else {
          SystemNavigator.pop();
        }
      },
      child: _scaffold(pages),
    );
  }

  DateTime? _lastBack;

  Widget _scaffold(List<Widget> pages) {
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
          NavigationDestination(icon: Icon(Icons.image_outlined), label: 'Posters'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
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

  Future<void> _deleteAccount() async {
    final pw = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete my account?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All your clients, chats, V-Card, files and videos will be deleted for ever. This cannot be undone. Your Pro time is lost.'),
          const SizedBox(height: 10),
          TextField(controller: pw, obscureText: true, decoration: const InputDecoration(labelText: 'Enter your password')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.delete('me', {'password': pw.text});
      await Api.setToken(null);
      HomeConfig.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
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
      Card(
        child: ListTile(
          leading: const Icon(Icons.chat_outlined, color: Color(0xFF0F766E)),
          title: const Text('My WhatsApp API'),
          subtitle: const Text('Send WhatsApp messages automatically'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WaSetupScreen())),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          for (final l in const [
            ['Privacy Policy', 'privacy.php', Icons.privacy_tip_outlined],
            ['Terms and Conditions', 'terms.php', Icons.description_outlined],
            ['Refund Policy', 'refund.php', Icons.currency_rupee],
            ['Community Rules', 'community-guidelines.php', Icons.groups_outlined],
          ])
            ListTile(
              dense: true,
              leading: Icon(l[2] as IconData, color: const Color(0xFF0F766E)),
              title: Text(l[0] as String),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => launchUrl(Uri.parse('${kBase.replaceFirst('/api/v1', '')}/${l[1]}'), mode: LaunchMode.externalApplication),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text('Log out'),
        onPressed: () async {
          try {
            await Api.post('auth/logout', {'push_token': PushService.token ?? ''});
          } catch (_) {}
          await Api.setToken(null);
          HomeConfig.clear();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
        },
      ),
      TextButton(
        onPressed: _deleteAccount,
        child: const Text('Delete my account', style: TextStyle(color: Colors.red)),
      ),
    ]);
  }
}
