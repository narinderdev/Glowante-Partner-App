import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _notificationsStorageKey = 'local_notifications';

class LocalNotificationItem {
  const LocalNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.data,
  });

  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'receivedAt': receivedAt.toIso8601String(),
      'data': data,
    };
  }

  static LocalNotificationItem? fromJson(dynamic value) {
    if (value is! Map) return null;

    final rawReceivedAt = value['receivedAt']?.toString();
    final receivedAt = rawReceivedAt == null
        ? null
        : DateTime.tryParse(rawReceivedAt)?.toLocal();
    if (receivedAt == null) return null;

    final rawData = value['data'];
    final data = <String, dynamic>{};
    if (rawData is Map) {
      rawData.forEach((key, value) => data[key.toString()] = value);
    }

    return LocalNotificationItem(
      id: value['id']?.toString() ??
          receivedAt.microsecondsSinceEpoch.toString(),
      title: value['title']?.toString() ?? 'Glowante',
      body: value['body']?.toString() ?? '',
      receivedAt: receivedAt,
      data: data,
    );
  }
}

class NotificationStore {
  const NotificationStore._();

  static Future<List<LocalNotificationItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_notificationsStorageKey) ?? const [];
    return rawItems
        .map((raw) {
          try {
            return LocalNotificationItem.fromJson(jsonDecode(raw));
          } catch (_) {
            return null;
          }
        })
        .whereType<LocalNotificationItem>()
        .toList()
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  static Future<void> saveRemoteMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        message.data['notificationTitle']?.toString() ??
        'Glowante';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        message.data['notification']?.toString() ??
        '';

    await save(
      LocalNotificationItem(
        id: message.messageId ??
            message.sentTime?.millisecondsSinceEpoch.toString() ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        receivedAt: DateTime.now(),
        data: Map<String, dynamic>.from(message.data),
      ),
    );
  }

  static Future<void> save(LocalNotificationItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final deduped = [
      item,
      ...existing.where((existingItem) => existingItem.id != item.id),
    ].take(100).toList();

    await prefs.setStringList(
      _notificationsStorageKey,
      deduped.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsStorageKey);
  }
}
