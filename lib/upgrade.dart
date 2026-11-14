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
  'lead_search': 'Find leads on Google',
  'pool_leads': 'Free daily leads',
  'video_post': 'Share experience videos',
  'poster_edit': 'Poster editing (photo, logo, layout)',
  'template_links': 'Own templates: links and longer text',
  'social_open': 'WhatsApp and Telegram chat links',
  'whatsapp': 'Automatic WhatsApp messages',
  'calls': 'Calls',
  'posters': 'Posters',
  'templates': 'Templates',
  'vcard_full': 'V-Card links and products',
  'ask_expert': 'Ask the expert (chat)',
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
    _coupon.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _payId != null) _checkPayment();
  }

  Map<String, dynamic> gw = {};
  int _sel = 0;
  final _coupon = TextEditingController();
  Map<String, dynamic>? _quote;
  String? _couponErr;

  String _rs(num v) => 'Rs ${v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2)}';

  Future<void> _applyCoupon(int priceId) async {
    final c = _coupon.text.trim();
    if (c.isEmpty) {
      setState(() { _quote = null; _couponErr = null; });
      return;
    }
    try {
      final d = Map<String, dynamic>.from(await Api.post('payments/quote', {'price_id': priceId, 'coupon': c}) as Map);
      setState(() {
        _quote = d['ok'] == true ? d : null;
        _couponErr = d['ok'] == true ? null : (d['error'] ?? 'Coupon not valid').toString();
      });
    } on ApiException catch (e) {
      setState(() { _quote = null; _couponErr = e.message; });
    }
  }

  Widget _card3d({required Widget child, required bool selected, required List<Color> colors}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        border: Border.all(color: selected ? const Color(0xFFFFD54F) : Colors.white24, width: selected ? 3 : 1),
        boxShadow: [
          BoxShadow(color: colors.last.withOpacity(0.55), blurRadius: selected ? 26 : 14, offset: Offset(0, selected ? 14 : 8)),
          const BoxShadow(color: Colors.white24, blurRadius: 2, offset: Offset(-2, -2)),
        ],
      ),
      child: child,
    );
  }

  Widget _priceCards(List prices) {
    if (prices.isEmpty) return const SizedBox();
    if (_sel >= prices.length) _sel = 0;
    final cur = Map<String, dynamic>.from(prices[_sel] as Map);
    final pid = cur['price_id'] as int;
    final payNow = (_quote != null ? _quote!['payable'] : cur['pay_now']) as num;
    final themes = [
      [const Color(0xFF14B8A6), const Color(0xFF0B4F4A)],
      [const Color(0xFF7C3AED), const Color(0xFF3B1A78)],
      [const Color(0xFFF59E0B), const Color(0xFF9A3412)],
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: const [
        Icon(Icons.workspace_premium, color: Color(0xFFF59E0B)),
        SizedBox(width: 6),
        Text('Choose your Pro plan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ]),
      for (var i = 0; i < prices.length; i++)
        Builder(builder: (_) {
          final p = Map<String, dynamic>.from(prices[i] as Map);
          final sel = i == _sel;
          final mrp = (p['mrp'] as num?) ?? 0;
          final intro = p['intro_active'] == true;
          final now = p['pay_now'] as num;
          final months = (p['months'] as num).toInt();
          final label = (p['offer_label'] ?? '').toString();
          return GestureDetector(
            onTap: () => setState(() { _sel = i; _quote = null; _couponErr = null; }),
            child: AnimatedScale(
              scale: sel ? 1.0 : 0.96,
              duration: const Duration(milliseconds: 200),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..setEntry(3, 2, 0.0008)..rotateX(sel ? 0.0 : 0.05),
                child: _card3d(
                  selected: sel,
                  colors: themes[i % themes.length].cast<Color>(),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: Colors.white),
                        const SizedBox(width: 8),
                        Text((p['label'] ?? p['period']).toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        if (label.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFFD54F), borderRadius: BorderRadius.circular(20)),
                            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
                          ),
                      ]),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_rs(now), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(2, 3))])),
                        const SizedBox(width: 8),
                        if (mrp > now || (intro && (p['amount'] as num) > now))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(_rs(mrp > now ? mrp : p['amount'] as num), style: const TextStyle(color: Colors.white70, decoration: TextDecoration.lineThrough)),
                          ),
                      ]),
                      if (intro)
                        Text('Intro price for ${p['intro_count']} purchase(s), then ${_rs(p['amount'] as num)}', style: const TextStyle(color: Colors.white, fontSize: 12))
                      else if (months > 1)
                        Text('Only ${_rs(now / months)} per month', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _coupon,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(labelText: 'Coupon code (optional)', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.local_offer_outlined), errorText: _couponErr),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: () => _applyCoupon(pid), child: const Text('Apply')),
      ]),
      if (_quote != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Coupon applied: you save ${_rs(_quote!['discount'] as num)}', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.w700)),
        ),
      const SizedBox(height: 12),
      if (isPro) const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('Buying again extends your Pro time.', style: TextStyle(color: Colors.black54))),
      if (gw['razorpay'] == true && gw['phonepe'] == true) ...[
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.workspace_premium),
          onPressed: _payId != null ? null : () => _pay(pid, 'razorpay'),
          label: Text('Pay ${_rs(payNow)}  (UPI / Card)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: _payId != null ? null : () => _pay(pid, 'phonepe'),
          child: Text('Pay ${_rs(payNow)} with PhonePe'),
        ),
      ] else
        FilledButton.icon(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.workspace_premium),
          onPressed: _payId != null ? null : () => _pay(pid, gw['phonepe'] == true ? 'phonepe' : null),
          label: Text('${isPro ? 'Extend' : 'Go Pro'} - Pay ${_rs(payNow)}'),
        ),
    ]);
  }

  Future<void> _pay(int priceId, [String? gateway]) async {
    try {
      final d = await Api.post('payments', {'price_id': priceId, if (gateway != null) 'gateway': gateway, if (_coupon.text.trim().isNotEmpty) 'coupon': _coupon.text.trim()});
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
      try {
        gw = Map<String, dynamic>.from(await Api.get('payments/gateways') as Map);
      } catch (_) {}
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
          _priceCards(prices),
          const SizedBox(height: 18),
          const Text('What you get', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
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
        ],
      ]),
    );
  }
}
