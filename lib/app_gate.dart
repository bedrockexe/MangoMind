import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:insights/pages/services/session.dart';
import 'pages/landing.dart';
import 'pages/home.dart';

class AppGate extends StatelessWidget {
  const AppGate({super.key});

  Future<bool> _isAllowed() async {
    // Wait for Firebase to restore the auth state once.
    final user = await FirebaseAuth.instance.authStateChanges().first;

    // If there’s no user, go to Landing.
    if (user == null) return false;

    // Check the 2-day session.
    final valid = await SessionService.isSessionValid();

    // If session is missing/expired -> sign out and go to Landing.
    if (!valid) {
      await FirebaseAuth.instance.signOut();
      await SessionService.clearSession();
      return false;
    }

    // User present AND session valid -> go Home.
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isAllowed(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data! ? const HomePage() : const Landing();
      },
    );
  }
}
