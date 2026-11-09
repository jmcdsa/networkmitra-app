import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'widgets.dart';

/// Opens a chat in WhatsApp or WhatsApp Business (the person picks which one).
Future<void> openWhatsApp(BuildContext context, String number, String text) async {
  final n = number.replaceAll(RegExp(r'[^0-9]'), '');
  final sp = await SharedPreferences.getInstance();
  var which = sp.getString('wa_app');
  if (which == null && context.mounted) {
    which = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Open in which app?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
          ListTile(leading: const Icon(Icons.chat, color: Color(0xFF25D366)), title: const Text('WhatsApp'), onTap: () => Navigator.pop(ctx, 'com.whatsapp')),
          ListTile(leading: const Icon(Icons.business_center, color: Color(0xFF128C7E)), title: const Text('WhatsApp Business'), onTap: () => Navigator.pop(ctx, 'com.whatsapp.w4b')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (which == null) return;
    await sp.setString('wa_app', which);
  }
  final url = 'https://wa.me/$n${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}';
  try {
    await AndroidIntent(action: 'action_view', data: url, package: which).launch();
  } catch (_) {
    // That app is not installed: let the phone choose.
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) toast(context, 'Could not open WhatsApp.');
    }
  }
}

Future<void> forgetWhatsAppChoice() async {
  final sp = await SharedPreferences.getInstance();
  await sp.remove('wa_app');
}

/// Where each seller adds his or her own WhatsApp Business API details.
class WaSetupScreen extends StatefulWidget {
  const WaSetupScreen({super.key});
  @override
  State<WaSetupScreen> createState() => _WaSetupScreenState();
}

class _WaSetupScreenState extends State<WaSetupScreen> {
  final phone = TextEditingController();
  final token = TextEditingController();
  final tpl = TextEditingController();
  final lang = TextEditingController(text: 'en');
  bool loading = true, saving = false, tokenSet = false, adminOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.get('me/whatsapp');
      phone.text = (d['phone_id'] ?? '').toString();
      tpl.text = (d['template'] ?? '').toString();
      lang.text = (d['template_lang'] ?? 'en').toString();
      tokenSet = d['token_set'] == true;
      adminOn = d['admin_enabled'] != false;
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await Api.put('me/whatsapp', {
        'phone_id': phone.text.trim(),
        'token': token.text.trim(),
        'template': tpl.text.trim(),
        'template_lang': lang.text.trim().isEmpty ? 'en' : lang.text.trim(),
      });
      token.clear();
      tokenSet = true;
      if (mounted) toast(context, 'Saved. You can now use "Send automatically" on a client.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() => saving = false);
  }

  Future<void> _remove() async {
    try {
      await Api.delete('me/whatsapp');
      phone.clear();
      token.clear();
      tpl.clear();
      tokenSet = false;
      if (mounted) toast(context, 'Removed.');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My WhatsApp API'), actions: [
        IconButton(
          tooltip: 'Choose WhatsApp / Business again',
          icon: const Icon(Icons.swap_horiz),
          onPressed: () async {
            await forgetWhatsAppChoice();
            if (mounted) toast(context, 'You will be asked again next time you press Open WhatsApp.');
          },
        ),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              if (!adminOn)
                const Card(color: Color(0xFFFFF4E5), child: Padding(padding: EdgeInsets.all(12), child: Text('Automatic WhatsApp is switched off by the admin for now. "Open WhatsApp" still works.'))),
              const Text('Send WhatsApp messages to your clients automatically, from your own WhatsApp Business number, using Meta\'s free WhatsApp Cloud API. Your details are used only to send your own messages.', style: TextStyle(height: 1.4)),
              const SizedBox(height: 12),
              field(phone, 'Phone number ID', type: TextInputType.number),
              field(token, tokenSet ? 'Access token (saved - leave empty to keep)' : 'Access token', secret: true),
              field(tpl, 'Template name (optional)'),
              field(lang, 'Template language (en, hi ...)'),
              FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving...' : 'Save')),
              if (tokenSet) TextButton(onPressed: _remove, child: const Text('Remove my WhatsApp API')),
              const SizedBox(height: 16),
              const Divider(),
              const Text('How to connect (one time)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                '1. Open developers.facebook.com and log in with Facebook. Press My Apps > Create App > type "Business".\n\n'
                '2. In the app, press Add Product > WhatsApp > Set up. Link or create a Meta Business account.\n\n'
                '3. Under WhatsApp > API Setup add your own phone number (it must not be active in the WhatsApp app; use a number only for business) and verify it with the code.\n\n'
                '4. On the same API Setup page, copy the "Phone number ID" (digits). Paste it above.\n\n'
                '5. Permanent token: business.facebook.com > Business Settings > Users > System Users > Add. Give it your app with full control, press Generate Token, select the app, tick whatsapp_business_messaging and whatsapp_business_management, and copy the token. Paste it above. (The 24 hour token shown on the API Setup page stops working after a day.)\n\n'
                '6. Add a payment method in Meta (WhatsApp Manager). Meta gives some free conversations every month, then charges per conversation.\n\n'
                '7. Template (for clients who have not messaged you in the last 24 hours): WhatsApp Manager > Message Templates > Create. Category "Utility" or "Marketing", language English or Hindi. In the body write only {{1}} and add a sample. After Meta approves it, type its name and language above. Without a template, messages reach only clients who wrote to you in the last 24 hours.\n\n'
                '8. Open a client > WhatsApp > write the message > Send automatically.',
                style: TextStyle(height: 1.45),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Meta developers link'),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'https://developers.facebook.com/apps'));
                  toast(context, 'Link copied.');
                },
              ),
            ]),
    );
  }
}
