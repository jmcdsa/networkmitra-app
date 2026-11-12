import 'package:flutter/material.dart';
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
      builder: (context, child) => SafeArea(top: false, child: child ?? const SizedBox()),
      home: const Splash(),
    );
  }
}

class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
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
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
