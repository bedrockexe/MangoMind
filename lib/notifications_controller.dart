import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insights/notifier.dart';

class NotificationsController {
  NotificationsController._private();
  static final NotificationsController instance =
      NotificationsController._private();

  static const _prefsKey = 'notif_enabled';

  final ValueNotifier<bool> notifier = ValueNotifier<bool>(
    LocalNotifier.isEnabled,
  );

  Future<void> init() async {
    await LocalNotifier.init();
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefsKey);
    final enabled = saved ?? LocalNotifier.isEnabled;
    LocalNotifier.setEnabled(enabled);
    notifier.value = enabled;
  }

  Future<void> setEnabled(bool value) async {
    notifier.value = value;

    if (value) {
      final granted = await LocalNotifier.requestPermissionIfNeeded();
      if (!granted) {
        notifier.value = false;
        LocalNotifier.setEnabled(false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKey, false);
        return;
      }
    }

    LocalNotifier.setEnabled(value);

    if (value) {
      await LocalNotifier.scheduleDailyAt6AM(
        buildBody: () async => 'Time to check irrigation recommendations',
        id: 1002,
      );
    } else {
      await LocalNotifier.cancelById(1002);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
