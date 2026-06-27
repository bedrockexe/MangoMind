// flutter packages
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';

import '../farmdetails.dart';

class FarmListPage extends StatelessWidget {
  final String userId;
  const FarmListPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Get the farm list
    final query = FirebaseFirestore.instance
        .collection('farms')
        .where('ownerUid', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Farms List')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyFarms();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

              final imageUrl = data['imageUrl'];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),

                child: 
                Column(children: [
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
                          Text('📍 $address'),
                          if (areaHa != null)
                            Text('🌾 ${areaHa.toStringAsFixed(2)} hectares'),

                          const SizedBox(height: 6),

                          Row(
                            children: [
                              _Chip('Soil: ${soilType ?? "-"}'),
                              const SizedBox(width: 6),
                              if (soilPh is num)
                                _Chip('pH: ${soilPh.toString()}'),
                            ],
                          ),

                          Row(
                            children: [
                              _Chip('Irrigation: ${irrigationType ?? "-"}'),
                            ],
                          ),

                          Row(
                            children: [
                              if (hasAnthracnose)
                                const _WarnChip('Anthracnose'),
                              const SizedBox(width: 8),
                              if (hasPowderyMildew)
                                const _WarnChip('Powdery Mildew'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: imageUrl != null && imageUrl != ""
                          ? Image.network(
                              imageUrl,
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;

                                return Shimmer.fromColors(
                                  baseColor: Colors.grey.shade300,
                                  highlightColor: Colors.grey.shade100,
                                  child: Container(
                                    width: 90,
                                    height: 90,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 110,
                              height: 110,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 50, color: Colors.grey),
                            ),
                    ),
                  ],
                ),
                  SizedBox(height: 12),
                  SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FarmDetailsPage(
                                    farmId: doc.id,
                                    userId: userId,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.build),
                              label: const Text('Manage Farm'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyFarms extends StatelessWidget {
  const _EmptyFarms();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.agriculture, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            const Text(
              'No farms yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "Add Farm" to create your first farm.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _WarnChip extends StatelessWidget {
  const _WarnChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 14, color: theme.onErrorContainer),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: theme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
