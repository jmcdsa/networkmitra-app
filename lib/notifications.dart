import 'package:flutter/material.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
      final d = await Api.get('notifications');
      if (!mounted) return;
      setState(() {
        items = asList(d['items']);
        loading = false;
      });
      Api.post('notifications/read', {}).catchError((_) => null);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(children: [
                if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red))),
                if (items.isEmpty && error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No notifications yet.'))),
                ...items.map((n) => ListTile(
                      leading: Icon(n['is_read'] == true ? Icons.notifications_none : Icons.notifications_active, color: const Color(0xFF0F766E)),
                      title: Text((n['title'] ?? '').toString(), style: TextStyle(fontWeight: n['is_read'] == true ? FontWeight.w400 : FontWeight.w700)),
                      subtitle: Text('${n['body'] ?? ''}\n${fmtDate(n['created_at'] as String?)}'),
                      isThreeLine: true,
                    )),
              ]),
            ),
    );
  }
}
