import 'package:flutter/foundation.dart';
import 'api.dart';

/// Number shown in red on the Chats tab: unread messages + new connection requests.
class ChatBadge {
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      final convs = await Api.get('conversations') as List;
      var n = 0;
      for (final c in convs) {
        n += ((c as Map)['unread'] ?? 0) as int;
      }
      final req = await Api.get('connections', query: {'status': 'incoming'}) as List;
      count.value = n + req.length;
    } catch (_) {
      // keep the old number if the phone is offline
    }
  }
}
