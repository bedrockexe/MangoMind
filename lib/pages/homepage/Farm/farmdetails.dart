import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/pages/homepage/Farm/yield.dart';
import 'package:intl/intl.dart';

// Opening Class
class FarmDetailsPage extends StatefulWidget {
  final String farmId;
  const FarmDetailsPage({super.key, required this.farmId});

  @override
  State<FarmDetailsPage> createState() => _FarmDetailsPageState();
}

// Child Class
class _FarmDetailsPageState extends State<FarmDetailsPage>
    with SingleTickerProviderStateMixin {
  // Initial Variables
  late final DocumentReference<Map<String, dynamic>> farmRef;
  late final TabController _tab;

  static const _mangoTypes = <String>[
    'Carabao',
    'Pico',
    'Apple',
    'Katchamita',
    'Others',
  ];

  String _seasonFromDate(DateTime d) {
    // PH: Wet = May–Oct; Dry = Nov–Apr
    return (d.month >= 5 && d.month <= 10) ? 'Wet' : 'Dry';
  }

  int _seasonYearFromDate(DateTime d) {
    // Label “season year” so Dry spans Nov–Apr under the *next* year label.
    // e.g., Nov 2025 -> Dry 2026; Jan 2026 -> Dry 2026; Jun 2026 -> Wet 2026
    final isWet = d.month >= 5 && d.month <= 10;
    if (!isWet && d.month >= 11) return d.year + 1; // Nov–Dec -> next year
    return d.year; // Jan–Apr Dry -> same calendar year; Wet -> same year
  }

  // Initialization
  @override
  void initState() {
    super.initState();
    farmRef = FirebaseFirestore.instance.collection('farms').doc(widget.farmId);
    _tab = TabController(length: 3, vsync: this);
  }

  // disposer
  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ===== Widget Helpers ======
  // Colors
  Color _taskStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'In-Progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.outline; // Pending (gray)
    }
  }

  Color _statusColorSmall(String status, BuildContext context) {
    switch (status) {
      case 'In-Progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.outline; // Pending = gray
    }
  }
  // Colors

  // Futures
  Future<void> _addObservationSheet() async {
    String type = 'anthracnose';
    String severity = 'low';
    final notes = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool saving = false; // <-- local saving flag inside the sheet

        return StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: AbsorbPointer(
              // disable inputs while saving
              absorbing: saving,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Record Disease Observation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),

                  // Type
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'anthracnose',
                        child: Text('Anthracnose'),
                      ),
                      DropdownMenuItem(
                        value: 'powdery_mildew',
                        child: Text('Powdery Mildew'),
                      ),
                    ],
                    onChanged: (v) => type = v ?? 'anthracnose',
                  ),
                  const SizedBox(height: 8),

                  // Severity
                  DropdownButtonFormField<String>(
                    value: severity,
                    decoration: const InputDecoration(labelText: 'Severity'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('Low')),
                      DropdownMenuItem(value: 'med', child: Text('Medium')),
                      DropdownMenuItem(value: 'high', child: Text('High')),
                    ],
                    onChanged: (v) => severity = v ?? 'low',
                  ),
                  const SizedBox(height: 8),

                  // Notes
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Save button with loading state
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              setLocal(() => saving = true);
                              try {
                                // 1) write observation
                                await farmRef.collection('observations').add({
                                  'type': type,
                                  'severity': severity,
                                  'observedAt': FieldValue.serverTimestamp(),
                                  'notes': notes.text.trim(),
                                  'createdAt': FieldValue.serverTimestamp(),
                                });

                                // 2) update summary fields on farm doc (optional)
                                await farmRef
                                    .update({
                                      'diseasePest.lastObserved':
                                          FieldValue.serverTimestamp(),
                                      if (type == 'anthracnose')
                                        'diseasePest.anthracnose': true,
                                      if (type == 'powdery_mildew')
                                        'diseasePest.powderyMildew': true,
                                    })
                                    .catchError((_) {});

                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to save: $e'),
                                    ),
                                  );
                                }
                              } finally {
                                setLocal(() => saving = false);
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(saving ? 'Saving…' : 'Save Observation'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _editNotesDialog(
    DocumentReference<Map<String, dynamic>> ref,
    String current,
  ) async {
    final ctrl = TextEditingController(text: current);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Edit notes'),
          content: TextField(
            controller: ctrl,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Write notes…'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setLocal(() => saving = true);
                      try {
                        await ref.update({'notes': ctrl.text.trim()});
                        if (context.mounted) Navigator.pop(context);
                      } finally {
                        setLocal(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTaskSheet() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime? due;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool saving = false; // local state inside the sheet
        return StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add Task',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title *'),
                ),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(
                          due == null
                              ? 'Pick due date'
                              : 'Due: ${due!.toLocal().toString().split(' ').first}',
                        ),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: due ?? now,
                            firstDate: DateTime(now.year - 5),
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) setLocal(() => due = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            if (title.text.trim().isEmpty) return;
                            setLocal(() => saving = true);
                            try {
                              await farmRef.collection('tasks').add({
                                'title': title.text.trim(),
                                'notes': notes.text.trim(),
                                'isDone': false,
                                'status': 'Pending',
                                'dueDate': due == null
                                    ? null
                                    : Timestamp.fromDate(due!),
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              if (context.mounted) Navigator.pop(context);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to save: $e')),
                                );
                              }
                            } finally {
                              setLocal(() => saving = false);
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(saving ? 'Saving...' : 'Save Task'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addYieldSheet() async {
    final formKey = GlobalKey<FormState>();
    final dateVN = ValueNotifier<DateTime>(DateTime.now());
    final kgCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    // Local state for season (auto from date but user can override)
    String type = _mangoTypes.first;
    String season = _seasonFromDate(dateVN.value);
    int seasonYear = _seasonYearFromDate(dateVN.value);
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final inset = MediaQuery.of(ctx).viewInsets.bottom;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Padding(
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

                  // Kilograms
                  TextFormField(
                    controller: kgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kilograms (kg)',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        setLocal(() => saving = false);
                        return 'Enter kilograms';
                      }
                      final x = double.tryParse(v);
                      if (x == null || x <= 0) {
                        setLocal(() => saving = false);
                        return 'Enter a valid number > 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mango type
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

                  // Date picker (auto-updates season + year)
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
                          if (picked != null) {
                            dateVN.value = picked;
                            setLocal(() {
                              season = _seasonFromDate(picked);
                              seasonYear = _seasonYearFromDate(picked);
                            });
                          }
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

                  // Season row (dropdown + year chip)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: season,
                          decoration: const InputDecoration(
                            labelText: 'Season',
                            prefixIcon: Icon(Icons.thermostat_auto_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Wet', child: Text('Wet')),
                            DropdownMenuItem(value: 'Dry', child: Text('Dry')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() {
                              season = v;
                              // Recompute seasonYear if user flips season manually:
                              final d = dateVN.value;
                              // If Wet selected -> same calendar year
                              // If Dry selected -> Nov–Dec dry should map to next year label,
                              // Jan–Apr dry stays same year.
                              if (v == 'Wet') {
                                seasonYear = d.year;
                              } else {
                                seasonYear = (d.month >= 11)
                                    ? d.year + 1
                                    : d.year;
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      InputChip(
                        label: Text('$seasonYear'),
                        avatar: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        onPressed: null, // display only
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Notes
                  TextFormField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
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
                              if (!formKey.currentState!.validate()) return;

                              final kg =
                                  double.tryParse(kgCtrl.text.trim()) ?? 0;
                              final dOnly = DateTime(
                                dateVN.value.year,
                                dateVN.value.month,
                                dateVN.value.day,
                              );

                              final isWet = (season == 'Wet');
                              final seasonKey = '$seasonYear-$season';

                              await farmRef.collection('yields').add({
                                'date': Timestamp.fromDate(dOnly),
                                'weightKg': kg,
                                'type': type,
                                'notes': notesCtrl.text.trim(),
                                // NEW fields for season reporting:
                                'season': season, // 'Wet' | 'Dry'
                                'isWet': isWet, // boolean
                                'seasonYear': seasonYear, // e.g., 2026
                                'seasonKey': seasonKey, // e.g., '2026-Dry'
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              if (context.mounted) Navigator.pop(context);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Yield Recorded'),
                                  ),
                                );
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveIrrigation({
    required DateTime date,
    required String method,
    required int durationMin,
    required int waterLiters,
    String zone = '',
    String notes = '',
  }) async {
    // store date as Y/M/D (no time) for easier grouping
    final dOnly = DateTime(date.year, date.month, date.day);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final entryRef = farmRef.collection('irrigations').doc();

      tx.set(entryRef, {
        'date': Timestamp.fromDate(dOnly),
        'method': method,
        'durationMin': durationMin,
        'waterLiters': waterLiters,
        'zone': zone.trim(),
        'notes': notes.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update farm summary KPIs
      tx.update(farmRef, {
        'irrigation.lastIrrigatedAt': Timestamp.fromDate(dOnly),
        'irrigation.seasonWaterLiters': FieldValue.increment(waterLiters),
      });
    });
  }

  Future<void> _updateIrrigation({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    required DateTime date,
    required String method,
    required int durationMin,
    required int waterLiters,
    String zone = '',
    String notes = '',
  }) async {
    final old = doc.data()!;
    final oldLiters = (old['waterLiters'] ?? 0) as int;
    final delta = waterLiters - oldLiters;
    final dOnly = DateTime(date.year, date.month, date.day);

    // 1) Do writes only (no reads) in the transaction
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(doc.reference, {
        'date': Timestamp.fromDate(dOnly),
        'method': method,
        'durationMin': durationMin,
        'waterLiters': waterLiters,
        'zone': zone.trim(),
        'notes': notes.trim(),
      });

      tx.update(farmRef, {
        'irrigation.seasonWaterLiters': FieldValue.increment(delta),
      });
    });

    // 2) Outside the transaction, recompute latest date and update farm summary
    final latest = await farmRef
        .collection('irrigations')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    if (latest.docs.isEmpty) {
      await farmRef.update({'irrigation.lastIrrigatedAt': FieldValue.delete()});
    } else {
      await farmRef.update({
        'irrigation.lastIrrigatedAt': latest.docs.first['date'],
      });
    }
  }

  Future<void> _deleteIrrigation(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final m = doc.data()!;
    final liters = (m['waterLiters'] ?? 0) as int;
    final deletedDate = (m['date'] as Timestamp?)?.toDate();

    // 1) Remove and decrement liters
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.delete(doc.reference);
      tx.update(farmRef, {
        'irrigation.seasonWaterLiters': FieldValue.increment(-liters),
      });
    });

    // 2) If the deleted one was the latest, recalc lastIrrigatedAt (cheap query)
    if (deletedDate != null) {
      final latest = await farmRef
          .collection('irrigations')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (latest.docs.isEmpty) {
        await farmRef.update({
          'irrigation.lastIrrigatedAt': FieldValue.delete(),
        });
      } else {
        await farmRef.update({
          'irrigation.lastIrrigatedAt': latest.docs.first['date'],
        });
      }
    }
  }

  Future<void> _showIrrigationSheet({
    DocumentSnapshot<Map<String, dynamic>>?
    editingDoc, // null = Add, not null = Edit
  }) async {
    // ---- SAFE reads: use .data() and null-aware lookups ----
    final m = editingDoc?.data(); // may be null for "Add"

    // Date (fallback to today if missing)
    DateTime date = (() {
      final ts = m?['date'];
      if (ts is Timestamp) return ts.toDate();
      return DateTime.now();
    })();

    // Method dropdown value (fallback to 'drip')
    String method = (m?['method'] as String?) ?? 'drip';

    // Controllers with safe fallbacks (missing fields => empty/default)
    final zoneCtrl = TextEditingController(text: (m?['zone'] as String?) ?? '');
    final notesCtrl = TextEditingController(
      text: (m?['notes'] as String?) ?? '',
    );
    final durationCtrl = TextEditingController(
      text: (m?['durationMin']?.toString() ?? ''),
    );
    final litersCtrl = TextEditingController(
      text: (m?['waterLiters']?.toString() ?? ''),
    );

    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: AbsorbPointer(
            absorbing: saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  editingDoc == null ? 'Log Irrigation' : 'Edit Irrigation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Date picker
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(
                    'Date: ${DateTime(date.year, date.month, date.day).toString().split(' ').first}',
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setLocal(() => date = picked);
                  },
                ),
                const SizedBox(height: 8),

                // Method (dropdown)
                DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: const [
                    DropdownMenuItem(value: 'drip', child: Text('Drip')),
                    DropdownMenuItem(
                      value: 'sprinkler',
                      child: Text('Sprinkler'),
                    ),
                    DropdownMenuItem(value: 'furrow', child: Text('Furrow')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? 'drip'),
                ),
                const SizedBox(height: 8),

                // Duration (TextField)
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: 'e.g. 45',
                  ),
                ),
                const SizedBox(height: 8),

                // Water (TextField)
                TextField(
                  controller: litersCtrl,
                  keyboardType: TextInputType.number,
                  // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Water (Liters)',
                    hintText: 'e.g. 1200',
                  ),
                ),
                const SizedBox(height: 8),

                // Zone & Notes
                TextField(
                  controller: zoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Zone/Block (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 12),

                // Save button with loading
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : () async {
                            final duration =
                                int.tryParse(durationCtrl.text.trim()) ?? 0;
                            final liters =
                                int.tryParse(litersCtrl.text.trim()) ?? 0;
                            if (duration <= 0 || liters <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Enter valid duration and liters',
                                  ),
                                ),
                              );
                              return;
                            }

                            setLocal(() => saving = true);
                            try {
                              if (editingDoc == null) {
                                await _saveIrrigation(
                                  date: date,
                                  method: method,
                                  durationMin: duration,
                                  waterLiters: liters,
                                  zone: zoneCtrl.text,
                                  notes: notesCtrl.text,
                                );
                              } else {
                                await _updateIrrigation(
                                  doc: editingDoc,
                                  date: date,
                                  method: method,
                                  durationMin: duration,
                                  waterLiters: liters,
                                  zone: zoneCtrl.text,
                                  notes: notesCtrl.text,
                                );
                              }
                              if (context.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed: $e')),
                                );
                              }
                            } finally {
                              setLocal(() => saving = false);
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      saving
                          ? 'Saving…'
                          : (editingDoc == null ? 'Save' : 'Save Changes'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addIrrigationSheet() {
    return _showIrrigationSheet();
  }

  Future<void> _editIrrigationSheet(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return _showIrrigationSheet(editingDoc: doc);
  }

  // Futures

  // ===== Widget Helpers ======

  // ===== Widgets ======
  Widget _statusPillSmall(String status, BuildContext context) {
    final c = _statusColorSmall(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _openTasksPreviewCard() {
    return InkWell(
      onTap: () => _tab.index = 1, // 👈 go to "Tasks" tab
      borderRadius: BorderRadius.circular(12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: farmRef
                .collection('tasks')
                .where('isDone', isEqualTo: false) // only open tasks
                .orderBy('dueDate', descending: false) // soonest first
                .orderBy('createdAt', descending: true) // tie-breaker
                .limit(20) // pull a few, we’ll pick 3
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Text('Open Tasks');
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return Row(
                  children: const [
                    Expanded(child: Text('Open Tasks')),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                );
              }

              final docs = snap.data?.docs ?? [];
              // Group by due date
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              final overdue = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final todayList = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final noDue = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final d in docs) {
                final t = d.data();
                final dueTs = t['dueDate'] as Timestamp?;
                if (dueTs == null) {
                  noDue.add(d);
                  continue;
                }
                final dt = dueTs.toDate();
                final dueOnly = DateTime(dt.year, dt.month, dt.day);
                if (dueOnly.isBefore(today)) {
                  overdue.add(d);
                } else if (dueOnly.isAtSameMomentAs(today)) {
                  todayList.add(d);
                } else {
                  upcoming.add(d);
                }
              }

              // Pick up to 3 tasks: Overdue → Today → Upcoming → No Due
              final picked = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              void take(List<QueryDocumentSnapshot<Map<String, dynamic>>> src) {
                for (final x in src) {
                  if (picked.length < 3) picked.add(x);
                }
              }

              take(overdue);
              take(todayList);
              take(upcoming);
              take(noDue);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.checklist, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Open Tasks',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _tab.index = 1,
                        child: const Text('See all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (picked.isEmpty) ...[
                    const Text('All caught up 👏'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _addTaskSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Task'),
                    ),
                  ] else
                    ...picked.map((doc) {
                      final t = doc.data();
                      final title = (t['title'] ?? '') as String;
                      final status = (t['status'] as String?) ?? 'Pending';
                      final dueTs = t['dueDate'] as Timestamp?;
                      final dueStr = dueTs == null
                          ? 'No due date'
                          : dueTs
                                .toDate()
                                .toLocal()
                                .toString()
                                .split(' ')
                                .first;

                      // Overdue marker (red) if not done and due date is in the past
                      bool isOverdue = false;
                      if (dueTs != null && status != 'Done') {
                        final d = dueTs.toDate();
                        final dd = DateTime(d.year, d.month, d.day);
                        isOverdue = dd.isBefore(today);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title + due
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (isOverdue)
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      if (isOverdue) const SizedBox(width: 4),
                                      Text(
                                        dueStr,
                                        style: isOverdue
                                            ? const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              )
                                            : Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Colored status
                            _statusPillSmall(status, context),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _overviewTab() {
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
        final anth = dp['anthracnose'] == true;
        final pm = dp['powderyMildew'] == true;

        final DateTime? _lastDiseaseDt = lastObs?.toDate();
        final String _lastDiseaseValue = _lastDiseaseDt == null
            ? '—'
            : DateFormat('yyyy-MM-dd').format(_lastDiseaseDt);

        // Color logic: orange if in last 14 days, green otherwise
        final bool _recent =
            _lastDiseaseDt != null &&
            DateTime.now().difference(_lastDiseaseDt).inDays <= 14;

        final Color _accent = _recent
            ? const Color(0xFFF59E0B)
            : const Color(0xFF22C55E);
        final IconData _icon = _recent
            ? Icons.warning_amber_rounded
            : Icons.verified_rounded;
        final String? _caption = _recent
            ? 'Recent issue—monitor closely'
            : 'No recent disease flags';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(
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
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (areaHa != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Area: ${areaHa.toString()} ha',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _openTasksPreviewCard(),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: farmRef
                  .collection('yields')
                  .orderBy('date', descending: true)
                  .limit(500)
                  .snapshots(),
              builder: (context, ysnap) {
                String lastSeasonTotal = '—';

                if (ysnap.hasData) {
                  final docs = ysnap.data!.docs;

                  // Sum weights per seasonKey "YYYY-Season"
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
                  String? bestKey;
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
                    } else if (yr > bestYear!) {
                      isBetter = true;
                    } else if (yr == bestYear!) {
                      // Within same seasonYear, Wet is later than Dry
                      final currentRank = (ssn == 'Wet') ? 2 : 1;
                      final bestRank = (bestSeason == 'Wet') ? 2 : 1;
                      if (currentRank > bestRank) isBetter = true;
                    }

                    if (isBetter) {
                      bestKey = key;
                      bestYear = yr;
                      bestSeason = ssn;
                    }
                  }

                  if (bestKey != null) {
                    final sum = totals[bestKey!] ?? 0;
                    lastSeasonTotal = sum.toStringAsFixed(sum % 1 == 0 ? 0 : 1);
                  }
                }

                return Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'Last Disease',
                        value: _lastDiseaseValue,
                        caption: _caption,
                        color: _accent,
                        icon: _icon,
                      ),
                    ),
                    // const SizedBox(width: 8),
                    // Expanded(
                    //   child: _kpiCard(
                    //     context,
                    //     'Last Season (kg)',
                    //     lastSeasonTotal,
                    //   ),
                    // ),
                  ],
                );
              },
            ),

            // Row(
            //   children: [
            //     Expanded(
            //       child: _kpiCard(
            //         context,
            //         'Last Disease',
            //         lastObs == null
            //             ? '—'
            //             : lastObs.toDate().toString().split(' ').first,
            //       ),
            //     ),
            //     const SizedBox(width: 8),
            //     Expanded(
            //       child: _kpiCard(
            //         context,
            //         'Last Season (kg)',
            //         lastSeasonKg == null ? '—' : '$lastSeasonKg',
            //       ),
            //     ),
            //   ],
            // ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.coronavirus, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disease flags: '
                        '${anth ? 'Anthracnose ' : ''}'
                        '${pm ? (anth ? '& Powdery Mildew' : 'Powdery Mildew') : (anth ? '' : 'None')}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addObservationSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Record'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.water_drop, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Irrigation: log a recent activity'),
                    ),
                    TextButton.icon(
                      onPressed: _addIrrigationSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Log'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.local_florist, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Yield: add latest season totals'),
                    ),
                    TextButton.icon(
                      onPressed: _addYieldSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _kpiCard(BuildContext context, String title, dynamic value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(String status, BuildContext context) {
    final c = _taskStatusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(
        status,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: c,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildTaskCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final ref = doc.reference;
    final t = doc.data();
    final title = (t['title'] ?? '') as String;
    final notes = (t['notes'] ?? '') as String;
    final isDone = (t['isDone'] ?? false) as bool;

    final dueTs = t['dueDate'] as Timestamp?;
    final dueStr = dueTs?.toDate().toLocal().toString().split(' ').first;

    final status = (t['status'] as String?) ?? (isDone ? 'Done' : 'Pending');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Checkbox(
            value: isDone,
            onChanged: (val) async {
              await ref.update({
                'isDone': val == true,
                'status': (val == true) ? 'Done' : 'Pending',
                'completedAt': (val == true)
                    ? FieldValue.serverTimestamp()
                    : FieldValue.delete(),
              });
            },
          ),
          title: Text(
            title,
            style: isDone
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  )
                : Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Due: ${dueStr ?? '—'}'),
              const SizedBox(height: 4),
              _statusPill(
                status,
                context,
              ), // 👈 colored status under the due date
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'to_pending') {
                await ref.update({'status': 'Pending', 'isDone': false});
              } else if (val == 'to_progress') {
                await ref.update({'status': 'In-Progress', 'isDone': false});
              } else if (val == 'to_done') {
                await ref.update({
                  'status': 'Done',
                  'isDone': true,
                  'completedAt': FieldValue.serverTimestamp(),
                });
              } else if (val == 'delete') {
                await ref.delete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'to_pending', child: Text('Mark Pending')),
              PopupMenuItem(
                value: 'to_progress',
                child: Text('Mark In-Progress'),
              ),
              PopupMenuItem(value: 'to_done', child: Text('Mark Done')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          children: [
            if (notes.trim().isEmpty)
              Text('No notes', style: Theme.of(context).textTheme.bodySmall)
            else
              Text(notes),
          ],
        ),
      ),
    );
  }

  Widget sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget taskTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final ref = doc.reference;
    final t = doc.data();
    final title = (t['title'] ?? '') as String;
    final notes = (t['notes'] ?? '') as String;
    final isDone = (t['isDone'] ?? false) as bool;

    final dueTs = t['dueDate'] as Timestamp?;
    final dueStr = dueTs?.toDate().toLocal().toString().split(' ').first;

    final status = (t['status'] as String?) ?? (isDone ? 'Done' : 'Pending');

    // Overdue = due date in the past AND not Done
    bool isOverdue = false;
    if (dueTs != null && status != 'Done') {
      final d = dueTs.toDate();
      final dd = DateTime(d.year, d.month, d.day);
      isOverdue = dd.isBefore(today);
    }

    Color statusColor() {
      switch (status) {
        case 'In-Progress':
          return Colors.orange;
        case 'Done':
          return Colors.green;
        default:
          return Theme.of(context).colorScheme.outline; // Pending = gray
      }
    }

    Widget statusPill() {
      final c = statusColor();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Text(
          status,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: c,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Checkbox(
            value: isDone,
            onChanged: (val) async {
              await ref.update({
                'isDone': val == true,
                'status': (val == true) ? 'Done' : 'Pending',
                'completedAt': (val == true)
                    ? FieldValue.serverTimestamp()
                    : FieldValue.delete(),
              });
            },
          ),
          title: Text(
            title,
            style: isDone
                ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  )
                : Theme.of(context).textTheme.bodyLarge,
          ),
          // Due date + status pill + overdue warning (red)
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Due: ${dueStr ?? '—'}',
                style: isOverdue
                    ? const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
              if (isOverdue) ...[
                const SizedBox(height: 2),
                Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.red,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Overdue',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              statusPill(),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (val) async {
              if (val == 'edit_notes') {
                await _editNotesDialog(ref, notes);
              } else if (val == 'to_pending') {
                await ref.update({'status': 'Pending', 'isDone': false});
              } else if (val == 'to_progress') {
                await ref.update({'status': 'In-Progress', 'isDone': false});
              } else if (val == 'to_done') {
                await ref.update({
                  'status': 'Done',
                  'isDone': true,
                  'completedAt': FieldValue.serverTimestamp(),
                });
              } else if (val == 'delete') {
                await ref.delete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit_notes', child: Text('Edit notes')),
              PopupMenuItem(value: 'to_pending', child: Text('Mark Pending')),
              PopupMenuItem(
                value: 'to_progress',
                child: Text('Mark In-Progress'),
              ),
              PopupMenuItem(value: 'to_done', child: Text('Mark Done')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          children: [
            if (notes.trim().isEmpty)
              Text('No notes', style: Theme.of(context).textTheme.bodySmall)
            else
              Text(notes),
          ],
        ),
      ),
    );
  }

  Widget _tasksChecklistTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: farmRef
                .collection('tasks')
                .orderBy('dueDate', descending: false)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}'));
              }
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Text('No tasks yet. Add one.'));
              }
              // ---- Group by due date ----
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);

              final past = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final current = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final upcoming = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
              final noDue = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              for (final d in docs) {
                final t = d.data();
                final dueTs = t['dueDate'] as Timestamp?;
                if (dueTs == null) {
                  noDue.add(d);
                  continue;
                }
                final dt = dueTs.toDate();
                final dueOnly = DateTime(dt.year, dt.month, dt.day);
                if (dueOnly.isBefore(today)) {
                  past.add(d);
                } else if (dueOnly.isAtSameMomentAs(today)) {
                  current.add(d);
                } else {
                  upcoming.add(d);
                }
              }
              // ---- Build grouped list ----
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (current.isNotEmpty) sectionHeader('Current (Today)'),
                  ...current.map(taskTile),

                  if (upcoming.isNotEmpty) sectionHeader('Upcoming'),
                  ...upcoming.map(taskTile),

                  if (past.isNotEmpty) sectionHeader('Past (Overdue)'),
                  ...past.map(taskTile),

                  if (noDue.isNotEmpty) sectionHeader('No Due Date'),
                  ...noDue.map(taskTile),

                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _addTaskSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add Task'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _recordsTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.water_drop_outlined,
                label: 'Irrigations',
                color: Colors.teal.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _listIrr()),
                ),
              ),
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.visibility_outlined,
                label: 'Observations',
                color: Colors.amber.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => _listObs()),
                ),
              ),
              const SizedBox(height: 12),
              _BigButton(
                icon: Icons.scale_outlined,
                label: 'Yields',
                color: Colors.green.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => YieldsHomePage(farmRef: farmRef),
                  ),
                ),
              ),

              // InkWell(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => _listIrr()),
              //     );
              //   },
              //   child: Container(
              //     padding: const EdgeInsets.all(20),
              //     margin: const EdgeInsets.only(bottom: 12),
              //     decoration: BoxDecoration(
              //       color: Colors.blue[100],
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: const Text(
              //       "Irrigations",
              //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              //     ),
              //   ),
              // ),
              // InkWell(
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => YieldsHomePage(farmRef: farmRef),
              //       ),
              //     );
              //   },
              //   child: Container(
              //     padding: const EdgeInsets.all(20),
              //     decoration: BoxDecoration(
              //       color: Colors.orange[100],
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: const Text(
              //       "Yields",
              //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              //     ),
              //   ),
              // ),
              // InkWell(
              //   onTap: () {
              //     // Navigate or show Observations
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(builder: (context) => _listObs()),
              //     );
              //   },
              //   child: Container(
              //     padding: const EdgeInsets.all(20),
              //     margin: const EdgeInsets.only(bottom: 12),
              //     decoration: BoxDecoration(
              //       color: Colors.green[100],
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     child: const Text(
              //       "Observations",
              //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _listObs() {
    Color _sevColor(String sev) {
      switch (sev.toLowerCase()) {
        case 'high':
          return Colors.red;
        case 'med':
          return Colors.orange;
        case 'low':
          return Colors.green;
        default:
          return Colors.grey;
      }
    }

    Widget _sevPill(String sev) {
      final c = _sevColor(sev);
      final label = sev.isEmpty ? '—' : sev.toUpperCase();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withOpacity(0.6)),
        ),
        child: Text(
          label,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
    }

    Widget _sectionHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    Widget _obsCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
      final d = doc.data();
      final type = (d['type'] ?? '')
          .toString(); // anthracnose | powdery_mildew | other
      final sev = (d['severity'] ?? '').toString(); // low | med | high
      final obsAt = (d['observedAt'] as Timestamp?)?.toDate();
      final notes = (d['notes'] ?? '').toString();
      final photoUrl = (d['photoUrl'] ?? '').toString();

      final dateStr = obsAt == null
          ? ''
          : obsAt.toLocal().toString().split(' ').first;

      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: const Icon(Icons.coronavirus),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr.isEmpty ? 'Observed' : 'Observed: $dateStr',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                _sevPill(sev),
              ],
            ),
            subtitle: Text(type.replaceAll('_', ' ').toUpperCase()),
            trailing: PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'edit') {
                  // quick inline notes editor
                  final ctrl = TextEditingController(text: notes);
                  bool saving = false;
                  await showDialog(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setLocal) => AlertDialog(
                        title: const Text('Edit notes'),
                        content: TextField(
                          controller: ctrl,
                          maxLines: 6,
                          decoration: const InputDecoration(
                            hintText: 'Write notes…',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    setLocal(() => saving = true);
                                    try {
                                      await doc.reference.update({
                                        'notes': ctrl.text.trim(),
                                      });
                                      if (context.mounted) Navigator.pop(ctx);
                                    } finally {
                                      setLocal(() => saving = false);
                                    }
                                  },
                            child: saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (val == 'delete') {
                  await doc.reference.delete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit notes')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: notes.trim().isEmpty
                      ? Text(
                          'No notes',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Text(notes),
                ),
              ),
              if (photoUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrl,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Observations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: farmRef
            .collection('observations')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No observations yet.'));
          }

          // Group by type
          final anth = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final pm = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final other = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          for (final doc in docs) {
            final t = (doc.data()['type'] ?? '').toString();
            if (t == 'anthracnose') {
              anth.add(doc);
            } else if (t == 'powdery_mildew') {
              pm.add(doc);
            } else {
              other.add(doc);
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ANTHRACNOSE
              _sectionHeader('ANTHRACNOSE'),
              if (anth.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    'No records',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                ...anth.map(_obsCard),

              const SizedBox(height: 8),

              // POWDERY MILDEW
              _sectionHeader('POWDERY MILDEW'),
              if (pm.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    'No records',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                ...pm.map(_obsCard),

              if (other.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('OTHER'),
                ...other.map(_obsCard),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addObservationSheet,
        icon: const Icon(Icons.coronavirus),
        label: const Text('Add Observation'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _listIrr() {
    return Scaffold(
      appBar: AppBar(title: const Text('Irrigations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: farmRef
            .collection('irrigations')
            .orderBy('date', descending: true)
            .orderBy('createdAt', descending: true) // tie-breaker
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Scaffold(
              body: Center(child: Text('No irrigation logs yet.')),
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _addIrrigationSheet,
                icon: const Icon(Icons.water_drop),
                label: const Text('Add Irrigation'),
              ),
            );
          }

          // Group by YYYY-MM
          final groups =
              <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

          for (final d in docs) {
            final ts = d.data()['date'] as Timestamp?;
            final dt = (ts?.toDate()) ?? DateTime.now();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            groups.putIfAbsent(key, () => []).add(d);
          }

          String labelOf(String ym) {
            final p = ym.split('-');
            final y = p[0];
            final m = int.parse(p[1]);
            const months = [
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
            return '${months[m - 1]} $y';
          }

          return Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: groups.entries.map((entry) {
                final label = labelOf(entry.key);
                final items = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...items.map((doc) {
                      final m = doc.data();
                      final date = (m['date'] as Timestamp?)?.toDate();
                      final method = (m['method'] ?? '').toString();
                      final duration = (m['durationMin'] ?? 0) as int;
                      final liters = (m['waterLiters'] ?? 0) as int;
                      final zone = (m['zone'] ?? '').toString();
                      final notes = (m['notes'] ?? '').toString();

                      final dateStr = date == null
                          ? '—'
                          : DateTime(
                              date.year,
                              date.month,
                              date.day,
                            ).toLocal().toString().split(' ').first;

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: const Icon(Icons.water_drop),
                          title: Text(
                            '$dateStr • ${method.toUpperCase()}${zone.isEmpty ? '' : ' • $zone'}',
                          ),
                          subtitle: Text(
                            'Duration: ${duration}m • Water: ${liters} L',
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (val) async {
                              if (val == 'edit') {
                                await _editIrrigationSheet(doc);
                              } else if (val == 'delete') {
                                await _deleteIrrigation(doc);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                          children: [
                            if (notes.trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Text(
                                  'No notes',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  12,
                                ),
                                child: Text(notes),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: _addIrrigationSheet,
              icon: const Icon(Icons.water_drop),
              label: const Text('Add Irrigation'),
            ),
          );
        },
      ),
    );
  }

  // ===== Widgets ======

  // Main Section
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: farmRef.snapshots(),
          builder: (context, snap) {
            final name =
                (snap.data?.data() ?? const {})['name'] ?? 'Farm Details';
            return Text(name);
          },
        ),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tasks'),
            Tab(text: 'Records'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [_overviewTab(), _tasksChecklistTab(), _recordsTab()],
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
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
