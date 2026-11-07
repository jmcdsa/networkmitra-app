import 'package:flutter/material.dart';
import 'api.dart';
import 'chat.dart' show asList;

/// Names shown to the user for each plan feature.
const Map<String, String> kFeatureNames = {
  'clients': 'Clients in CRM',
  'connections': 'Community connections',
  'chat': 'Chat messages',
  'chat_files': 'Files and photos in chat',
  'calls': 'Calls',
  'posters': 'Posters',
  'templates': 'Templates',
  'vcard_full': 'V-Card links and products',
};

bool featureOn(String key) {
  final f = Api.plan?['features'];
  if (f is Map && f[key] is Map) return (f[key] as Map)['enabled'] == true;
  return false;
}

bool get isPro => Api.plan?['is_pro'] == true;

void goUpgrade(BuildContext context, [String? message]) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => UpgradeScreen(message: message)));
}

String limitText(Map f) {
  if (f['enabled'] != true) return 'Not included';
  if (f['limit'] == null) return 'Unlimited';
  final p = f['period'];
  final per = p == 'daily' ? ' per day' : p == 'weekly' ? ' per week' : p == 'monthly' ? ' per month' : '';
  return '${f['limit']}$per';
}

class UpgradeScreen extends StatefulWidget {
  final String? message;
  const UpgradeScreen({super.key, this.message});
  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  List<Map<String, dynamic>> plans = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('plans');
      if (mounted) setState(() => plans = asList(d));
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final free = plans.where((p) => p['is_default'] == true).toList();
    final pro = plans.where((p) => p['is_default'] != true).toList();
    final fp = free.isNotEmpty ? free.first : null;
    final pp = pro.isNotEmpty ? pro.first : null;
    final fFeat = fp != null ? Map<String, dynamic>.from(fp['features'] as Map) : <String, dynamic>{};
    final pFeat = pp != null ? Map<String, dynamic>.from(pp['features'] as Map) : <String, dynamic>{};
    final prices = pp != null ? (pp['prices'] as List) : [];
    return Scaffold(
      appBar: AppBar(title: const Text('Upgrade to Pro')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.message != null)
          Card(color: const Color(0xFFFFF4E0), child: Padding(padding: const EdgeInsets.all(14), child: Text(widget.message!))),
        if (isPro)
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('You are on the Pro plan. Thank you!', style: TextStyle(fontWeight: FontWeight.w700)))),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        if (plans.isEmpty && error == null) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())),
        if (pp != null) ...[
          const SizedBox(height: 8),
          Row(children: const [
            Expanded(child: SizedBox()),
            SizedBox(width: 90, child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 90, child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F766E)))),
          ]),
          const Divider(),
          ...kFeatureNames.entries.where((e) => pFeat.containsKey(e.key) || fFeat.containsKey(e.key)).map((e) {
            final a = fFeat[e.key] is Map ? limitText(fFeat[e.key] as Map) : 'Not included';
            final b = pFeat[e.key] is Map ? limitText(pFeat[e.key] as Map) : 'Not included';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(e.value)),
                SizedBox(width: 90, child: Text(a, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                SizedBox(width: 90, child: Text(b, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            );
          }),
          const Divider(),
          const SizedBox(height: 8),
          ...prices.map((p) => Card(
                child: ListTile(
                  title: Text('Rs ${(p['amount'] as num) == (p['amount'] as num).roundToDouble() ? (p['amount'] as num).toStringAsFixed(0) : p['amount']}  /  ${p['period']}'),
                  trailing: FilledButton(
                    onPressed: isPro
                        ? null
                        : () => showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Online payment is coming soon'),
                                content: const Text('Payment inside the app will start very soon. Until then, please contact the NetworkMitra team to activate Pro for your account.'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                              ),
                            ),
                    child: const Text('Upgrade'),
                  ),
                ),
              )),
        ],
      ]),
    );
  }
}
