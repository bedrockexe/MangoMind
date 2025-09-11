import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

/// DROP-IN: Simple, list-first yields page designed for tech-illiterate users.
/// - Big "Record yield" button
/// - Month dropdown filter
/// - At-a-glance summary chips (month/season/year)
/// - Simple list; long-press to delete with Undo
/// - Optional mini trend (bars) placed last
///
/// Firestore document shape under farmRef.collection('yields'):
/// { date: Timestamp, kg: num, notes: String? }

class YieldsSimplePage extends StatefulWidget {
  const YieldsSimplePage({super.key, required this.farmRef});
  final DocumentReference<Map<String, dynamic>> farmRef;

  @override
  State<YieldsSimplePage> createState() => _YieldsSimplePageState();
}

class _YieldsSimplePageState extends State<YieldsSimplePage> {
  CollectionReference<Map<String, dynamic>> get yieldsCol =>
      widget.farmRef.collection('yields');

  // ------ Month filter ------
  late int _selYear;
  late int _selMonth; // 1-12

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selYear = now.year;
    _selMonth = now.month;
  }

  DateTime _monthStart(int year, int month) => DateTime(year, month, 1);
  DateTime _monthEnd(int year, int month) => DateTime(year, month + 1, 1);

  // Season in PH context: Dry (Nov–Apr), Wet (May–Oct)
  bool _isDryMonth(int m) => (m == 11 || m == 12 || m <= 4);

  // --------- ADD: Bottom sheet (simple) ----------
  Future<void> _openAddSheet() async {
    final formKey = GlobalKey<FormState>();
    final kgCtrl = TextEditingController();
    DateTime date = DateTime.now();
    String notes = '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final insets = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, insets + 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Record yield',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),

                // Date (Today by default)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => date = picked);
                      }
                    },
                    child: const Text('Pick'),
                  ),
                ),
                const SizedBox(height: 8),

                // KG (number keypad, big)
                TextFormField(
                  controller: kgCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'e.g. 25',
                  ),
                  validator: (v) {
                    final x = double.tryParse((v ?? '').trim());
                    if (x == null || x <= 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Notes (optional, smaller)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  onChanged: (v) => notes = v.trim(),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      await yieldsCol.add({
                        'date': Timestamp.fromDate(
                          DateTime(date.year, date.month, date.day),
                        ),
                        'kg': double.parse(kgCtrl.text.trim()),
                        'notes': notes,
                      });
                      if (mounted) Navigator.pop(context);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yield recorded')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------ Streams for the selected month ------
  Stream<QuerySnapshot<Map<String, dynamic>>> _monthStream() {
    final from = _monthStart(_selYear, _selMonth);
    final to = _monthEnd(_selYear, _selMonth);
    return yieldsCol
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date')
        .snapshots();
  }

  // Whole-year stream for summaries/trend
  Stream<QuerySnapshot<Map<String, dynamic>>> _yearStream(int year) {
    final from = DateTime(year, 1, 1);
    final to = DateTime(year + 1, 1, 1);
    return yieldsCol
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date')
        .snapshots();
  }

  // ------- Helpers to compute totals -------
  double _sumKg(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    double t = 0;
    for (final d in docs) {
      t += (d['kg'] as num).toDouble();
    }
    return t;
  }

  double _sumMonth(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    int m,
  ) {
    double t = 0;
    for (final d in docs) {
      final dt = (d['date'] as Timestamp).toDate();
      if (dt.month == m) t += (d['kg'] as num).toDouble();
    }
    return t;
  }

  Map<int, double> _monthlyBuckets(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final map = <int, double>{for (var i = 1; i <= 12; i++) i: 0};
    for (final d in docs) {
      final dt = (d['date'] as Timestamp).toDate();
      final kg = (d['kg'] as num).toDouble();
      map[dt.month] = (map[dt.month] ?? 0) + kg;
    }
    return map;
  }

  double _seasonTotal(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    bool dry,
  ) {
    double t = 0;
    for (final d in docs) {
      final m = (d['date'] as Timestamp).toDate().month;
      final isDry = _isDryMonth(m);
      if (dry ? isDry : !isDry) t += (d['kg'] as num).toDouble();
    }
    return t;
  }

  // --------- UI ---------
  @override
  Widget build(BuildContext context) {
    final monthsShort = const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Yields')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('Record yield'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Row: Month dropdown + Add button (big)
            Row(
              children: [
                Expanded(
                  child: _MonthPicker(
                    year: _selYear,
                    month: _selMonth,
                    onChanged: (y, m) => setState(() {
                      _selYear = y;
                      _selMonth = m;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _openAddSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Record'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summaries (chip style)
            StreamBuilder(
              stream: _yearStream(_selYear),
              builder:
                  (
                    context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
                  ) {
                    final docs = snap.data?.docs ?? const [];
                    final totalYear = _sumKg(docs);
                    final totalMonth = _sumMonth(docs, _selMonth);
                    final totalDry = _seasonTotal(docs, true);
                    final totalWet = _seasonTotal(docs, false);

                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SumChip(
                          icon: Icons.calendar_month,
                          label: 'This month',
                          value: '${totalMonth.toStringAsFixed(1)} kg',
                        ),
                        _SumChip(
                          icon: Icons.wb_sunny,
                          label: 'Dry (Nov–Apr)',
                          value: '${totalDry.toStringAsFixed(1)} kg',
                        ),
                        _SumChip(
                          icon: Icons.water_drop,
                          label: 'Wet (May–Oct)',
                          value: '${totalWet.toStringAsFixed(1)} kg',
                        ),
                        _SumChip(
                          icon: Icons.event,
                          label: 'This year',
                          value: '${totalYear.toStringAsFixed(1)} kg',
                        ),
                      ],
                    );
                  },
            ),
            const SizedBox(height: 12),

            // List for selected month
            Expanded(
              child: StreamBuilder(
                stream: _monthStream(),
                builder:
                    (
                      context,
                      AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
                    ) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const _EmptyState();
                      }

                      return ListView.separated(
                        itemCount: docs.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            // Month header total
                            final total = _sumKg(docs);
                            return ListTile(
                              title: Text(
                                '${monthsShort[_selMonth - 1]} $_selYear',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              trailing: Text(
                                '${total.toStringAsFixed(1)} kg',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            );
                          }
                          final d = docs[i - 1];
                          final dt = (d['date'] as Timestamp).toDate();
                          final kg = (d['kg'] as num).toDouble();
                          final notes =
                              (d.data().containsKey('notes')
                                      ? (d['notes'] ?? '')
                                      : '')
                                  as String;

                          return InkWell(
                            onLongPress: () => _confirmDelete(d),
                            child: ListTile(
                              leading: const Icon(Icons.inventory_2_outlined),
                              title: Text(
                                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}',
                              ),
                              subtitle: notes.isEmpty
                                  ? null
                                  : Text(
                                      notes,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: Text(
                                '${kg.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
              ),
            ),

            // Small, optional trend (end of page so it never confuses)
            StreamBuilder(
              stream: _yearStream(_selYear),
              builder:
                  (
                    context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
                  ) {
                    final docs = snap.data?.docs ?? const [];
                    final buckets = _monthlyBuckets(docs);
                    final maxVal =
                        (buckets.values.isEmpty
                                ? 10.0
                                : buckets.values.reduce(math.max))
                            .clamp(10, double.infinity);

                    return _MiniBars(
                      label: 'Monthly trend $_selYear',
                      data: [for (var i = 1; i <= 12; i++) buckets[i] ?? 0],
                      maxY: maxVal * 1.2,
                    );
                  },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final kg = (doc['kg'] as num).toDouble();
    final dt = (doc['date'] as Timestamp).toDate();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete record?'),
        content: Text(
          'Delete ${kg.toStringAsFixed(1)} kg on '
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    // Delete with undo
    await doc.reference.delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            // Restore (best-effort if we still have data)
            await doc.reference.set(doc.data());
          },
        ),
      ),
    );
  }
}

/// Month & year dropdown with big tap targets.
class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.year,
    required this.month,
    required this.onChanged,
  });

  final int year;
  final int month;
  final void Function(int year, int month) onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Allow +/- 3 years for simplicity
    final years = [for (var y = now.year - 3; y <= now.year + 3; y++) y];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: month,
            decoration: const InputDecoration(labelText: 'Month'),
            items: List.generate(12, (i) {
              return DropdownMenuItem(value: i + 1, child: Text(months[i]));
            }),
            onChanged: (m) => onChanged(year, m ?? month),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<int>(
            isExpanded: true,
            value: year,
            decoration: const InputDecoration(labelText: 'Year'),
            items: years
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (y) => onChanged(y ?? year, month),
          ),
        ),
      ],
    );
  }
}

