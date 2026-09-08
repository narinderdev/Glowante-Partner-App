import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/api_service.dart';
import 'notification_store.dart';

const _androidChannelId = 'glowante_default_channel';
const _androidChannelName = 'General Notifications';
const _androidChannelDescription =
    'Updates about bookings, branches, and offers.';
const _tokenStorageKey = 'fcm_device_token';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

final AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  _androidChannelId,
  _androidChannelName,
  description: _androidChannelDescription,
  importance: Importance.high,
);

class BookingNotificationPayload {
  BookingNotificationPayload({
    required this.branchId,
    required this.date,
    required this.type,
    required this.wasTapped,
    this.message,
  });

  final int branchId;
  final DateTime date;
  final String type;
  final bool wasTapped;
  final String? message;

  static BookingNotificationPayload? fromRemoteMessage(
    RemoteMessage message, {
    required bool wasTapped,
  }) {
    final data = message.data;
    if (data.isEmpty) return null;

    final branchId = int.tryParse(data['branchId']?.toString() ?? '');
    final rawDate = data['appointmentDate']?.toString();
    if (branchId == null || rawDate == null || rawDate.isEmpty) {
      return null;
    }

    DateTime? parsedDate;
    final formats = <DateFormat>[
      DateFormat('yyyy-MM-dd'),
      DateFormat('d MMM yyyy'),
      DateFormat('dd MMM yyyy'),
    ];

    for (final format in formats) {
      try {
        parsedDate = format.parse(rawDate);
        break;
      } catch (_) {
        // Ignore and try next format.
      }
    }

    parsedDate ??= DateTime.tryParse(rawDate);
    if (parsedDate == null) return null;

    final normalizedDate =
        DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

    return BookingNotificationPayload(
      branchId: branchId,
      date: normalizedDate,
      type: data['type']?.toString() ?? '',
      wasTapped: wasTapped,
      message: data['notification']?.toString() ?? message.notification?.body,
    );
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background push message: ${message.messageId}');
  print(
      'Background push notification: title=${message.notification?.title}, body=${message.notification?.body}');
  print('Background push data: ${message.data}');
  await NotificationStore.saveRemoteMessage(message);

  // A payload with a top-level `notification` block is auto-displayed by
  // the OS even while backgrounded/terminated — no app code involved. This
  // app's booking payloads are data-only (BookingNotificationPayload reads
  // branchId/date/type, and even the display text, out of `data`, not
  // `notification`), so the OS has nothing to auto-display; only the
  // foreground path (onMessage) was building and showing one explicitly.
  // This mirrors that here for the background/terminated case.
  if (message.notification == null) {
    await _showBackgroundNotification(message);
  }
}

// Runs in a fresh background isolate (Android) with no access to the main
// isolate's already-initialized PushNotificationService state, so this
// creates and initializes its own short-lived plugin instance rather than
// reusing PushNotificationService's.
Future<void> _showBackgroundNotification(RemoteMessage message) async {
  final title = message.data['title']?.toString() ?? 'Glowante';
  final body = message.data['notification']?.toString() ??
      message.data['body']?.toString() ??
      '';
  if (body.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await plugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: const DarwinNotificationDetails(
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    ),
  );

  print('Showing background local notification: title=$title, body=$body');
  await plugin.show(
    message.hashCode,
    title,
    body,
    details,
    payload: message.data.isEmpty ? null : jsonEncode(message.data),
  );
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  String? _cachedToken;
  bool _initialised = false;

  final StreamController<BookingNotificationPayload> _bookingEvents =
      StreamController<BookingNotificationPayload>.broadcast();
  BookingNotificationPayload? _pendingNavigation;

  Stream<BookingNotificationPayload> get bookingNotifications =>
      _bookingEvents.stream;
  BookingNotificationPayload? get pendingNavigationEvent => _pendingNavigation;

  BookingNotificationPayload? takePendingNavigationEvent() {
    final pending = _pendingNavigation;
    _pendingNavigation = null;
    return pending;
  }

  bool get _supportsPush =>
      !kIsWeb &&
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

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Deliberately not requesting the OS notification permission (or
    // fetching/persisting the FCM token) here — that used to happen on
    // every cold start, before the user had even logged in. It's now
    // triggered explicitly via requestPermissionAndRegisterToken() right
    // after OTP verify succeeds (and again on a returning already-logged-in
    // user's splash check, which re-requests silently since the OS only
    // prompts once per install).

    _messaging.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _persistToken(newToken);
    });

    FirebaseMessaging.onMessage.listen((message) async {
      print('Foreground push message: ${message.messageId}');
      print(
          'Foreground push notification: title=${message.notification?.title}, body=${message.notification?.body}');
      print('Foreground push data: ${message.data}');
      await NotificationStore.saveRemoteMessage(message);
      _emitBookingEvent(message, wasTapped: false);
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      print('Push notification opened: ${message.messageId}');
      print('Opened push data: ${message.data}');
      await NotificationStore.saveRemoteMessage(message);
      _emitBookingEvent(message, wasTapped: true);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      print('Initial push message: ${initialMessage.messageId}');
      print('Initial push data: ${initialMessage.data}');
      await NotificationStore.saveRemoteMessage(initialMessage);
      _emitBookingEvent(initialMessage, wasTapped: true);
    }
  }

  // Shows the OS notification-permission prompt and registers the FCM
  // token — call this right after login (OTP verify) succeeds, not at raw
  // app start, so the ask has context. Safe to call again on every app
  // start for an already-logged-in user: once the OS has recorded a
  // decision, requestPermission() just returns it without prompting again.
  bool _retryScheduled = false;

