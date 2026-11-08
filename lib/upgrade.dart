import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'widgets.dart';

/// Names shown to the user for each plan feature.
const Map<String, String> kFeatureNames = {
  'clients': 'Clients in CRM',
  'connections': 'Community connections',
  'chat': 'Chat messages',
  'chat_files': 'Files and photos in chat',
  'whatsapp': 'WhatsApp messages to clients',
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

class _UpgradeScreenState extends State<UpgradeScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> plans = [];
  String? error;
  int? _payId;
  Timer? _timer;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _payId != null) _checkPayment();
  }

  Future<void> _pay(int priceId) async {
    try {
      final d = await Api.post('payments', {'price_id': priceId});
      _payId = d['payment_id'] as int;
      _tries = 0;
      await launchUrl(Uri.parse(d['pay_url'] as String), mode: LaunchMode.externalApplication);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 4), (_) => _checkPayment());
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payment'),
          content: Text(e.message),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (_) {
      if (mounted) toast(context, 'Could not open the payment page.');
    }
  }

  bool _checking = false;

  Future<void> _checkPayment() async {
    final id = _payId;
    if (id == null || _checking) return;
    _checking = true;
    try {
      _tries++;
      final d = await Api.get('payments/$id');
      if (d['status'] == 'paid') {
        _timer?.cancel();
        _payId = null;
        await Api.refreshMe();
        if (mounted) {
          setState(() {});
          toast(context, 'Payment received. Pro is active. Thank you!');
        }
      } else if (_tries > 90) {
        _timer?.cancel();
        _payId = null;
        if (mounted) setState(() {});
      }
    } catch (_) {
      // try again at the next check
    } finally {
      _checking = false;
    }
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
        if (_payId != null)
          Card(
            color: const Color(0xFFE8F5F3),
            child: ListTile(
              leading: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              title: const Text('Waiting for your payment...'),
              subtitle: const Text('After paying, come back to the app. Pro starts automatically.'),
              trailing: TextButton(onPressed: _checkPayment, child: const Text('I have paid')),
            ),
          ),
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
                  subtitle: isPro ? const Text('Buying again extends your Pro time') : null,
                  trailing: FilledButton(
                    onPressed: (_payId != null) ? null : () => _pay(p['price_id'] as int),
                    child: Text(isPro ? 'Extend' : 'Upgrade'),
                  ),
                ),
              )),
        ],
      ]),
    );
  }
}
