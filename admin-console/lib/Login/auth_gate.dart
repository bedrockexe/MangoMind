import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../Admin_mainpage/navigator.dart';
import '../theme/app_theme.dart';
import 'login_page.dart';

/// Startup gate that decides the first screen based on the persisted Firebase
/// session, so an already-signed-in admin skips the login form.
///
/// Firebase Auth keeps the session on-device across restarts; this widget
/// simply honours it. It also re-verifies the `admin` custom claim on every
/// launch, so a revoked admin is signed out and sent back to login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _auth = FirebaseAuth.instance;
  late Future<bool> _adminCheck;

  @override
  void initState() {
    super.initState();
    _adminCheck = _resolveSession();
  }

  /// Returns true when a signed-in admin session is valid, false otherwise.
  Future<bool> _resolveSession() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      final result = await user.getIdTokenResult(true);
      final isAdmin = result.claims?['admin'] == true;
      if (!isAdmin) {
        await _auth.signOut();
      }
      return isAdmin;
    } catch (_) {
      // Network hiccup or expired token — fall back to the login screen
      // rather than trusting a session we could not verify.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminCheck,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        return snap.data == true ? const MainPage() : const LoginPage();
      },
    );
  }
}

/// Minimal branded splash shown while the session check runs.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(
                Icons.eco_rounded,
                size: 44,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            const Text(
              'MangoMind Admin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.space4),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