  Future<void> requestPermissionAndRegisterToken() async {
    print('[PushNotif] requestPermissionAndRegisterToken() called, '
        'platform=$defaultTargetPlatform supportsPush=$_supportsPush '
        'initialised=$_initialised');
    if (!_supportsPush) {
      print('[PushNotif] platform does not support push, skipping.');
      return;
    }
    if (!_initialised) {
      print(
        '[PushNotif] called before initialize(); skipping.',
      );
      return;
    }

    final registered = await _attemptRegisterToken();

    // The APNS token (iOS) or a getToken() call can occasionally take
    // longer than this attempt's own wait/retry budget — especially right
    // after a fresh install. Without this, a failed attempt here would
    // otherwise go unregistered for the rest of the session, since the
    // only other place this re-runs is a full app restart (splash's
    // returning-user check). One deferred retry closes that gap; only ever
    // scheduled once per session so repeated calls to this method (e.g.
    // every app start) don't stack up multiple pending retries.
    if (!registered && !_retryScheduled) {
      _retryScheduled = true;
      unawaited(_retryRegistrationLater());
    }
  }

  Future<void> _retryRegistrationLater() async {
    await Future.delayed(const Duration(seconds: 20));
    print('[PushNotif] retrying token registration after initial delay...');
    await _attemptRegisterToken();
  }

  Future<bool> _attemptRegisterToken() async {
    await _requestPermissions();

    final hasApnsToken = await _waitForApnsToken();
    if (!hasApnsToken) {
      print(
          '[PushNotif] APNS token not available; skipping FCM token registration for now.');
      return false;
    }

    try {
      print('[PushNotif] calling _messaging.getToken()...');
      final token = await _messaging.getToken();
      print('[PushNotif] getToken() returned: $token');
      await _persistToken(token);
      print('[PushNotif] requestPermissionAndRegisterToken() done.');
      return true;
    } catch (error) {
      print('[PushNotif] FCM token registration failed: $error');
      return false;
    }
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

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await _messaging.getNotificationSettings();
      final isAllowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!isAllowed) {
        print(
          '[PushNotif] iOS notification permission is not granted yet; '
          'skipping pre-login FCM token fetch.',
        );
        return _cachedToken;
      }
    }

    final hasApnsToken = await _waitForApnsToken();
    if (!hasApnsToken) {
      print('APNS token not available; returning cached FCM token if any.');
      return _cachedToken;
    }

    try {
      final freshToken = await _messaging.getToken();
      await _persistToken(freshToken);
      return freshToken;
    } catch (error) {
      debugPrint('FCM token fetch failed: $error');
      return _cachedToken;
    }
  }

  void _emitBookingEvent(RemoteMessage message, {required bool wasTapped}) {
    final parsed = BookingNotificationPayload.fromRemoteMessage(
      message,
      wasTapped: wasTapped,
    );
    if (parsed == null) return;

    debugPrint(
        'Booking event received: branch=${parsed.branchId}, date=${parsed.date.toIso8601String()}, tapped=$wasTapped');

    if (parsed.wasTapped) {
      _pendingNavigation = parsed;
    }

    _bookingEvents.add(parsed);
  }

  Future<void> _initialiseLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            final mapped = <String, dynamic>{};
            decoded.forEach((key, value) {
              mapped[key.toString()] = value;
            });
            _emitBookingEvent(
              RemoteMessage(data: Map<String, dynamic>.from(mapped)),
              wasTapped: true,
            );
          }
        } catch (err) {
          debugPrint('Failed to decode local notification payload: $err');
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _requestPermissions() async {
    print('[PushNotif] requesting OS notification permission...');
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print(
      '[PushNotif] requestPermission() returned '
      'authorizationStatus=${settings.authorizationStatus} '
      'alert=${settings.alert} badge=${settings.badge} sound=${settings.sound}',
    );
  }

  Future<bool> _waitForApnsToken() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      print('[PushNotif] not iOS, skipping APNS token wait.');
      return true;
    }

    const maxAttempts = 10;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken?.isNotEmpty == true) {
        print('[PushNotif] APNS token is available (attempt $attempt)');
        return true;
      }
      print('[PushNotif] APNS token not yet available (attempt $attempt)');
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }

    print('[PushNotif] APNS token was not available after waiting');
    return false;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = notification?.android;

    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'Glowante';
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
      iOS: const DarwinNotificationDetails(
          presentSound: true, presentAlert: true, presentBadge: true),
    );

    print(
        'Showing local notification on channel $_androidChannelId with title=$title, body=$body');
    await _localNotifications.show(
      (notification?.hashCode ?? message.hashCode),
      title,
      body,
      details,
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  Future<void> _persistToken(String? token) async {
    if (token == null || token.isEmpty) {
      print('[PushNotif] _persistToken called with empty token, ignoring.');
      return;
    }
    print('[PushNotif] persisting token locally: $token');
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);

    // Only push to the backend once there's a session to associate the
    // token with — this can also run pre-login (login_screen.dart's own
    // getToken() call), where there's nothing to register against yet.
    final userToken = prefs.getString('user_token');
    if (userToken == null || userToken.isEmpty) {
      print('[PushNotif] no user_token yet, skipping backend sync.');
      return;
    }
    try {
      print('[PushNotif] syncing device token to backend...');
      final response = await ApiService().updateDeviceToken(token);
      print('[PushNotif] updateDeviceToken response: $response');
      if (response['success'] != true) {
        debugPrint(
            '[PushNotificationService] updateDeviceToken failed: $response');
      }
    } catch (error) {
      debugPrint('[PushNotificationService] updateDeviceToken error: $error');
    }
  }
}
