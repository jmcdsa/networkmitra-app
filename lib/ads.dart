import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

/// Home slideshow banners and the ad settings, given by the owner from the admin panel.
class HomeConfig {
  static final ValueNotifier<Map<String, dynamic>?> data = ValueNotifier(null);

  static Future<void> load() async {
    try {
      data.value = Map<String, dynamic>.from(await Api.get('home/banners') as Map);
    } catch (_) {}
  }

  static void clear() => data.value = null;

  static Map<String, dynamic> get _ads {
    final a = data.value?['ads'];
    return a is Map ? Map<String, dynamic>.from(a) : <String, dynamic>{};
  }

  static bool get adsOn => false;
  static bool get slideAd => false;
  static String get footerUnit => (_ads['footer_unit'] ?? '').toString();
  static String get slideUnit => (_ads['slide_unit'] ?? '').toString();

  static List<Map<String, dynamic>> get banners {
    final b = data.value?['banners'];
    if (b is! List) return [];
    return b.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

/// Ads are switched off in this version of the app (the AdMob plugin is not included). The admin ad settings are kept for later.
class AdBanner extends StatelessWidget {
  final String unit;
  const AdBanner({super.key, required this.unit});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class AdFooter extends StatelessWidget {
  const AdFooter({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// The sliding banners at the top of Home (own banners, and one ad slide if the owner switched it on).
class BannerSlideshow extends StatefulWidget {
  const BannerSlideshow({super.key});
  @override
  State<BannerSlideshow> createState() => _BannerSlideshowState();
}

class _BannerSlideshowState extends State<BannerSlideshow> {
  final PageController _pc = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pc.hasClients) return;
      final n = _count();
      if (n < 2) return;
      _pc.animateToPage((_page + 1) % n, duration: const Duration(milliseconds: 450), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  int _count() => HomeConfig.banners.length + (HomeConfig.adsOn && HomeConfig.slideAd ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: HomeConfig.data,
      builder: (context, _, __) {
        final banners = HomeConfig.banners;
        final withAd = HomeConfig.adsOn && HomeConfig.slideAd;
        final n = banners.length + (withAd ? 1 : 0);
        if (n == 0) return const SizedBox.shrink();
        return Column(children: [
          AspectRatio(
            aspectRatio: 12 / 5,
            child: PageView.builder(
              controller: _pc,
              itemCount: n,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                if (i >= banners.length) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
                    alignment: Alignment.center,
                    child: AdBanner(unit: HomeConfig.slideUnit),
                  );
                }
                final b = banners[i];
                final link = (b['link_url'] ?? '').toString();
                return GestureDetector(
                  onTap: link.isEmpty ? null : () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.black12),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      b['image_url'].toString(),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported_outlined)),
                    ),
                  ),
                );
              },
            ),
          ),
          if (n > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < n; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: i == _page ? const Color(0xFF0F766E) : Colors.black26, borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
            ),
        ]);
      },
    );
  }
}
