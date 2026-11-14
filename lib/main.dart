import 'package:flutter/material.dart';
import 'ads.dart';
import 'api.dart';
import 'auth_screens.dart';
import 'home.dart';
import 'upgrade.dart';

final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
const Color kBrand = Color(0xFF0F766E);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  Api.onUnauthorized = () {
    navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (r) => false,
    );
  };
  Api.onUpgrade = (m) {
    navKey.currentState?.push(MaterialPageRoute(builder: (_) => UpgradeScreen(message: m)));
  };
  runApp(const NetworkMitraApp());
}

class NetworkMitraApp extends StatelessWidget {
  const NetworkMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NetworkMitra',
      navigatorKey: navKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrand),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      // Keeps every screen out of the phone's bottom navigation bar (the top is handled by each screen's own app bar / SafeArea).
      builder: (context, child) => SafeArea(top: false, child: Column(children: [Expanded(child: child ?? const SizedBox()), const AdFooter()])),
      home: const Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    _ac.forward();
    _start();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final minShow = Future.delayed(const Duration(milliseconds: 1700));
    Widget next = const LoginScreen();
    if (Api.token != null) {
      try {
        await Api.refreshMe();
        next = const HomeScreen();
      } on ApiException catch (e) {
        // A wrong/expired login sends us to the login screen. No internet: still open the app.
        if (e.code == 'network') next = const HomeScreen();
      }
    }
    await minShow;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => next,
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scale = CurvedAnimation(parent: _ac, curve: Curves.elasticOut);
    final fade = CurvedAnimation(parent: _ac, curve: const Interval(0.0, 0.6, curve: Curves.easeIn));
    final textFade = CurvedAnimation(parent: _ac, curve: const Interval(0.5, 1.0, curve: Curves.easeIn));
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0B5D56), Color(0xFF0F766E), Color(0xFF14B8A6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),
            FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.4, end: 1).animate(scale),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 30, offset: Offset(0, 14))],
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(34), child: Image.asset('assets/logo_splash.png', width: 128, height: 128)),
                ),
              ),
            ),
            const SizedBox(height: 26),
            FadeTransition(
              opacity: textFade,
              child: const Column(children: [
                Text('NetworkMitra', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                SizedBox(height: 8),
                Text('Grow your network. Grow your business.', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: textFade,
              child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white70)),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
