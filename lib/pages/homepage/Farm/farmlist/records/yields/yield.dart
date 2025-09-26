import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class YieldsHomePage extends StatefulWidget {
  const YieldsHomePage({super.key, required this.farmRef, this.yearsBack = 2});
  final DocumentReference<Map<String, dynamic>> farmRef;
  final int yearsBack; // how many past years to show besides current

  @override
  State<YieldsHomePage> createState() => _YieldsHomePageState();
}

class _YieldsHomePageState extends State<YieldsHomePage> {
  static const _mangoTypes = <String>[
    'Carabao',
    'Pico',
    'Apple',
    'Katchamita',
    'Others',
  ];

  CollectionReference<Map<String, dynamic>> get _yields =>
      widget.farmRef.collection('yields');

  late final int _currentYear;
  late final List<int> _years; // e.g., [2025, 2024, 2023]

  @override
  void initState() {
    super.initState();
    _currentYear = DateTime.now().year;
    _years = List.generate(widget.yearsBack + 1, (i) => _currentYear - i);
  }

  @override
  Widget build(BuildContext context) {
    // Load from Jan 1 of the oldest year to end of current year
    final oldest = DateTime(_years.last, 1, 1);
    final oldestTs = Timestamp.fromDate(oldest);

    return Scaffold(
      appBar: AppBar(title: const Text('Yields')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _yields
            .orderBy('date')
            .where('date', isGreaterThanOrEqualTo: oldestTs)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          // Aggregate firestore docs -> by month
          final Map<_MonthKey, _MonthAgg> byMonth = {};
          for (final d in (snap.data?.docs ?? [])) {
            final data = d.data();
            final ts = data['date'];
            if (ts is! Timestamp) continue;
            final dt = ts.toDate();
            final kg = _asNum(data['weightKg']);
            final key = _MonthKey(dt.year, dt.month);
            byMonth.putIfAbsent(key, () => _MonthAgg()).add(kg);
          }

          // Build list: years (desc), each with 12 months (Jan..Dec)
          return ListView.builder(
            itemCount: _years.length,
            itemBuilder: (context, yi) {
              final year = _years[yi];

              return Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  initiallyExpanded: yi == 0, // expand current year by default
                  title: Text(
                    '$year',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, mi) {
                        final month = mi + 1; // 1..12
                        final label = DateFormat(
                          'MMMM',
                        ).format(DateTime(year, month));
                        final agg =
                            byMonth[_MonthKey(year, month)] ?? _MonthAgg();

                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              DateFormat(
                                'MMM',
                              ).format(DateTime(year, month)).toUpperCase(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text('$label $year'),
                          subtitle: Text(
                            '${_fmtKg(agg.total)} total • ${agg.count} record(s)',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MonthYieldsPage(
                                  farmRef: widget.farmRef,
                                  year: year,
                                  month: month,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      // Add yield from main page
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add yield'),
        onPressed: () => _openAddSheet(context),
      ),
    );
  }

  Future<void> _openAddSheet(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final dateVN = ValueNotifier<DateTime>(DateTime.now());
    final kgCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String type = _mangoTypes.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, inset + 16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add yield',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: kgCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Kilograms (kg)',
                    prefixIcon: Icon(Icons.monitor_weight_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter kilograms';
                    final x = double.tryParse(v);
                    if (x == null || x <= 0) return 'Enter a valid number > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Mango type',
                    prefixIcon: Icon(Icons.local_florist_outlined),
                  ),
                  items: _mangoTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => type = v ?? _mangoTypes.first,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<DateTime>(
                  valueListenable: dateVN,
                  builder: (context, date, _) {
                    final label = DateFormat('MMMM d, yyyy').format(date);
                    return InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) dateVN.value = picked;
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.event_outlined),
                          border: OutlineInputBorder(),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(label),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final kg = double.tryParse(kgCtrl.text.trim()) ?? 0;
                      await _yields.add({
                        'date': Timestamp.fromDate(
                          DateTime(
                            dateVN.value.year,
                            dateVN.value.month,
                            dateVN.value.day,
                          ),
                        ),
                        'weightKg': kg,
                        'type': type,
                        'notes': notesCtrl.text.trim(),
                        'createdAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) Navigator.pop(context);
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
}

class MonthYieldsPage extends StatefulWidget {
  const MonthYieldsPage({
    super.key,
    required this.farmRef,
    required this.year,
    required this.month,
  });

  final DocumentReference<Map<String, dynamic>> farmRef;
  final int year;
  final int month;

  @override
  State<MonthYieldsPage> createState() => _MonthYieldsPageState();
}

class _MonthYieldsPageState extends State<MonthYieldsPage> {
  CollectionReference<Map<String, dynamic>> get _yields =>
      widget.farmRef.collection('yields');

  late final DateTime _firstDay;
  late final DateTime _lastDay;

  // 👉 This drives UI changes without rebuilding the StreamBuilder.
  late final ValueNotifier<DateTime> _selectedDayVN;

  @override
  void initState() {
    super.initState();
    _firstDay = DateTime(widget.year, widget.month, 1);
    _lastDay = DateTime(widget.year, widget.month + 1, 0);
    _selectedDayVN = ValueNotifier<DateTime>(_firstDay);
  }

  @override
  void dispose() {
    _selectedDayVN.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final startTs = Timestamp.fromDate(_firstDay);
    final endTs = Timestamp.fromDate(
      DateTime(widget.year, widget.month + 1, 1),
    );
    final monthName = DateFormat('MMMM').format(_firstDay);

    return Scaffold(
      appBar: AppBar(title: Text('Yields in $monthName')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _yields
            .orderBy('date')
            .where('date', isGreaterThanOrEqualTo: startTs)
            .where('date', isLessThan: endTs)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          // ---- Transform snapshot → events map (day -> records)
          final Map<DateTime, List<_YieldRecord>> events = {};
          final Map<String, Map<String, dynamic>> originalById = {};

          for (final doc in (snap.data?.docs ?? [])) {
            final data = doc.data();
            final ts = data['date'];
            if (ts is! Timestamp) continue;
            final dt = ts.toDate();
            final day = DateTime(dt.year, dt.month, dt.day);

            originalById[doc.id] = Map<String, dynamic>.from(data);
            (events[day] ??= <_YieldRecord>[]).add(
              _YieldRecord(
                id: doc.id,
                date: dt,
                kg: _asNum(data['weightKg']),
                type: (data['type'] ?? '').toString(),
                notes: (data['notes'] ?? '').toString(),
              ),
            );
          }

          // 👉 Optional: auto-select the latest day that has records
          if ((events.isNotEmpty) &&
              (_selectedDayVN.value.isBefore(_firstDay) ||
                  _selectedDayVN.value.isAfter(_lastDay) ||
                  (events[_dayOnly(_selectedDayVN.value)] == null))) {
            final latestDay =
                (events.keys.toList()..sort((a, b) => b.compareTo(a))).first;
            _selectedDayVN.value = latestDay;
          }

          return Column(
            children: [
              // ---------------- Calendar (locked to month) ----------------
              Padding(
                padding: const EdgeInsets.all(12),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                    child: ValueListenableBuilder<DateTime>(
                      valueListenable: _selectedDayVN,
                      builder: (context, selectedDay, _) {
                        return TableCalendar<_YieldRecord>(
                          firstDay: _firstDay,
                          lastDay: _lastDay,
                          focusedDay:
                              selectedDay.isBefore(_firstDay) ||
                                  selectedDay.isAfter(_lastDay)
                              ? _firstDay
                              : selectedDay,
                          calendarFormat: CalendarFormat.month,
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          },
                          availableGestures: AvailableGestures.none, // lock nav
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            leftChevronVisible: false,
                            rightChevronVisible: false,
                          ),
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          selectedDayPredicate: (day) =>
                              _isSameDay(day, selectedDay),
                          eventLoader: (day) =>
                              events[_dayOnly(day)] ?? const [],
                          onDaySelected: (day, _) {
                            // 🔒 No setState here → no StreamBuilder rebuild.
                            if (!mounted) return;
                            _selectedDayVN.value = _dayOnly(day);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),

              const Divider(height: 0),

              // ---------------- Selected day’s records pane ----------------
              Expanded(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDayVN,
                  builder: (context, selectedDay, _) {
                    final dayKey = _dayOnly(selectedDay);
                    final recs = (events[dayKey] ?? <_YieldRecord>[])
                      ..sort((a, b) => b.date.compareTo(a.date));

                    final selLabel = DateFormat('EEE, MMM d').format(dayKey);
                    final selTotal = recs.fold<double>(0, (s, e) => s + e.kg);

                    return ListView(
                      key: const PageStorageKey(
                        'day-records',
                      ), // smoother scrolling
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        ListTile(
                          title: Text(
                            selLabel,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${_fmtKg(selTotal)} total'),
                        ),

                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SizeTransition(
                              sizeFactor: anim,
                              child: child,
                            ),
                          ),
                          child: recs.isEmpty
                              ? const Padding(
                                  key: ValueKey('empty'),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: _EmptyState(
                                    message: 'No yields on this day.',
                                  ),
                                )
                              : Card(
                                  key: ValueKey(
                                    '${dayKey.toIso8601String()}-${recs.length}',
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      for (final r in recs) ...[
                                        ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.local_mall_outlined,
                                          ),
                                          title: Text(_fmtKg(r.kg)),
                                          subtitle: Text(
                                            [
                                              if (r.type.isNotEmpty)
                                                'Type: ${r.type}',
                                              if (r.notes.isNotEmpty) r.notes,
                                              if (r.type.isEmpty &&
                                                  r.notes.isEmpty)
                                                'No notes',
                                            ].join(' • '),
                                          ),
                                          trailing: Wrap(
                                            spacing: 0,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit notes',
                                                icon: const Icon(
                                                  Icons.edit_note_outlined,
                                                ),
                                                onPressed: () =>
                                                    _editNotesDialog(
                                                      context,
                                                      r.id,
                                                      r.notes,
                                                    ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete',
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () => _deleteWithUndo(
                                                  context,
                                                  r.id,
                                                  // safe copy for undo; may be empty if not needed
                                                  {
                                                    'date': Timestamp.fromDate(
                                                      r.date,
                                                    ),
                                                    'weightKg': r.kg,
                                                    'type': r.type,
                                                    'notes': r.notes,
                                                    'createdAt':
                                                        FieldValue.serverTimestamp(),
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          onLongPress: () => _editNotesDialog(
                                            context,
                                            r.id,
                                            r.notes,
                                          ),
                                        ),
                                        if (r != recs.last)
                                          const Divider(height: 0),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------- Edit notes (dialog) ----------------
  Future<void> _editNotesDialog(
    BuildContext context,
    String id,
    String currentNotes,
  ) async {
    final ctrl = TextEditingController(text: currentNotes);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: const Text('Edit notes'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Add details about this harvest…',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
              onPressed: saving
                  ? null
                  : () async {
                      setLocal(() => saving = true);
                      try {
                        await _yields.doc(id).update({
                          'notes': ctrl.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        });
                        if (mounted) Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Notes updated')),
                          );
                        }
                      } finally {
                        if (mounted) setLocal(() => saving = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Delete with confirm + Undo ----------------
  Future<void> _deleteWithUndo(
    BuildContext context,
    String id,
    Map<String, dynamic> prevData,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete record?'),
        content: const Text('This harvest record will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _yields.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Record deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await _yields.add({
                ...prevData,
                'restoredAt': FieldValue.serverTimestamp(),
              });
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }
}

class _YieldRecord {
  final String id;
  final DateTime date;
  final double kg;
  final String type;
  final String notes;
  _YieldRecord({
    required this.id,
    required this.date,
    required this.kg,
    required this.type,
    required this.notes,
  });
}

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

double _asNum(dynamic v) {
  if (v == null) return 0.0;
  if (v is int) return v.toDouble();
  if (v is double) return v;
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}

String _fmtKg(double v) {
  final isInt = v % 1 == 0;
  return isInt ? '${v.toInt()} kg' : '${v.toStringAsFixed(1)} kg';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message = 'No data yet'});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// =============================== Helpers ===================================
class _MonthKey {
  final int year;
  final int month;
  const _MonthKey(this.year, this.month);
  @override
  bool operator ==(Object other) =>
      other is _MonthKey && year == other.year && month == other.month;
  @override
  int get hashCode => Object.hash(year, month);
}

class _MonthAgg {
  double total = 0;
  int count = 0;
  void add(double kg) {
    total += kg;
    count++;
  }
}
