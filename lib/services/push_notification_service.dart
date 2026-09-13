import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';
import 'token_storage.dart';

const _notificationChannelId = 'challenge_notifications';
const _notificationChannelName = 'Challenge notifications';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> _initializeLocalNotifications() async {
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _localNotifications.initialize(settings);
  await _localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _notificationChannelId,
          _notificationChannelName,
          description: 'Notifications about challenge invitations.',
          importance: Importance.high,
        ),
      );
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final data = message.data;
  await _localNotifications.show(
    message.hashCode,
    notification?.title ?? data['title'] ?? 'New notification',
    notification?.body ?? data['body'] ?? 'You have a new update.',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _notificationChannelId,
        _notificationChannelName,
        channelDescription: 'Notifications about challenge invitations.',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _initializeLocalNotifications();
  if (message.notification == null) {
    await _showLocalNotification(message);
  }
}

class PushNotificationService {
  final ApiClient api;
  final TokenStorage tokenStorage;

  Future<void>? _initialization;
  StreamSubscription<String>? _tokenRefreshSubscription;
  VoidCallback? onNotificationReceived;

  PushNotificationService({required this.api, required this.tokenStorage});

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Web requires Firebase web options and a messaging service worker.
      // Notification setup must never block the main app when those are not
      // configured yet.
      if (kIsWeb) return;

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      await _initializeLocalNotifications();
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) async {
        await _showLocalNotification(message);
        onNotificationReceived?.call();
      });
      _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
        registerToken,
      );
      await _registerCurrentToken();
    } catch (error) {
      debugPrint('Push notification setup skipped: $error');
    }
  }

  Future<void> registerCurrentToken() async {
    if (kIsWeb) return;
    await initialize();
    await _registerCurrentToken();
  }

  Future<void> _registerCurrentToken() async {
    if (kIsWeb) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await registerToken(token);
    } catch (error) {
      debugPrint('FCM token registration skipped: $error');
    }
  }

  Future<void> registerToken(String token) async {
    final accessToken = await tokenStorage.accessToken;
    if (accessToken == null) return;

    try {
      await api.post(
        '/users/me/push-tokens',
        data: {'token': token, 'platform': _platform},
      );
      await tokenStorage.savePushToken(token);
    } catch (error) {
      debugPrint('FCM token API registration skipped: $error');
    }
  }

  Future<void> unregisterCurrentToken() async {
    final token = await tokenStorage.pushToken;
    if (token == null) return;

    try {
      await api.delete(
        '/users/me/push-tokens/${Uri.encodeComponent(token)}',
      );
    } catch (error) {
      debugPrint('FCM token removal skipped: $error');
    } finally {
      await tokenStorage.clearPushToken();
    }
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
      _ => 'android',
    };
  }

  Future<void> dispose() async {
    await _tokenRefreshSubscription?.cancel();
  }
}