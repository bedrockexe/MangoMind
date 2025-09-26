// lib/core/local_notifier.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class LocalNotifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Channel id must be stable and used when sending notifications
  static const String _androidChannelId = 'irrigation_reco';
  static const String _androidChannelName = 'Irrigation Recommendations';

  // Flag to enable/disable notifications
  static bool _enabled = true;

  // Public getter
  static bool get isEnabled => _enabled;

  // Toggle notifications on/off
  static void setEnabled(bool value) {
    _enabled = value;
    if (!_enabled) {
      _plugin.cancelAll();
    }
  }

  static Future<void> cancelById(int id) => _plugin.cancel(id);

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    // Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    final initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        //
      },
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final androidChannel = AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'Important irrigation alerts',
          importance: Importance.high,
          playSound: true,
          showBadge: true,
        );
        await androidPlugin.createNotificationChannel(androidChannel);
      }
    }
  }

  /// Request runtime notification permission on Android 13+
  static Future<bool> requestPermissionIfNeeded() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Show an immediate notification (local)
  static Future<void> showNow({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    if (!_enabled) return;
    await requestPermissionIfNeeded();
    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Important irrigation alerts',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  static Future<void> scheduleDailyAt6AM({
    required Future<String> Function() buildBody,
    int id = 1002,
  }) async {
    if (!_enabled) return;
    await requestPermissionIfNeeded();

    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 6);
    if (now.isAfter(next)) next = next.add(const Duration(days: 1));

    final body = await buildBody();

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Important irrigation alerts',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
    );

    await _plugin.periodicallyShow(
      id,
      'Irrigation recommendation',
      body,
      RepeatInterval.everyMinute,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
  }
}
