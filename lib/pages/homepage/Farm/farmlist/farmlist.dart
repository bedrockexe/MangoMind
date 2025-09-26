// flutter packages
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.green, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.agriculture,
                          size: 32,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text('📍 $address'),
                        if (areaHa != null)
                          Text('🌾 ${areaHa.toStringAsFixed(2)} hectares'),
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
                            if (hasAnthracnose) const _WarnChip('Anthracnose'),
                            const SizedBox(width: 8),
                            if (hasPowderyMildew)
                              const _WarnChip('Powdery Mildew'),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FarmDetailsPage(farmId: doc.id),
                          ),
                        ),
                        icon: const Icon(Icons.build),
                        label: const Text('Manage Farm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddFarmPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Farm'),
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
  // final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // if (icon != null) ...[Icon(icon, size: 14), const SizedBox(width: 4)],
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _WarnChip extends StatelessWidget {
  const _WarnChip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
