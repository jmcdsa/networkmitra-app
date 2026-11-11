import 'package:flutter/material.dart';

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c).hideCurrentSnackBar();
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
}

class BigButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool busy;
  const BigButton(this.text, {super.key, this.onTap, this.busy = false});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

Widget field(TextEditingController c, String label,
    {bool secret = false, TextInputType? type, int lines = 1}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      obscureText: secret,
      keyboardType: type,
      maxLines: secret ? 1 : lines,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final d = DateTime.parse(iso).toLocal();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${m[d.month - 1]}, $h:$mm ${d.hour >= 12 ? 'PM' : 'AM'}';
  } catch (_) {
    return iso;
  }
}

const List<List<String>> kCountries = [
  ['India', '91'], ['United States / Canada', '1'], ['United Kingdom', '44'], ['United Arab Emirates', '971'], ['Saudi Arabia', '966'],
  ['Qatar', '974'], ['Kuwait', '965'], ['Oman', '968'], ['Bahrain', '973'], ['Nepal', '977'], ['Bangladesh', '880'], ['Sri Lanka', '94'],
  ['Pakistan', '92'], ['Bhutan', '975'], ['Maldives', '960'], ['Afghanistan', '93'], ['Singapore', '65'], ['Malaysia', '60'],
  ['Thailand', '66'], ['Indonesia', '62'], ['Philippines', '63'], ['Vietnam', '84'], ['Japan', '81'], ['South Korea', '82'], ['China', '86'],
  ['Hong Kong', '852'], ['Australia', '61'], ['New Zealand', '64'], ['Fiji', '679'], ['Mauritius', '230'], ['South Africa', '27'],
  ['Kenya', '254'], ['Nigeria', '234'], ['Ghana', '233'], ['Egypt', '20'], ['Turkey', '90'], ['Russia', '7'], ['Germany', '49'],
  ['France', '33'], ['Italy', '39'], ['Spain', '34'], ['Netherlands', '31'], ['Ireland', '353'], ['Brazil', '55'], ['Mexico', '52'],
];

/// Mobile number with a country code list. [controller] holds the whole number:
/// an Indian number as plain digits (9876543210), any other country as +<code><digits>.
class PhoneField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  const PhoneField({super.key, required this.controller, this.label = 'Mobile number'});
  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  final local = TextEditingController();
  String code = '91';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _parse();
    widget.controller.addListener(_outside);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_outside);
    local.dispose();
    super.dispose();
  }

  String _compose() {
    final d = local.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return '';
    return code == '91' ? d : '+$code$d';
  }

  void _parse() {
    final t = widget.controller.text.trim();
    if (t.startsWith('+')) {
      final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
      String? best;
      for (final c in kCountries) {
        if (digits.startsWith(c[1]) && (best == null || c[1].length > best.length)) best = c[1];
      }
      if (best != null) {
        code = best;
        local.text = digits.substring(best.length);
        return;
      }
    }
    code = '91';
    var d = t.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
    local.text = d;
  }

  void _outside() {
    if (_busy) return;
    if (widget.controller.text != _compose()) {
      _parse();
      if (mounted) setState(() {});
    }
  }

  void _push() {
    _busy = true;
    widget.controller.text = _compose();
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 104,
          child: DropdownButtonFormField<String>(
            value: code,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Country'),
            selectedItemBuilder: (_) => [for (final c in kCountries) Text('+${c[1]}', overflow: TextOverflow.ellipsis)],
            items: [for (final c in kCountries) DropdownMenuItem(value: c[1], child: Text('${c[0]} +${c[1]}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v == null) return;
              setState(() => code = v);
              _push();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: local,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: widget.label),
            onChanged: (_) => _push(),
          ),
        ),
      ]),
    );
  }
}
