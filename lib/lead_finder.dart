import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'chat.dart' show asList;
import 'widgets.dart';

/// Find new leads on Google (shops, clinics, salons...) and add them to my clients.
class LeadFinderScreen extends StatefulWidget {
  const LeadFinderScreen({super.key});
  @override
  State<LeadFinderScreen> createState() => _LeadFinderScreenState();
}

class _LeadFinderScreenState extends State<LeadFinderScreen> {
  final q = TextEditingController();
  List<Map<String, dynamic>> items = [];
  String nextToken = '';
  bool busy = false, searched = false;
  String lastQuery = '';
  final Set<String> added = {};

  Future<void> _search({bool more = false}) async {
    final text = more ? lastQuery : q.text.trim();
    if (text.length < 3) {
      toast(context, 'Write what you are looking for, for example: beauty parlour in Jaipur.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => busy = true);
    try {
      final d = await Api.post('leads/search', {'query': text, if (more) 'page_token': nextToken});
      final list = asList(d['items']);
      lastQuery = text;
      nextToken = (d['next_page_token'] ?? '').toString();
      if (more) {
        items.addAll(list);
      } else {
        items = list;
        added.clear();
      }
      searched = true;
    } on ApiException catch (e) {
      if (mounted && e.status != 402) toast(context, e.code == 'places_off' ? 'The lead finder is not switched on yet.' : e.message);
    }
    if (mounted) setState(() => busy = false);
  }

  String _mobile(String phone) {
    final plus = phone.trim().startsWith('+');
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (plus && d.startsWith('91') && d.length == 12) return d.substring(2);
    if (plus) return '+$d';
    return d.replaceFirst(RegExp(r'^0+'), '');
  }

  Future<void> _add(Map<String, dynamic> p) async {
    final phone = (p['phone'] ?? '').toString();
    if (phone.isEmpty) {
      toast(context, 'This place has no phone number on Google.');
      return;
    }
    try {
      await Api.post('leads', {
        'name': p['name'].toString(),
        'mobile': _mobile(phone),
        'city': '',
        'product_interest': '',
        'notes': 'Found on Google. ${p['address'] ?? ''}${(p['website'] ?? '').toString().isNotEmpty ? '\n${p['website']}' : ''}',
      });
      added.add(p['place_id'].toString());
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
    return Scaffold(
      appBar: AppBar(title: const Text('Find leads on Google')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Example: beauty parlour in Jaipur',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: busy ? null : _search),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Write the type of business and the city. Each search counts once. Contact only people who may really need your product, and respect their wish if they say no.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(searched ? 'No places found. Try other words.' : 'Search to see businesses with phone numbers.'))
              : ListView(padding: const EdgeInsets.all(12), children: [
                  for (final p in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['name'].toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          if (p['address'].toString().isNotEmpty) Text(p['address'].toString(), style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(p['phone'].toString().isEmpty ? 'No phone on Google' : p['phone'].toString()),
                          if (p['rating'] != null) Text('Rating ${p['rating']}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          const SizedBox(height: 6),
                          Wrap(spacing: 8, children: [
                            if (p['exists'] == true || added.contains(p['place_id'].toString()))
                              const Chip(label: Text('In your clients'), avatar: Icon(Icons.check, size: 16))
                            else
                              FilledButton.icon(onPressed: () => _add(p), icon: const Icon(Icons.person_add_alt), label: const Text('Add to clients')),
                            if (p['maps_url'].toString().isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => launchUrl(Uri.parse(p['maps_url'].toString()), mode: LaunchMode.externalApplication),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Map'),
                              ),
                          ]),
                        ]),
                      ),
                    ),
                  if (nextToken.isNotEmpty)
                    Padding(padding: const EdgeInsets.all(8), child: OutlinedButton(onPressed: busy ? null : () => _search(more: true), child: const Text('Show more (counts as one more search)'))),
                ]),
        ),
      ]),
    );
  }
}
