import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'push.dart';

/// Shows a ringing "incoming call" alert, also when the app is closed.
final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _ready = false;

const String kCallChannel = 'nm_calls_v1';

Future<void> _init() async {
  if (_ready) return;
  await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(const AndroidNotificationChannel(
    kCallChannel,
    'Incoming calls',
    description: 'Rings when someone calls you',
    importance: Importance.max,
    playSound: true,
    sound: UriAndroidNotificationSound('content://settings/system/ringtone'),
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    enableVibration: true,
  ));
  _ready = true;
}

int _idFor(String callId) => 7000 + (int.tryParse(callId) ?? 0) % 100000;

/// Runs in the background when a push arrives and the app is closed.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage m) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: PushService.options);
  }
  await handleCallPush(m);
}

Future<void> handleCallPush(RemoteMessage m) async {
  final d = m.data;
  final type = d['type'];
  if (type != 'call' && type != 'call_cancel') return;
  await _init();
  final callId = (d['call_id'] ?? '0').toString();
  if (type == 'call_cancel') {
    await _plugin.cancel(_idFor(callId));
    return;
  }
  final video = d['video'] == '1';
  await _plugin.show(
    _idFor(callId),
    (d['caller'] ?? 'Someone').toString(),
    'Incoming ${video ? 'video' : 'audio'} call',
    NotificationDetails(
      android: AndroidNotificationDetails(
        kCallChannel,
        'Incoming calls',
        channelDescription: 'Rings when someone calls you',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: true,
        timeoutAfter: 45000,
        visibility: NotificationVisibility.public,
        sound: const UriAndroidNotificationSound('content://settings/system/ringtone'),
        audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
        additionalFlags: Int32List.fromList(<int>[4]), // keep ringing until answered
      ),
    ),
  );
}

/// Remove any call alert (the app is open and shows the call screen itself).
Future<void> clearCallAlerts() async {
  try {
    await _init();
    await _plugin.cancelAll();
  } catch (_) {}
}
