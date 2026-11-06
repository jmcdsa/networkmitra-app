import 'package:flutter/material.dart';
import 'api.dart';
import 'home.dart';
import 'widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final pass = TextEditingController();
  bool busy = false;
  String? error;

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await Api.post('auth/login', {
        'email': email.text.trim(),
        'password': pass.text,
        'device_name': 'Android app',
      });
      await Api.setToken(d['token'] as String);
      Api.user = Map<String, dynamic>.from(d['user'] as Map);
      Api.plan = Map<String, dynamic>.from(d['plan'] as Map);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _forgot() async {
    final c = TextEditingController(text: email.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot password'),
        content: TextField(controller: c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Your email')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send link')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.post('auth/forgot-password', {'email': c.text.trim()});
      if (mounted) toast(context, 'If this email is registered, a reset link has been sent.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('NetworkMitra', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F766E))),
                const SizedBox(height: 4),
                const Text('The app for direct sellers', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                field(email, 'Email', type: TextInputType.emailAddress),
                field(pass, 'Password', secret: true),
                if (error != null)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
                BigButton('Log in', busy: busy, onTap: _login),
                TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
                const Divider(),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('New here? Create account'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final pass = TextEditingController();
  final city = TextEditingController();
  final ref = TextEditingController();
  List<Map<String, dynamic>> companies = [];
  Map<String, dynamic>? company;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final d = await Api.get('companies');
      setState(() => companies = (d as List).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    } on ApiException catch (e) {
      setState(() => error = e.message);
    }
  }

  Future<void> _pickCompany() async {
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(builder: (ctx, setS) {
          final list = companies.where((c) => c['name'].toString().toLowerCase().contains(q.toLowerCase())).toList();
          return AlertDialog(
            title: const Text('Choose your company'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search'),
                  onChanged: (v) => setS(() => q = v),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('Not found'))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(list[i]['name'].toString()),
                            onTap: () => Navigator.pop(ctx, list[i]),
                          ),
                        ),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
          );
        });
      },
    );
    if (picked != null) setState(() => company = picked);
  }

  Future<void> _requestCompany() async {
    final cn = TextEditingController();
    final ce = TextEditingController(text: email.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Company not in the list?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: cn, decoration: const InputDecoration(labelText: 'Company name')),
          const SizedBox(height: 10),
          TextField(controller: ce, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Your email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send request')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final d = await Api.post('company-requests', {'company_name': cn.text.trim(), 'email': ce.text.trim()});
      if (mounted) toast(context, (d['message'] ?? 'Request sent.').toString());
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  Future<void> _register() async {
    if (company == null) {
      setState(() => error = 'Please choose your company.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final d = await Api.post('auth/register', {
        'name': name.text.trim(),
        'email': email.text.trim(),
        'mobile': mobile.text.trim(),
        'password': pass.text,
        'city': city.text.trim(),
        'company_id': company!['id'],
        'referral_code': ref.text.trim(),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Almost done'),
          content: Text((d['message'] ?? 'Account created.').toString()),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => error = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          field(name, 'Full name'),
          field(email, 'Email', type: TextInputType.emailAddress),
          field(mobile, 'Mobile number', type: TextInputType.phone),
          field(pass, 'Password (8 or more letters)', secret: true),
          field(city, 'City (optional)'),
          InkWell(
            onTap: _pickCompany,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Your company', suffixIcon: Icon(Icons.arrow_drop_down)),
              child: Text(company == null ? 'Tap to choose' : company!['name'].toString()),
            ),
          ),
          TextButton(onPressed: _requestCompany, child: const Align(alignment: Alignment.centerLeft, child: Text('My company is not in the list'))),
          const SizedBox(height: 6),
          field(ref, 'Referral code (optional)'),
          const Text('You can only connect and chat with people of the company you choose. It cannot be changed later.', style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 14),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          BigButton('Create account', busy: busy, onTap: _register),
        ]),
      ),
    );
  }
}
