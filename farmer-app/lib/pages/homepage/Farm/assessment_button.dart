import 'package:flutter/material.dart';
import 'assessment_overview.dart';

class AssessmentButton extends StatelessWidget {
  const AssessmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.assignment),
      label: const Text(
        'Farmer Assessment',
        style: TextStyle(fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => FarmerOverviewPage()),
        );
      },
    );
  }
}
