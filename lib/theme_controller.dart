import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _kKey = 'app_theme_mode';
  // default to system
  ThemeMode _mode = ThemeMode.light;
  ThemeMode get mode => _mode;

  /// Call this in main() before runApp.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey); // "system" | "light" | "dark"
    if (saved != null) {
      instance._mode = _fromString(saved);
    }
  }

  Future<void> setMode(ThemeMode newMode) async {
    if (_mode == newMode) return;
    _mode = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, _mode.name); // uses "system"/"light"/"dark"
    notifyListeners();
  }

  static ThemeMode _fromString(String s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
