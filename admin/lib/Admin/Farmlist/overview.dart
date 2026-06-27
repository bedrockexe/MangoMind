import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Userfarmdetails/yieldchart.dart';
import 'Userfarmdetails/editfarm.dart';

class OverviewPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> farmRef;
  final TabController tabController;
  final String userId;
  final String farmId;
  const OverviewPage({
    super.key,
    required this.farmRef,
    required this.tabController,
    required this.userId,
    required this.farmId,
  });

  @override
  State<OverviewPage> createState() => _OverviewPage();
}

class _OverviewPage extends State<OverviewPage> {
  DocumentReference<Map<String, dynamic>> get farmRef => widget.farmRef;
  TabController get tabController => widget.tabController;

  Future<void> deleteFarm() async {
    try {
      await farmRef.delete();
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted Farm Successfully')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting farm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: farmRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data?.data() ?? {};
        final name = data['name'] ?? 'Farm';
        final address = data['address'] ?? '';
        final areaHa = data['areaHa'];
        final dp = Map<String, dynamic>.from(data['diseasePest'] ?? {});
        final lastObs = dp['lastObserved'] as Timestamp?;
        final DateTime? lastDiseaseDt = lastObs?.toDate();
        final String lastDiseaseValue = lastDiseaseDt == null
            ? '—'
            : DateFormat('yyyy-MM-dd').format(lastDiseaseDt);
        final bool recent =
            lastDiseaseDt != null &&
            DateTime.now().difference(lastDiseaseDt).inDays <= 14;
        final Color accent = recent
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
        final IconData icon = recent
            ? Icons.warning_amber_rounded
            : Icons.verified_rounded;
        final String caption = recent
            ? 'Recent issue—monitor closely'
            : 'No recent disease flags';
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Farm Title Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (areaHa != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Area: ${areaHa.toString()} hectares',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            //
            const Divider(height: 5),
            //
            const SizedBox(height: 12),
            // Yields Chart Card
            CompactYieldCard(farmRef: farmRef),
            //
            const SizedBox(height: 12),
            // Last Disease
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: farmRef
                  .collection('yields')
                  .orderBy('date', descending: true)
                  .limit(500)
                  .snapshots(),
              builder: (context, ysnap) {
                if (ysnap.hasData) {
                  final docs = ysnap.data!.docs;
                  // Aggregate yields by season
                  final Map<String, double> totals = {};
                  for (final d in docs) {
                    final m = d.data();
                    final season =
                        (m['season'] ?? '') as String; // 'Wet' | 'Dry'
                    final seasonYear =
                        (m['seasonYear'] ?? 0) as int; // e.g., 2026
                    final w = (m['weightKg'] is int)
                        ? (m['weightKg'] as int).toDouble()
                        : (m['weightKg'] as num?)?.toDouble() ?? 0.0;

                    if ((season == 'Wet' || season == 'Dry') &&
                        seasonYear > 0) {
                      final key = '$seasonYear-$season';
                      totals[key] = (totals[key] ?? 0) + w;
                    }
                  }

                  // Pick the latest season: higher seasonYear wins; for same year Wet > Dry
                  int? bestYear;
                  String? bestSeason;

                  for (final key in totals.keys) {
                    final parts = key.split('-'); // [year, season]
                    if (parts.length != 2) continue;
                    final yr = int.tryParse(parts[0]) ?? 0;
                    final ssn = parts[1]; // 'Wet' or 'Dry'

                    bool isBetter = false;
                    if (bestYear == null) {
                      isBetter = true;
                    } else if (yr > bestYear) {
                      isBetter = true;
                    } else if (yr == bestYear) {
                      // Within same seasonYear, Wet is later than Dry
                      final currentRank = (ssn == 'Wet') ? 2 : 1;
                      final bestRank = (bestSeason == 'Wet') ? 2 : 1;
                      if (currentRank > bestRank) isBetter = true;
                    }

                    if (isBetter) {
                      bestYear = yr;
                      bestSeason = ssn;
                    }
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Last Disease',
                        value: lastDiseaseValue,
                        caption: caption,
                        color: accent,
                        icon: icon,
                      ),
                    ),
                  ],
                );
              },
            ),
            //
            const SizedBox(height: 12),
            FarmActionButtons(
              onEdit: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditFarm(
                      farm: data,
                      userId: widget.userId,
                      farmId: widget.farmId,
                    ),
                  ),
                );
              },
              onDelete: () async {
                final confirm = await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: const Text(
                      'Are you sure you want to delete this farm?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  deleteFarm();
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.caption,
  });

  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surface;
    final onBg = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [bg.withOpacity(0.96), bg.withOpacity(0.86)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: onBg.withOpacity(0.06)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon pill
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: onBg.withOpacity(0.75),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: onBg,
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: onBg.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FarmActionButtons extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FarmActionButtons({
    super.key,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0), // outer margin
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🟢 Edit Farm Button
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, color: Colors.white),
              label: const Text(
                'Edit Farm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16), // spacing between buttons
          // 🔴 Delete Farm Button
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Delete Farm',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
