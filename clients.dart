import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'widgets.dart';
import 'upgrade.dart';
import 'whatsapp.dart';

class ClientsTab extends StatefulWidget {
  const ClientsTab({super.key});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  List<Map<String, dynamic>> items = [];
  final search = TextEditingController();
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('leads', query: {'q': search.text.trim(), 'per_page': '100'});
      if (!mounted) return;
      setState(() {
        items = (d['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<void> _open([Map<String, dynamic>? lead]) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LeadScreen(leadId: lead?['id'] as int?)));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open(), icon: const Icon(Icons.add), label: const Text('Add client')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              hintText: 'Search clients',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () {
                search.clear();
                _load();
              }),
            ),
          ),
        ),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: const [Padding(padding: EdgeInsets.all(40), child: Center(child: Text('No clients yet. Tap "Add client".')))])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final l = items[i];
                            final locked = l['is_locked'] == true;
                            return ListTile(
                              leading: CircleAvatar(child: Text(l['name'].toString().isEmpty ? '?' : l['name'].toString()[0].toUpperCase())),
                              title: Text(l['name'].toString()),
                              subtitle: locked
                                  ? const Text('Locked. Upgrade to Pro to open.')
                                  : Text([(l['mobile'] ?? '').toString(), (l['status'] ?? '').toString()].where((x) => x.isNotEmpty).join('  •  ')),
                              trailing: locked ? const Icon(Icons.lock_outline) : const Icon(Icons.chevron_right),
                              onTap: locked ? () => toast(context, 'This client is locked because your plan limit is over.') : () => _open(l),
                            );
                          },
                        ),
                ),
        ),
      ]),
    );
  }
}

class LeadScreen extends StatefulWidget {
  final int? leadId;
  const LeadScreen({super.key, this.leadId});
  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  final name = TextEditingController();
  final mobile = TextEditingController();
  final city = TextEditingController();
  final product = TextEditingController();
  final notes = TextEditingController();
  List<Map<String, dynamic>> statuses = [];
  int? statusId;
  bool busy = false;
  bool loading = true;
  String? error;
  String? nextFollowup;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final st = await Api.get('lead-statuses');
      statuses = (st as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (statuses.isNotEmpty) statusId = statuses.first['id'] as int;
      if (widget.leadId != null) {
        final l = Map<String, dynamic>.from(await Api.get('leads/${widget.leadId}') as Map);
        name.text = (l['name'] ?? '').toString();
        mobile.text = (l['mobile'] ?? '').toString();
        city.text = (l['city'] ?? '').toString();
        product.text = (l['product_interest'] ?? '').toString();
        notes.text = (l['notes'] ?? '').toString();
        statusId = l['status_id'] as int?;
        nextFollowup = l['next_followup_at'] as String?;
      }
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
    final body = <String, dynamic>{
      'name': name.text.trim(),
      'mobile': mobile.text.trim(),
      'city': city.text.trim(),
      'product_interest': product.text.trim(),
      'notes': notes.text.trim(),
      'status_id': statusId,
    };
    try {
      if (widget.leadId == null) {
        await Api.post('leads', body);
      } else {
        await Api.put('leads/${widget.leadId}', body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this client?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.delete('leads/${widget.leadId}');
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _addFollowup() async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
    if (time == null || !mounted) return;
    final noteC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Follow-up note'),
        content: TextField(controller: noteC, decoration: const InputDecoration(hintText: 'e.g. Call about the product (optional)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    String two(int n) => n.toString().padLeft(2, '0');
    final due = '${date.year}-${two(date.month)}-${two(date.day)} ${two(time.hour)}:${two(time.minute)}';
    try {
      await Api.post('leads/${widget.leadId}/followups', {'due_at': due, 'note': noteC.text.trim()});
      if (mounted) toast(context, 'Follow-up saved.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _whatsapp(String num) async {
    if (!featureOn('social_open')) {
      goUpgrade(context, 'WhatsApp and Telegram chat links are available on the Pro plan.');
      return;
    }
    final c = TextEditingController();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('WhatsApp to ${name.text.trim().isEmpty ? 'client' : name.text.trim()}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: c, maxLines: 4, maxLength: 1000, decoration: const InputDecoration(hintText: 'Write your message')),
          const SizedBox(height: 6),
          const Text('Open WhatsApp: opens your own WhatsApp with this message.\nSend automatically (Pro): sent from your own WhatsApp Business API (Profile > My WhatsApp API).', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'open'), child: const Text('Open WhatsApp')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'api'), child: const Text('Send automatically')),
        ],
      ),
    );
    if (choice == null) return;
    final text = c.text.trim();
    if (choice == 'open') {
      await openWhatsApp(context, num, text);
      return;
    }
    if (text.isEmpty) {
      if (mounted) toast(context, 'Please write a message first.');
      return;
    }
    try {
      await Api.post('leads/${widget.leadId}/whatsapp', {'message': text});
      if (mounted) toast(context, 'WhatsApp message sent.');
    } on ApiException catch (e) {
      if (!mounted) return;
      // 402 (plan limit) already opens the upgrade page by itself.
      if (e.status != 402) toast(context, e.code == 'wa_not_setup' ? 'First add your WhatsApp API: Profile > My WhatsApp API.' : (e.code == 'wa_off' ? 'Automatic sending is switched off for now. Use "Open WhatsApp".' : e.message));
    }
  }

  Future<void> _launch(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) toast(context, 'Could not open.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.leadId == null;
    final num = mobile.text.replaceAll(RegExp(r'[^0-9+]'), '');
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New client' : 'Client'), actions: [
        if (!isNew) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              field(name, 'Name'),
              field(mobile, 'Mobile number', type: TextInputType.phone),
              if (!isNew && num.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Wrap(spacing: 10, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: () => _launch('tel:$num'), icon: const Icon(Icons.call), label: const Text('Call')),
                    OutlinedButton.icon(onPressed: () => _whatsapp(num), icon: const Icon(Icons.chat), label: const Text('WhatsApp')),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (!featureOn('social_open')) {
                          goUpgrade(context, 'WhatsApp and Telegram chat links are available on the Pro plan.');
                        } else {
                          openTelegram(context, num);
                        }
                      },
                      icon: const Icon(Icons.send),
                      label: const Text('Telegram'),
                    ),
                  ]),
                ),
              field(city, 'City'),
              field(product, 'Interested in (product)'),
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: DropdownButtonFormField<int>(
                  value: statuses.any((s) => s['id'] == statusId) ? statusId : null,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: statuses.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'].toString()))).toList(),
                  onChanged: (v) => setState(() => statusId = v),
                ),
              ),
              field(notes, 'Notes', lines: 4),
              if (!isNew) ...[
                if (nextFollowup != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Next follow-up: ${fmtDate(nextFollowup)}')),
                OutlinedButton.icon(onPressed: _addFollowup, icon: const Icon(Icons.alarm_add), label: const Text('Add follow-up')),
                const SizedBox(height: 14),
              ],
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
              BigButton('Save', busy: busy, onTap: _save),
            ]),
    );
  }
}
