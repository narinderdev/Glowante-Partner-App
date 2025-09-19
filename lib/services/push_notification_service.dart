import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for channel details (MUST match Android strings.xml)
const _channelId = 'high_importance_channel';
const _channelName = 'High Importance';
const _channelDescription = 'Used for important notifications.';

final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  description: _channelDescription,
  importance: Importance.high,
);

@pragma('vm:entry-point') // required so the VM can find it in background isolate
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase for this isolate
  await Firebase.initializeApp();

  // Initialize local notifications for this isolate and show the notification
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await _fln.initialize(init);

  await _fln.show(
    message.hashCode,
    message.notification?.title ?? message.data['title'] ?? 'Notification',
    message.notification?.body ?? message.data['body'] ?? '',
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        priority: Priority.high,
        importance: Importance.high,
      ),
    ),
    payload: message.data.toString(),
  );
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const String _tokenStorageKey = 'fcm_device_token';
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _cachedToken;
  bool _initialized = false;

  bool get _supportsPush => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> initialize() async {
    if (!_supportsPush) {
      print('Push notifications are not supported on this platform.');
      return;
    }
    if (_initialized) return;
    _initialized = true;

    // 1) Background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2) Permissions (iOS + Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('Notification permission status: ${settings.authorizationStatus}');

    // 3) Local notifications init + channel creation
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _fln.initialize(init);
    final androidImpl = _fln.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);

    // 4) Foreground presentation (iOS) — harmless on Android
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 5) Token bootstrap + persistence
    final token = await _messaging.getToken();
    await _persistToken(token);
    print('FCM Token: $token');

    _messaging.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _persistToken(newToken);
    });

    // 6) Foreground message -> show local notification
    FirebaseMessaging.onMessage.listen((message) async {
      print('Foreground push message: ${message.messageId}');
      await _fln.show(
        message.hashCode,
        message.notification?.title ?? message.data['title'] ?? 'Notification',
        message.notification?.body ?? message.data['body'] ?? '',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            priority: Priority.high,
            importance: Importance.high,
          ),
        ),
        payload: message.data.toString(),
      );
    });

    // 7) User tapped notification when app in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Push notification opened: ${message.messageId}');
      // TODO: Navigate using message.data if needed.
    });
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    if (!_supportsPush) return null;
    if (!forceRefresh && _cachedToken?.isNotEmpty == true) return _cachedToken;

    final prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final stored = prefs.getString(_tokenStorageKey);
      if (stored?.isNotEmpty == true) {
        _cachedToken = stored;
        return stored;
      }
    }

    final freshToken = await _messaging.getToken();
    await _persistToken(freshToken);
    return freshToken;
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }
}
