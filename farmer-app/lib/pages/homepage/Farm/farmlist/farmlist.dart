// flutter packages
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';

// theme
import 'package:insights/theme/transitions.dart';
import 'package:insights/theme/skeletons.dart';
import 'package:insights/theme/components.dart';

// pages
import 'package:insights/pages/homepage/Farm/farmlist/addfarm.dart';
import 'package:insights/pages/homepage/Farm/farmlist/farmdetails.dart';

class FarmListPage extends StatelessWidget {
  const FarmListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Worst Case handler
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your farms.')),
      );
    }

    // Get the farm list
    final query = FirebaseFirestore.instance
        .collection('farms')
        .where('ownerUid', isEqualTo: user.uid)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Farms List')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const FarmListSkeleton();
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.agriculture,
              title: 'No farms yet',
              message: 'Tap "Add Farm" to create your first farm.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final name = (data['name'] ?? 'Untitled Farm') as String;
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

              return AppCard(
                onTap: () => Navigator.push(
                  context,
                  appRoute(FarmDetailsPage(farmId: doc.id)),
                ),
                selected: true,
                child: Column(children: [
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
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text('📍 $address'),
            if (areaHa != null)
              Text('🌾 ${areaHa.toStringAsFixed(2)} hectares'),

            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppStatusChip('Soil: ${soilType ?? "-"}'),
                if (soilPh is num) AppStatusChip('pH: ${soilPh.toString()}'),
                AppStatusChip('Irrigation: ${irrigationType ?? "-"}'),
                if (hasAnthracnose)
                  const AppStatusChip(
                    'Anthracnose',
                    tone: StatusTone.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
                if (hasPowderyMildew)
                  const AppStatusChip(
                    'Powdery Mildew',
                    tone: StatusTone.danger,
                    icon: Icons.warning_amber_rounded,
                  ),
              ],
            ),

            const SizedBox(height: 10),

            
          ],
        ),
      ),

      const SizedBox(width: 14),
  
      // ---------------------------
      // 📸 Right SIDE — FARM IMAGE
      // ---------------------------
      ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: data['imageUrl'] != null && data['imageUrl'] != ""
      ? Image.network(
          data['imageUrl'],
          width: 110,
          height: 110,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;

            // SHIMMER PLACEHOLDER
            return Shimmer.fromColors(
              baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              highlightColor: Theme.of(context).colorScheme.surfaceContainer,
              child: Container(
                width: 110,
                height: 110,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            );
          },
        )
      : Container(
          width: 110,
          height: 110,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.image,
            size: 50,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
)
    ],
  ),
    SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  appRoute(FarmDetailsPage(farmId: doc.id)),
                ),
                icon: const Icon(Icons.build),
                label: const Text('Manage Farm'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
  ],)
)
    .animate()
    .fadeIn(
      delay: (i * 70).ms,
      duration: 350.ms,
      curve: Curves.easeOut,
    )
    .slideY(
      begin: 0.12,
      delay: (i * 70).ms,
      duration: 350.ms,
      curve: Curves.easeOutCubic,
    );

            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, appRoute(const AddFarmPage()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Farm'),
      ),
    );
  }
}