/// Summary chip widget
class _SumChip extends StatelessWidget {
  const _SumChip({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label: $value'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}

/// Minimal bars (no external chart lib) to keep things simple & responsive.
class _MiniBars extends StatelessWidget {
  const _MiniBars({
    required this.label,
    required this.data,
    required this.maxY,
  });

  final String label;
  final List<double> data; // 12 values for months
  final double maxY;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, c) {
                final barWidth = (c.maxWidth - 11 * 6) / 12; // spacing ~6
                final height = math.max(120.0, c.maxWidth * 0.25);

                return SizedBox(
                  height: height,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(12, (i) {
                      final v = data[i];
                      final h = (maxY <= 0) ? 0 : (v / maxY) * (height - 20);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: math.max(10, barWidth),
                              // height: h.clamp(0, height - 20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                'J',
                                'F',
                                'M',
                                'A',
                                'M',
                                'J',
                                'J',
                                'A',
                                'S',
                                'O',
                                'N',
                                'D',
                              ][i],
                              style: textTheme.bodySmall,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty-state
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64),
          const SizedBox(height: 8),
          const Text('No yields yet for this month'),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tap the “Record yield” button to add one.'),
              ),
            ),
            icon: const Icon(Icons.info_outline),
            label: const Text('How?'),
          ),
        ],
      ),
    );
  }
}
