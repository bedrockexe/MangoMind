// mango_yield_card_subcollections.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';

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
              'weightKg': (weightVal as num).toDouble(),
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final sections = <PieChartSectionData>[];
    final entries = pieData.entries.toList();
    final colors = [
      Colors.green.shade600,
      Colors.orange.shade600,
      Colors.blue.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
    ];
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
    if (sections.isEmpty) {
      sections.addAll([
        PieChartSectionData(
          color: Colors.green,
          value: 50,
          title: '50%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        PieChartSectionData(
          color: Colors.orange,
          value: 50,
          title: '50%',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ]);
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.green.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: _loading
            ? SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Loading mango metrics...'),
                    ],
                  ),
                ),
              )
            : _error != null
            ? SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'Error: $_error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_florist,
                        color: Colors.green.shade600,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Mango Yield Overview',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.trending_up,
                          label: 'Avg. Yield (record)',
                          value: '${overallAverageYield.toStringAsFixed(0)} kg',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.agriculture,
                          label: 'Total Farms',
                          value: totalFarms.toString(),
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          icon: Icons.people,
                          label: 'Total Active Farmers',
                          value: totalFarmers.toString(),
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 12),
                  Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: pieData.entries.map((entry) {
                        final season = entry.key;
                        final percent = entry.value.toStringAsFixed(1);

                        // Pick the same colors you used for the pie chart slices
                        final colors = [
                          Colors.green.shade600,
                          Colors.orange.shade600,
                          Colors.blue.shade600,
                          Colors.purple.shade600,
                          Colors.red.shade600,
                          Colors.teal.shade600,
                        ];
                        final colorIndex =
                            pieData.keys.toList().indexOf(season) %
                            colors.length;
                        final color = colors[colorIndex];

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$season: $percent%',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Center(
                    child: const Text(
                      'Average Kilogram per yield by season',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 8),
                  if (avgYieldPerSeason.isNotEmpty) ...[
                    Center(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: avgYieldPerSeason.entries.map((e) {
                          return Chip(
                            backgroundColor: Colors.grey[400],
                            label: Text(
                              '${e.key}: ${e.value.toStringAsFixed(0)} kg/per yield',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
