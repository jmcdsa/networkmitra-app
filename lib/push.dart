import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api.dart';
import 'badge.dart';
import 'call.dart';
import 'chat.dart';
import 'main.dart' show navKey;
import 'ringer.dart';

/// Phone alerts (push notifications) through Firebase.
class PushService {
  static String? token;
  static bool _started = false;

  static const FirebaseOptions options = FirebaseOptions(
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
        await Firebase.initializeApp(options: options);
      }
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
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
      FirebaseMessaging.onMessage.listen((msg) {
        ChatBadge.refresh();
        if (msg.data['type'] == 'call') CallWatcher.check();
      });
      // The person taps an alert: open the right chat or the call screen.
      FirebaseMessaging.onMessageOpenedApp.listen(_opened);
      final first = await m.getInitialMessage();
      if (first != null) {
        Future.delayed(const Duration(milliseconds: 1500), () => _opened(first));
      }
    } catch (_) {
      // Push is a bonus. If it fails the app still works.
    }
  }

  static Future<void> _opened(RemoteMessage msg) async {
    if (Api.token == null) return;
    final type = msg.data['type'];
    try {
      if (type == 'call') {
        CallWatcher.check();
      } else if (type == 'message') {
        final id = int.tryParse((msg.data['conversation_id'] ?? '').toString());
        if (id == null) return;
        final list = asList(await Api.get('conversations'));
        final c = list.where((e) => e['id'] == id).toList();
        if (c.isEmpty) return;
        final other = c.first['other_user'] is Map ? (c.first['other_user'] as Map)['id'] as int? : null;
        navKey.currentState?.push(MaterialPageRoute(
          builder: (_) => ChatScreen(convId: id, title: c.first['title'].toString(), otherUserId: other),
        ));
      }
    } catch (_) {}
  }

  static Future<void> _send() async {
    final t = token;
    if (t == null || Api.token == null) return;
    try {
      await Api.post('me/device-token', {'platform': 'android', 'push_token': t});
    } catch (_) {}
  }
}
