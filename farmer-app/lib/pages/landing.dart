// packages
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Landing extends StatelessWidget {
  const Landing({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
                Text(
                  'MangoMind',
                  style: GoogleFonts.poppins(
                    fontSize: 35,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your #1 Mango Farming Guide App',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sign Up
                Container(
                  margin: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Log In
                Container(
                  margin: const EdgeInsets.all(12),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: scheme.primary, width: 1),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      "Log In",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
