import 'package:flutter/material.dart';
import 'assessment_overview.dart';

class AssessmentButton extends StatelessWidget {
  const AssessmentButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.assignment, color: Colors.white),
      label: const Text(
        'Farmer Assessment',
        style: TextStyle(fontSize: 16, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AssessmentOverviewPage()),
        );
      },
    );
  }
}
