import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your existing pages
import 'package:insights/pages/homepage/Farm/farmlist/records/irrigations/irrigations.dart';
import 'package:insights/pages/homepage/Farm/farmlist/records/observations/observations.dart';
import 'package:insights/pages/homepage/Farm/farmlist/records/yields/yield.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.farmRef});

  final DocumentReference<Map<String, dynamic>> farmRef;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 12),
                _RecordsBigButton(
                  icon: Icons.water_drop_outlined,
                  label: 'Irrigations',
                  color: Colors.teal.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => IrrigationsPage(farmRef: farmRef),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RecordsBigButton(
                  icon: Icons.visibility_outlined,
                  label: 'Observations',
                  color: Colors.amber.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ObservationsPage(farmRef: farmRef),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _RecordsBigButton(
                  icon: Icons.scale_outlined,
                  label: 'Yields',
                  color: Colors.green.shade700,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => YieldsHomePage(farmRef: farmRef),
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

class _RecordsBigButton extends StatelessWidget {
  const _RecordsBigButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
