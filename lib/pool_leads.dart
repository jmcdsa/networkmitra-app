import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'whatsapp.dart';
import 'widgets.dart';

/// Free leads given every day by the owner (from an Excel list). Take today's leads, call them, add them to my clients.
class PoolLeadsScreen extends StatefulWidget {
  const PoolLeadsScreen({super.key});
  @override
  State<PoolLeadsScreen> createState() => _PoolLeadsScreenState();
}

class _PoolLeadsScreenState extends State<PoolLeadsScreen> {
  List<Map<String, dynamic>> items = [];
  Map<String, dynamic> quota = {};
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(dynamic d) {
    items = asList(d['items']);
    quota = Map<String, dynamic>.from((d['quota'] ?? {}) as Map);
  }

  Future<void> _load() async {
    try {
      _apply(await Api.get('pool'));
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _claim() async {
    setState(() => busy = true);
    try {
      final d = await Api.post('pool/claim', {});
      _apply(d);
      if (mounted) toast(context, '${d['claimed']} new lead(s) added to your list.');
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _add(Map<String, dynamic> l) async {
    try {
      await Api.post('pool/${l['id']}/add', {});
      l['added'] = true;
      if (mounted) {
        setState(() {});
        toast(context, 'Added to your clients.');
      }
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = (quota['left'] ?? 0) as int;
    final limit = quota['limit'];
    final per = (quota['period'] ?? 'daily').toString();
    return Scaffold(
      appBar: AppBar(title: const Text('Free leads')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      limit == null ? 'You can take new leads now.' : '$left of $limit leads left ($per).',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: busy ? null : _claim,
                    icon: const Icon(Icons.download),
                    label: const Text('Get leads'),
                  ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('These leads are given only to you. Contact them politely and stop if they say no. Pro members get more leads every day.', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              if (busy) const LinearProgressIndicator(),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Tap "Get leads" to receive your leads.'))
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final l in items)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                Text(l['mobile'].toString()),
                                if ('${l['city']}${l['category']}'.isNotEmpty)
                                  Text([l['category'], l['city']].where((x) => x.toString().isNotEmpty).join(' • '), style: const TextStyle(color: Colors.black54)),
                                if (l['notes'].toString().isNotEmpty) Text(l['notes'].toString(), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  OutlinedButton.icon(
                                    onPressed: () => launchUrl(Uri.parse('tel:${l['mobile']}')),
                                    icon: const Icon(Icons.call, size: 18),
                                    label: const Text('Call'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => openWhatsApp(context, l['mobile'].toString(), ''),
                                    icon: const Icon(Icons.chat, size: 18),
                                    label: const Text('WhatsApp'),
                                  ),
                                  if (l['added'] == true)
                                    const Chip(label: Text('In your clients'), avatar: Icon(Icons.check, size: 16))
                                  else
                                    FilledButton.icon(onPressed: () => _add(l), icon: const Icon(Icons.person_add_alt), label: const Text('Add to clients')),
                                ]),
                              ]),
                            ),
                          ),
                      ]),
              ),
            ]),
    );
  }
}
