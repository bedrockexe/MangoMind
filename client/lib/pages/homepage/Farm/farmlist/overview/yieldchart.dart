import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class CompactYieldCard extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? farmRef;
  const CompactYieldCard({super.key, this.farmRef});

  @override
  State<CompactYieldCard> createState() => _CompactYieldCardState();
}

class _CompactYieldCardState extends State<CompactYieldCard> {
  bool _loading = true;
  final Map<int, double> _kgPerMonth = {for (var i = 1; i <= 12; i++) i: 0.0};
  final int _year = DateTime.now().year;

  // Season definitions
  final List<int> wetMonths = [5, 6, 7, 8, 9, 10]; // May–Oct
  final List<int> dryMonths = [11, 12, 1, 2, 3, 4]; // Nov–Apr

  // Track selected season (0 = auto/current, 1 = Wet, 2 = Dry)
  int _seasonMode = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    for (var i = 1; i <= 12; i++) {
      _kgPerMonth[i] = 0.0;
    }

    Query query = widget.farmRef!
        .collection('yields')
        .where('seasonYear', isEqualTo: _year);

    final snap = await query.get();
    for (final d in snap.docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final w = (data['weightKg'] is num)
          ? (data['weightKg'] as num).toDouble()
          : double.tryParse('${data['weightKg']}') ?? 0.0;

      Timestamp? ts;
      if (data['date'] is Timestamp) {
        ts = data['date'] as Timestamp;
      } else if (data['createdAt'] is Timestamp) {
        ts = data['createdAt'] as Timestamp;
      }

      final month = ts != null
          ? ts.toDate().month
          : (data['month'] is int ? data['month'] as int : 0);
      if (month >= 1 && month <= 12) {
        _kgPerMonth[month] = (_kgPerMonth[month] ?? 0.0) + w;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  List<int> get _currentSeasonMonths {
    final m = DateTime.now().month;
    if (_seasonMode == 1) return wetMonths;
    if (_seasonMode == 2) return dryMonths;
    return wetMonths.contains(m) ? wetMonths : dryMonths;
  }

  String get _seasonName {
    if (_seasonMode == 1) return "Wet Season";
    if (_seasonMode == 2) return "Dry Season";
    final m = DateTime.now().month;
    return wetMonths.contains(m) ? "Wet Season" : "Dry Season";
  }

  List<FlSpot> get _spots {
    final months = _currentSeasonMonths;
    return months.asMap().entries.map((e) {
      final index = e.key; // 0..5
      final month = e.value; // real month
      return FlSpot(index.toDouble(), _kgPerMonth[month] ?? 0.0);
    }).toList();
  }

  double get _maxY {
    final values = _currentSeasonMonths.map((m) => _kgPerMonth[m] ?? 0.0);
    final maxKg = values.fold<double>(0.0, (p, n) => n > p ? n : p);
    return maxKg <= 0 ? 10.0 : (maxKg * 1.2).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
    }

    final months = _currentSeasonMonths;
    final spots = _spots;
    final yMax = _maxY;

    return Container(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          children: [
            // Header + toggle
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yields this Season',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$_seasonName ($_year)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),

                const Spacer(),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.swap_horiz),
                  onSelected: (val) => setState(() => _seasonMode = val),
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 0,
                      child: Text("Auto (current)"),
                    ),
                    const PopupMenuItem(value: 1, child: Text("Wet Season")),
                    const PopupMenuItem(value: 2, child: Text("Dry Season")),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Graph
            SizedBox(
              height: 110,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (months.length - 1).toDouble(),
                  minY: 0,
                  maxY: yMax,
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()} kg',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black54,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= months.length) {
                            return const SizedBox.shrink();
                          }
                          final label = DateFormat.MMM().format(
                            DateTime(0, months[idx]),
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2.5,
                      dotData: FlDotData(show: true),
                      color: Theme.of(context).primaryColor,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Total line
            Text(
              'Total: ${_currentSeasonMonths.map((m) => _kgPerMonth[m] ?? 0.0).reduce((a, b) => a + b).toStringAsFixed(0)} kg',
              style: const TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
