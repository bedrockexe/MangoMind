import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'Login/auth_gate.dart';
import 'ThemeController.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await ThemeController.init();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }
  runApp(const SweetInsightAdmin());
}

class SweetInsightAdmin extends StatelessWidget {
  const SweetInsightAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'MangoMind Admin',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const AuthGate(),
        );
      },
    );
  }
}
