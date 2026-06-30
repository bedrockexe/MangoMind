import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/transitions.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          const SectionHeader('Records'),
          _RecordTile(
            icon: Icons.water_drop_outlined,
            color: const Color(0xFF18A0C1),
            title: 'Irrigations',
            subtitle: 'Watering logs and water use',
            onTap: () => Navigator.push(
              context,
              appRoute(IrrigationsPage(farmRef: farmRef)),
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          _RecordTile(
            icon: Icons.coronavirus_outlined,
            color: AppTheme.brandAmber,
            title: 'Observations',
            subtitle: 'Disease and pest sightings',
            onTap: () => Navigator.push(
              context,
              appRoute(ObservationsPage(farmRef: farmRef)),
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          _RecordTile(
            icon: Icons.scale_outlined,
            color: AppTheme.brandGreen,
            title: 'Yields',
            subtitle: 'Harvest weights by month',
            onTap: () => Navigator.push(
              context,
              appRoute(YieldsHomePage(farmRef: farmRef)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.space3 + 2),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
