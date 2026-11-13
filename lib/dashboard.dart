import 'package:flutter/material.dart';
import 'ads.dart';
import 'api.dart';
import 'lead_finder.dart';
import 'more.dart';
import 'notifications.dart';
import 'pool_leads.dart';
import 'upgrade.dart';
import 'videos.dart';
import 'whatsapp.dart';
import 'widgets.dart';

/// Lets a Home tile switch the bottom tab (Home screen listens to this).
class HomeNav {
  static final ValueNotifier<int?> request = ValueNotifier<int?>(null);
  static void go(int tab) => request.value = tab;
}

class _Tile {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final bool locked;
  final VoidCallback onTap;
  const _Tile(this.title, this.icon, this.colors, this.onTap, {this.locked = false});
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  Map<String, dynamic>? summary;
  List<Map<String, dynamic>> today = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    HomeConfig.load();
    try {
      await Api.refreshMe();
    } catch (_) {}
    try {
      final s = await Api.get('crm/summary');
      final f = await Api.get('followups', query: {'due': 'today'});
      if (!mounted) return;
      setState(() {
        summary = Map<String, dynamic>.from(s as Map);
        today = (f as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.message);
    }
    if (mounted) setState(() {});
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Widget _header() {
    final name = (Api.user?['name'] ?? '').toString();
    final photo = Api.user?['photo_url']?.toString();
    final co = Api.user?['company'] is Map ? ((Api.user!['company'] as Map)['name'] ?? '').toString() : '';
    final pro = isPro;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFCCEFEA),
            backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
            child: (photo == null || photo.isEmpty)
                ? Text(name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F766E)))
                : null,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hello,', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: pro ? const Color(0xFFFFC857) : Colors.white24, borderRadius: BorderRadius.circular(10)),
                child: Text(pro ? 'PRO' : 'FREE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: pro ? Colors.black87 : Colors.white)),
              ),
              if (co.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(co, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12))),
              ],
            ]),
          ]),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.white),
          onPressed: () => _push(const NotificationsScreen()),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, IconData icon, Color c) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ]),
      ),
    );
  }

  Widget _tileWidget(_Tile t) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: t.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: t.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(t.icon, color: Colors.white, size: 28),
            ),
            if (t.locked)
              const Positioned(right: -6, top: -6, child: CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Icon(Icons.lock, size: 13, color: Colors.black54))),
          ]),
          const SizedBox(height: 8),
          Text(t.title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  List<_Tile> _tiles() {
    void gated(String key, String msg, Widget screen) {
      if (!featureOn(key)) {
        goUpgrade(context, msg);
      } else {
        _push(screen);
      }
    }

    return [
      _Tile('My clients', Icons.people_alt_rounded, const [Color(0xFF0F766E), Color(0xFF2DD4BF)], () => HomeNav.go(1)),
      _Tile('Free leads', Icons.card_giftcard_rounded, const [Color(0xFFEA580C), Color(0xFFFBBF24)], () => gated('pool_leads', 'Free daily leads are available on the Pro plan.', const PoolLeadsScreen()),
          locked: !featureOn('pool_leads')),
      _Tile('Find leads', Icons.travel_explore_rounded, const [Color(0xFF2563EB), Color(0xFF60A5FA)], () => gated('lead_search', 'Finding new leads on Google is available on the Pro plan.', const LeadFinderScreen()),
          locked: !featureOn('lead_search')),
      _Tile('Targets & sales', Icons.flag_rounded, const [Color(0xFFDC2626), Color(0xFFFB7185)], () => _push(const TargetsScreen())),
      _Tile('Digital V-Card', Icons.badge_rounded, const [Color(0xFF7C3AED), Color(0xFFA78BFA)], () => _push(const VCardScreen())),
      _Tile('Product catalogue', Icons.storefront_rounded, const [Color(0xFFDB2777), Color(0xFFF472B6)], () => _push(const VCardScreen())),
      _Tile('Posters & templates', Icons.photo_library_rounded, const [Color(0xFF0891B2), Color(0xFF22D3EE)], () => HomeNav.go(4)),
      _Tile('Videos', Icons.play_circle_fill_rounded, const [Color(0xFFE11D48), Color(0xFFFB923C)], () => _push(Scaffold(appBar: AppBar(title: const Text('Videos')), body: const VideosTab()))),
      _Tile('Community & chat', Icons.forum_rounded, const [Color(0xFF059669), Color(0xFF34D399)], () => HomeNav.go(2)),
      _Tile('Learn', Icons.menu_book_rounded, const [Color(0xFF4F46E5), Color(0xFF818CF8)], () => HomeNav.go(3)),
      _Tile('My WhatsApp API', Icons.chat_rounded, const [Color(0xFF16A34A), Color(0xFF4ADE80)], () => _push(const WaSetupScreen())),
      _Tile(isPro ? 'My plan' : 'Go Pro', Icons.workspace_premium_rounded, const [Color(0xFFCA8A04), Color(0xFFFACC15)], () => goUpgrade(context)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final tiles = _tiles();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: EdgeInsets.zero, children: [
        _header(),
        const SizedBox(height: 16),
        const BannerSlideshow(),
        const SizedBox(height: 12),
        if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: const TextStyle(color: Colors.red))),
        if (s != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              _stat('Clients', '${s['total_clients']}', Icons.people, const Color(0xFF0F766E)),
              _stat('Sales won', '${s['closed_won']}', Icons.emoji_events, const Color(0xFFD97706)),
              _stat('Follow-ups today', '${today.length}', Icons.alarm, const Color(0xFFDC2626)),
            ]),
          ),
        const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 10), child: Text('Everything in one place', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final t in tiles) _tileWidget(t)],
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(20, 22, 20, 6), child: Text("Today's follow-ups", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        if (today.isEmpty)
          const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 8), child: Text('Nothing due today. Enjoy!', style: TextStyle(color: Colors.black54))),
        ...today.map((f) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(f['lead_name'].toString()),
                subtitle: Text('${fmtDate(f['due_at'] as String?)}${(f['note'] ?? '').toString().isEmpty ? '' : '\n${f['note']}'}'),
                isThreeLine: (f['note'] ?? '').toString().isNotEmpty,
                trailing: IconButton(
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: () async {
                    try {
                      await Api.put('followups/${f['id']}', {'done': true});
                      _load();
                    } on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  },
                ),
              ),
            )),
        if (s != null && (s['by_status'] as List).isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 8), child: Text('Clients by stage', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final b in (s['by_status'] as List)) Chip(label: Text('${b['name']}  ${b['count']}')),
            ]),
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}
