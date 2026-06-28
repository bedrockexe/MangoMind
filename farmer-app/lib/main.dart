// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_store_plus/media_store_plus.dart';

// Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Theme controller (For Dark Mode)
import 'theme_controller.dart';
import 'theme/app_theme.dart';

// Pages
import 'pages/login.dart';
import 'pages/signup.dart';
import 'pages/success.dart';
import 'pages/landing.dart';
import 'pages/forgot.dart';
import 'pages/homepage.dart';
import 'pages/homepage/Farm/farmlist/farmlist.dart';
import 'app_gate.dart';
import 'notifier.dart';
import 'notifications_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _bootstrap();
}

/// Runs one-time startup and launches the app, or the error screen on failure.
/// Safe to call again (e.g. from a "Retry" button) — each step is guarded so a
/// partial first run won't double-initialize.
Future<void> _bootstrap() async {
  try {
    if (Platform.isAndroid) {
      await MediaStore.ensureInitialized();
      MediaStore.appFolder = 'FarmReports';
    }
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    await ThemeController.init();
    await NotificationsController.instance.init();
    await LocalNotifier.init();
  } catch (e, st) {
    runApp(_InitErrorApp(error: e, stack: st));
    return;
  }

  runApp(const SweetInsightsApp());
}

// Predefine initial designs and settings
class SweetInsightsApp extends StatelessWidget {
  const SweetInsightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        // At this point, Firebase is initialized already.
        return MaterialApp(
          title: 'MangoMind',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const AppGate(),

          // Named routes for easy navigation
          routes: {
            '/login': (context) => const LoginPage(),
            '/signup': (context) => const Signup(),
            '/landing': (context) => const Landing(),
            '/forgot': (context) => const Forgot(),
            '/success': (context) => const SuccessPage(),
            '/home': (context) => const HomePage(),
            '/farm': (context) => const FarmListPage(),
          },
        );
      },
    );
  }
}

/// Shown only if Firebase fails to initialize (e.g., bad config, no google-services.json)
class _InitErrorApp extends StatelessWidget {
  final Object error;
  final StackTrace? stack;
  const _InitErrorApp({required this.error, this.stack});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase failed to initialize.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text('$error', textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ElevatedButton(
                        onPressed: () => _bootstrap(),
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () => SystemNavigator.pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
