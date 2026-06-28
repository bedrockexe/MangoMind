import 'package:firebase_auth/firebase_auth.dart';

/// Session policy: a signed-in user stays "active" for [_maxAge] after their
/// last sign-in.
///
/// Validity is derived from Firebase's server-recorded `lastSignInTime` rather
/// than a timestamp we store ourselves. That removes the previous weaknesses of
/// the SharedPreferences approach (the window could be reset by clearing prefs,
/// and was anchored to an arbitrary client-set value). The age comparison still
/// uses the device clock for "now", so this is a client-side convenience gate,
/// not a hard server-enforced expiry — true enforcement would require checking
/// token age in a backend.
class SessionService {
  static const Duration _maxAge = Duration(days: 2);

  /// Retained for call sites right after login/signup. Sign-in time is tracked
  /// by Firebase itself, so there is nothing to persist locally.
  static Future<void> startSession() async {}

  /// Retained for symmetry; actual sign-out is done via
  /// `FirebaseAuth.instance.signOut()` at the call sites.
  static Future<void> clearSession() async {}

  /// True if the current user signed in within [_maxAge].
  static Future<bool> isSessionValid() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final lastSignIn = user.metadata.lastSignInTime;
    if (lastSignIn == null) return false;

    final age = DateTime.now().toUtc().difference(lastSignIn.toUtc());
    return age < _maxAge;
  }
}
