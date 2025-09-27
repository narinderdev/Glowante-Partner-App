import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _androidChannelId = 'glowante_default_channel';
const _androidChannelName = 'General Notifications';
const _androidChannelDescription = 'Updates about bookings, branches, and offers.';
const _tokenStorageKey = 'fcm_device_token';

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

final AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  _androidChannelId,
  _androidChannelName,
  description: _androidChannelDescription,
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background push message: ${message.messageId}');
  print('Background push notification: title=${message.notification?.title}, body=${message.notification?.body}');
  print('Background push data: ${message.data}');
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _cachedToken;
  bool _initialised = false;

  bool get _supportsPush => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> initialize() async {
    if (!_supportsPush) {
      print('Push notifications are not supported on this platform.');
      return;
    }
    if (_initialised) return;
    _initialised = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initialiseLocalNotifications();
    await _requestPermissions();

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final hasApnsToken = await _waitForApnsToken();
    if (!hasApnsToken) {
      print('APNS token not available; skipping FCM token registration for now.');
    } else {
      final token = await _messaging.getToken();
      await _persistToken(token);
      print('FCM tokens: $token');
    }

    _messaging.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      print('Foreground push message: ${message.messageId}');
      print('Foreground push notification: title=${message.notification?.title}, body=${message.notification?.body}');
      print('Foreground push data: ${message.data}');
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('Push notification opened: ${message.messageId}');
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

    final hasApnsToken = await _waitForApnsToken();
    if (!hasApnsToken) {
      print('APNS token not available; returning cached FCM token if any.');
      return _cachedToken;
    }

    final freshToken = await _messaging.getToken();
    await _persistToken(freshToken);
    return freshToken;
  }

  Future<void> _initialiseLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(settings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('Notification permissions: ${settings.authorizationStatus}');
  }

  Future<bool> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;

    const maxAttempts = 10;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken?.isNotEmpty == true) {
        print('APNS token is available');
        return true;
      }
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    print('APNS token was not available after waiting');
    return false;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = notification?.android;

    final title = notification?.title ?? message.data['title']?.toString() ?? 'Glowante';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        icon: android?.smallIcon ?? '@mipmap/ic_launcher',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(presentSound: true, presentAlert: true, presentBadge: true),
    );

    print('Showing local notification on channel $_androidChannelId with title=$title, body=$body');
    await _localNotifications.show(
      (notification?.hashCode ?? message.hashCode),
      title,
      body,
      details,
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) return;
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }
}
