import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _kLoginAt = 'login_at_ms';
  static const _kMaxAgeMs = 172800000;

  /// Call this right after a successful login/signup.
  static Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLoginAt, DateTime.now().millisecondsSinceEpoch);
  }

  /// Optional: call this on manual logout.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLoginAt);
  }

  /// Returns true if the stored login time is within 2 days.
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final loginAt = prefs.getInt(_kLoginAt);
    if (loginAt == null) return false;
    final age = DateTime.now().millisecondsSinceEpoch - loginAt;
    return age < _kMaxAgeMs;
  }
}
