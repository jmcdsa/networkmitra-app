import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';
import 'badge.dart';

/// Phone alerts (push notifications) through Firebase.
class PushService {
  static String? token;
  static bool _started = false;

  static const FirebaseOptions _options = FirebaseOptions(
    apiKey: 'AIzaSyCK3rJgc43IRSPR2_YqnHNFo2bF2SITIjo',
    appId: '1:80496493924:android:3f56e49c221d1332a52671',
    messagingSenderId: '80496493924',
    projectId: 'networkmitra-f4537',
    storageBucket: 'networkmitra-f4537.firebasestorage.app',
  );

  static Future<void> start() async {
    if (_started) return;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      final m = FirebaseMessaging.instance;
      await m.requestPermission();
      _started = true;
      token = await m.getToken();
      await _send();
      m.onTokenRefresh.listen((t) {
        token = t;
        _send();
      });
      // A message arriving while the app is open: update the red counting.
      FirebaseMessaging.onMessage.listen((_) => ChatBadge.refresh());
    } catch (_) {
      // Push is a bonus. If it fails the app still works.
    }
  }

  static Future<void> _send() async {
    final t = token;
    if (t == null || Api.token == null) return;
    try {
      await Api.post('me/device-token', {'platform': 'android', 'push_token': t});
    } catch (_) {}
  }
}
