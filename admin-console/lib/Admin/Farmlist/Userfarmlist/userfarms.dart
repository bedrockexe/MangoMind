// flutter packages
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../farmdetails.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';

class FarmListPage extends StatelessWidget {
  final String userId;
  const FarmListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('farms')
        .where('ownerUid', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Farms')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const FarmListSkeleton();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Could not load farms',
              message: '${snap.error}',
            );
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.agriculture_outlined,
              title: 'No farms yet',
              message: 'This farmer has not registered any farms.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.space4),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.space2),
            itemBuilder: (context, i) => _FarmCard(doc: docs[i], userId: userId),
          );
        },
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({required this.doc, required this.userId});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = doc.data();

    final name = (data['name'] ?? 'Untitled farm') as String;
    final address = (data['address'] ?? 'No address') as String;
    final areaHa = (data['areaHa'] is num)
        ? (data['areaHa'] as num).toDouble()
        : null;

    final soil = (data['soil'] as Map?) ?? const {};
    final soilType = (soil['type'] ?? '-') as String?;
    final soilPh = soil['ph'];

    final irrigation = (data['irrigation'] as Map?) ?? const {};
    final irrigationType = (irrigation['type'] ?? '-') as String?;

    final disease = (data['diseasePest'] as Map?) ?? const {};
    final hasAnthracnose = disease['anthracnose'] == true;
    final hasPowderyMildew = disease['powderyMildew'] == true;

    final imageUrl = data['imageUrl'];
    final hasImage = imageUrl != null && imageUrl != '';

    return AppCard(
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (areaHa != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.straighten,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${areaHa.toStringAsFixed(2)} ha',
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _thumb(scheme),
                      )
                    : _thumb(scheme),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space3),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space1,
            children: [
              AppStatusChip('Soil: ${soilType ?? "-"}', icon: Icons.terrain),
              if (soilPh is num) AppStatusChip('pH: $soilPh'),
              AppStatusChip(
                'Irrigation: ${irrigationType ?? "-"}',
                tone: StatusTone.info,
                icon: Icons.water_drop_outlined,
              ),
              if (hasAnthracnose)
                const AppStatusChip(
                  'Anthracnose',
                  tone: StatusTone.danger,
                  icon: Icons.warning_amber_rounded,
                ),
              if (hasPowderyMildew)
                const AppStatusChip(
                  'Powdery mildew',
                  tone: StatusTone.danger,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                appRoute(FarmDetailsPage(farmId: doc.id, userId: userId)),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('Manage farm'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(ColorScheme scheme) {
    return Container(
      width: 84,
      height: 84,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.local_florist, size: 36, color: scheme.onSurfaceVariant),
    );
  }
}
