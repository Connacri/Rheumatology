// ═══════════════════════════════════════════════════════════════════
// services/notification_service.dart
// ═══════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );
    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
    String? type,
  }) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'congress_main', 'Congrès Oran',
          channelDescription: 'Notifications du congrès',
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF1A3A6B),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Écoute les notifications Supabase en realtime ──
  static RealtimeChannel? _channel;

  static void subscribe(String userId, VoidCallback onUpdate) {
    _channel?.unsubscribe();
    _channel = Supabase.instance.client
        .channel('notifs_$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'congress_notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) async {
        final row = payload.newRecord;
        await show(
          title: row['title'] as String,
          body:  row['body']  as String,
          type:  row['type']  as String?,
        );
        onUpdate();
      },
    )
        .subscribe();
  }

  static void unsubscribe() => _channel?.unsubscribe();
}
