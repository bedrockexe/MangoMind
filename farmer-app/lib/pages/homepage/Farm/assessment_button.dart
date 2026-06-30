import 'package:flutter/material.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/interactions.dart';
import 'package:insights/theme/transitions.dart';
import 'assessment_overview.dart';

/// Flagship CTA for the Farmer Assessment flow, styled as a gradient spotlight
/// card to match the Home dashboard's primary action.
class AssessmentButton extends StatelessWidget {
  const AssessmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () =>
          Navigator.push(context, appRoute(const FarmerOverviewPage())),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.space4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandGreen, AppTheme.brandGreenDeep],
          ),
          borderRadius: AppTheme.cardRadius,
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandGreen.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: const Icon(Icons.assignment, color: Colors.white),
            ),
            const SizedBox(width: AppTheme.space3),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Farmer Assessment',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Check your readiness and get tailored tips',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
