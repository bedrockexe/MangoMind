// mango_yield_card_subcollections.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';

class MangoYieldCard extends StatefulWidget {
  const MangoYieldCard({super.key});

  @override
  State<MangoYieldCard> createState() => _MangoYieldCardState();
}

class _MangoYieldCardState extends State<MangoYieldCard> {
  bool _loading = true;
  String? _error;

  Map<String, double> avgYieldPerSeason = {};
  double overallAverageYield = 0.0;
  int totalFarms = 0;
  int totalFarmers = 0;
  Map<String, double> pieData = {};

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _fetchFromFarmsAndYields();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchFromFarmsAndYields() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final farmsRef = firestore.collection('farms');
      final farmsSnap = await farmsRef.get();
      totalFarms = farmsSnap.size;

      final Set<String> farmerIds = {};
      final List<Map<String, dynamic>> yieldRecords = [];

      final futures = farmsSnap.docs.map((farmDoc) async {
        final farmData = farmDoc.data();
        final userIdVal = (farmData['ownerUid'])?.toString();
        if (userIdVal != null && userIdVal.isNotEmpty) farmerIds.add(userIdVal);

        final yieldsRef = farmsRef.doc(farmDoc.id).collection('yields');
        final yieldsSnap = await yieldsRef.get();
        for (final yDoc in yieldsSnap.docs) {
          final y = yDoc.data();
          String season = (y['seasonKey'] ?? 'unknown').toString();
          final dynamic weightVal = y['weightKg'] ?? 0;
          if (weightVal is num) {
            yieldRecords.add({
              'season': season,
              'weightKg': weightVal.toDouble(),
            });
          }
        }
      }).toList();

      // wait for all subcollection reads to finish
      await Future.wait(futures);

      totalFarmers = farmerIds.length;

      // Bucket yields by season
      final Map<String, List<double>> buckets = {};
      for (final r in yieldRecords) {
        final s = (r['season'] ?? 'unknown').toString();
        final double w = (r['weightKg'] as double);
        buckets.putIfAbsent(s, () => []).add(w);
      }

      final Map<String, double> seasonAvg = {};
      double totalSum = 0;
      int totalCount = 0;
      final Map<String, double> seasonTotals = {};

      buckets.forEach((season, list) {
        final sum = list.fold<double>(0, (a, b) => a + b);
        final avg = (list.isNotEmpty) ? sum / list.length : 0.0;
        seasonAvg[season] = avg;
        seasonTotals[season] = sum;
        totalSum += sum;
        totalCount += list.length;
      });

      final overallAvg = totalCount > 0 ? (totalSum / totalCount) : 0.0;

      final double grandTotal = seasonTotals.values.fold<double>(
        0,
        (a, b) => a + b,
      );
      final Map<String, double> seasonPercent = {};
      if (grandTotal > 0) {
        seasonTotals.forEach((k, v) {
          seasonPercent[k] = (v / grandTotal) * 100.0;
        });
      }

      setState(() {
        avgYieldPerSeason = seasonAvg;
        overallAverageYield = overallAvg;
        pieData = seasonPercent;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    // returns plain Container — caller should wrap with Expanded if needed
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Distinct, theme-friendly palette reused by the pie slices and legend.
  List<Color> get _chartPalette => const [
    AppTheme.brandGreen,
    AppTheme.brandOrange,
    Color(0xFF18A0C1),
    Color(0xFF8E6DF5),
    Color(0xFFEF4444),
    Color(0xFF0EA5A4),
  ];

  List<PieChartSectionData> _buildPieSections() {
    final sections = <PieChartSectionData>[];
    final entries = pieData.entries.toList();
    final colors = _chartPalette;
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      final color = colors[i % colors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: e.value,
          title: '${e.value.toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space2,
        AppTheme.space4,
        AppTheme.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Mango yield overview'),
          AppCard(
            child: _loading
                ? const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _error != null
                ? SizedBox(
                    height: 240,
                    child: EmptyState(
                      icon: Icons.error_outline,
                      title: 'Could not load metrics',
                      message: _error,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.trending_up,
                              label: 'Avg. yield / record',
                              value:
                                  '${overallAverageYield.toStringAsFixed(0)} kg',
                              color: AppTheme.brandGreen,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.agriculture,
                              label: 'Total farms',
                              value: totalFarms.toString(),
                              color: AppTheme.brandOrange,
                            ),
                          ),
                          const SizedBox(width: AppTheme.space3),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.people,
                              label: 'Active farmers',
                              value: totalFarmers.toString(),
                              color: const Color(0xFF18A0C1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space5),
                      if (pieData.isEmpty)
                        const SizedBox(
                          height: 240,
                          child: EmptyState(
                            icon: Icons.pie_chart_outline,
                            title: 'No yield data yet',
                            message:
                                'Season breakdown appears once farmers log '
                                'yields.',
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 150,
                          child: PieChart(
                            PieChartData(
                              sections: _buildPieSections(),
                              sectionsSpace: 2,
                              centerSpaceRadius: 30,
                              borderData: FlBorderData(show: false),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space3),
                        Center(
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: pieData.entries.map((entry) {
                              final season = entry.key;
                              final percent = entry.value.toStringAsFixed(1);
                              final colorIndex =
                                  pieData.keys.toList().indexOf(season) %
                                  _chartPalette.length;
                              final color = _chartPalette[colorIndex];

                              return Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$season: $percent%',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: AppTheme.space2),
                        Center(
                          child: Text(
                            'Average kilograms per yield, by season',
                            style: TextStyle(
                              fontSize: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (avgYieldPerSeason.isNotEmpty) ...[
                          const SizedBox(height: AppTheme.space3),
                          Center(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: avgYieldPerSeason.entries.map((e) {
                                return AppStatusChip(
                                  '${e.key}: ${e.value.toStringAsFixed(0)} kg',
                                  tone: StatusTone.neutral,
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
