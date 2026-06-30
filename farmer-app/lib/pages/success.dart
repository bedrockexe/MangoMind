import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:insights/theme/app_theme.dart';

class SuccessPage extends StatelessWidget {
  const SuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space5),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          "assets/confetti.gif",
                          height: 200,
                          errorBuilder: (c, e, s) => const SizedBox(height: 40),
                        ),
                        Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                size: 56,
                                color: scheme.onPrimaryContainer,
                              ),
                            )
                            .animate()
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1, 1),
                              duration: 500.ms,
                              curve: Curves.easeOutBack,
                            )
                            .fadeIn(),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space5),
                    Text(
                      "Account created!",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: AppTheme.space2),
                    Text(
                      "Your MangoMind account is ready. Log in to start managing your farm.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ).animate().fadeIn(delay: 350.ms),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Proceed to login'),
                ),
              ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppTheme.space2),
            ],
          ),
        ),
      ),
    );
  }
}
