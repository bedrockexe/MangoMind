import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';

// Import your existing pages
import 'irrigations.dart';
import 'observations.dart';
import 'yield.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key, required this.farmRef});

  final DocumentReference<Map<String, dynamic>> farmRef;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.space4),
      children: [
        const SectionHeader('Record logs'),
        _RecordTile(
          icon: Icons.water_drop_outlined,
          color: const Color(0xFF0EA5A4),
          label: 'Irrigations',
          subtitle: 'Watering schedule and volumes',
          onTap: () => Navigator.push(
            context,
            appRoute(IrrigationsPage(farmRef: farmRef)),
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        _RecordTile(
          icon: Icons.visibility_outlined,
          color: AppTheme.brandAmber,
          label: 'Observations',
          subtitle: 'Field notes, disease and pest sightings',
          onTap: () => Navigator.push(
            context,
            appRoute(ObservationsPage(farmRef: farmRef)),
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        _RecordTile(
          icon: Icons.scale_outlined,
          color: AppTheme.brandGreen,
          label: 'Yields',
          subtitle: 'Harvest weights by season',
          onTap: () => Navigator.push(
            context,
            appRoute(YieldsHomePage(farmRef: farmRef)),
          ),
        ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
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
