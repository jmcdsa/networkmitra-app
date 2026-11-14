import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
import 'ads.dart';
import 'upgrade.dart';
import 'widgets.dart';

/// Full-width Home button "Ask <expert>". Shown only when the owner has switched it on.
class ExpertButton extends StatelessWidget {
  const ExpertButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: HomeConfig.data,
      builder: (context, d, _) {
        final e = d?['expert'];
        if (e is! Map || e['enabled'] != true) return const SizedBox.shrink();
        final name = (e['name'] ?? 'Mr. Deepak Sharma').toString();
        final sub = (e['subtitle'] ?? '').toString();
        final img = (e['image_url'] ?? '').toString();
        final allowed = e['allowed'] == true;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: GestureDetector(
            onTap: () {
              if (!allowed) {
                goUpgrade(context, 'Asking the expert is available on the Pro plan.');
              } else {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpertChatScreen(name: name, imageUrl: img)));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0B4F4A), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white38),
                boxShadow: const [
                  BoxShadow(color: Color(0x660B4F4A), blurRadius: 18, offset: Offset(0, 10)),
                  BoxShadow(color: Colors.white54, blurRadius: 2, offset: Offset(-1.5, -1.5)),
                ],
              ),
              child: Row(children: [
                _avatar(img, 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ask $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 2))])),
                    if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                ),
                if (!allowed) const Icon(Icons.lock, color: Colors.white70, size: 20) else const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
              ]),
            ),
          ),
        );
      },
    );
  }
}

Widget _avatar(String img, double r) => Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: CircleAvatar(
        radius: r,
        backgroundColor: const Color(0xFFCCEFEA),
        backgroundImage: img.isNotEmpty ? NetworkImage(img) : null,
        child: img.isEmpty ? const Icon(Icons.support_agent, color: Color(0xFF0F766E)) : null,
      ),
    );

/// Simple chat with the expert. The expert's answers are written in the admin panel.
class ExpertChatScreen extends StatefulWidget {
  final String name;
  final String imageUrl;
  const ExpertChatScreen({super.key, required this.name, required this.imageUrl});
  @override
  State<ExpertChatScreen> createState() => _ExpertChatScreenState();
}

class _ExpertChatScreenState extends State<ExpertChatScreen> {
  final List<Map<String, dynamic>> _msgs = [];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _timer;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  int get _lastId => _msgs.isEmpty ? 0 : (_msgs.last['id'] as int);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final d = Map<String, dynamic>.from(await Api.get('expert/messages', query: {'after': '$_lastId'}) as Map);
      final list = (d['messages'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (!mounted) return;
      setState(() {
        _msgs.addAll(list);
        _loading = false;
        _error = null;
      });
      if (list.isNotEmpty) _toEnd();
    } on ApiException catch (e) {
      if (mounted && !quiet) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted && !quiet) setState(() { _loading = false; _error = 'Could not load. Check your internet.'; });
    }
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final t = _ctl.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = Map<String, dynamic>.from(await Api.post('expert/messages', {'body': t}) as Map);
      _ctl.clear();
      await _load(quiet: true);
      if (_msgs.isEmpty || _lastId < (m['id'] as int)) setState(() => _msgs.add(m));
      _toEnd();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          _avatar(widget.imageUrl, 16),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.name, overflow: TextOverflow.ellipsis)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(12),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final m = _msgs[i];
                        final mine = m['from'] == 'user';
                        return Align(
                          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: mine ? const Color(0xFF0F766E) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 3))],
                            ),
                            child: Text((m['body'] ?? '').toString(), style: TextStyle(color: mine ? Colors.white : Colors.black87, fontSize: 15)),
                          ),
                        );
                      },
                    ),
        ),
        if (_error == null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 1500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Ask anything about direct selling', counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))), contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
      ]),
    );
  }
}
