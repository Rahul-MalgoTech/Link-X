import 'dart:async';

import 'package:bossy/BossyServices/linkx_chat_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LinkxNotificationService {
  LinkxNotificationService._();

  static final LinkxNotificationService instance = LinkxNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<LinkxNotification>? _subscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: darwin),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    _subscription = LinkxChatService.instance.notifications.listen(show);
    _initialized = true;
  }

  Future<void> show(LinkxNotification notification) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'linkx_general',
        'Linkx Notifications',
        channelDescription: 'Matches, messages, events, rooms, and billing.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      id: notification.id.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}
