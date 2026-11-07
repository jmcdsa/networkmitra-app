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
