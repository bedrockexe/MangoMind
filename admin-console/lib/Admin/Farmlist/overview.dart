import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';

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

  Future<void> deleteFarm() async {
    // Capture before the await so we don't touch a stale context afterwards.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await farmRef.delete();
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('Farm deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error deleting farm: $e')),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete farm?'),
        content: const Text(
          'This permanently removes the farm and its records. This cannot be '
          'undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) deleteFarm();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: farmRef.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off,
            title: 'Could not load farm',
            message: '${snap.error}',
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snap.data?.data() ?? {};
        final name = (data['name'] ?? 'Farm') as String;
        final address = (data['address'] ?? '') as String;
        final areaHa = data['areaHa'];

        final dp = Map<String, dynamic>.from(data['diseasePest'] ?? {});
        final lastObs = dp['lastObserved'] as Timestamp?;
        final DateTime? lastDiseaseDt = lastObs?.toDate();
        final String lastDiseaseValue = lastDiseaseDt == null
            ? 'None recorded'
            : DateFormat('MMM d, yyyy').format(lastDiseaseDt);
        final bool recent = lastDiseaseDt != null &&
            DateTime.now().difference(lastDiseaseDt).inDays <= 14;

        return ListView(
          padding: const EdgeInsets.all(AppTheme.space4),
          children: [
            // ===== Farm identity =====
            const SectionHeader('Farm'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (areaHa != null) ...[
                    const SizedBox(height: AppTheme.space2),
                    AppStatusChip(
                      '${areaHa is num ? areaHa.toStringAsFixed(2) : areaHa} ha',
                      icon: Icons.straighten,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.space4),

            // ===== Yield trend =====
            const SectionHeader('Yield trend'),
            CompactYieldCard(farmRef: farmRef),

            const SizedBox(height: AppTheme.space4),

            // ===== Disease status =====
            const SectionHeader('Disease & pest'),
            AppCard(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (recent ? scheme.error : AppTheme.brandGreen)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      recent
                          ? Icons.warning_amber_rounded
                          : Icons.verified_rounded,
                      color: recent ? scheme.error : AppTheme.brandGreen,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last observed',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lastDiseaseValue,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AppStatusChip(
                          recent
                              ? 'Recent issue — monitor closely'
                              : 'No recent disease flags',
                          tone: recent ? StatusTone.danger : StatusTone.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.space5),

            // ===== Actions =====
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                appRoute(
                  EditFarm(
                    farm: data,
                    userId: widget.userId,
                    farmId: widget.farmId,
                  ),
                ),
              ),
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Edit farm'),
            ),
            const SizedBox(height: AppTheme.space3),
            OutlinedButton.icon(
              onPressed: _confirmDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete farm'),
            ),
          ],
        );
      },
    );
  }
}
