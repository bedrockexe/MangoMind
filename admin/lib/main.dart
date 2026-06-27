import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'Login/login_page.dart';
import 'ThemeController.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await ThemeController.init();
  } catch (e) {
    print('Firebase initialization error: $e');
  }
  runApp(SweetInsightAdmin());
}

class SweetInsightAdmin extends StatelessWidget {
  const SweetInsightAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sweet Insight Admin',
          themeMode: ThemeController.instance.mode,
          theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            useMaterial3: true,
            colorSchemeSeed: Colors.green,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData.light().textTheme,
            ),
          ),
          home: LoginPage(),
        );
      },
    );
  }
}
