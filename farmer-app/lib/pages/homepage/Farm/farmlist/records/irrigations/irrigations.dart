import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/skeletons.dart';

class IrrigationsPage extends StatefulWidget {
  const IrrigationsPage({super.key, required this.farmRef});

  final DocumentReference<Map<String, dynamic>> farmRef;

  @override
  State<IrrigationsPage> createState() => _IrrigationsPageState();
}

class _IrrigationsPageState extends State<IrrigationsPage> {
  DocumentReference<Map<String, dynamic>> get farmRef => widget.farmRef;

  // ───────────────────────────────────────────
  // YOUR FUNCTIONS (wired to this page)
  // ───────────────────────────────────────────

  Future<void> _saveIrrigation({
    required DateTime date,
    required String method,
    required int durationMin,
    required int waterLiters,
    String zone = '',
    String notes = '',
  }) async {
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

    // Recompute latest irrigated date
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

    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.delete(doc.reference);
      tx.update(farmRef, {
        'irrigation.seasonWaterLiters': FieldValue.increment(-liters),
      });
    });

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
    DocumentSnapshot<Map<String, dynamic>>? editingDoc,
  }) async {
    final m = editingDoc?.data();

    DateTime date = (() {
      final ts = m?['date'];
      if (ts is Timestamp) return ts.toDate();
      return DateTime.now();
    })();

    String method = (m?['method'] as String?) ?? 'drip';

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

                // Date
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

                // Method
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

                // Duration
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Duration (minutes)',
                    hintText: 'e.g. 45',
                  ),
                ),
                const SizedBox(height: 8),

                // Liters
                TextField(
                  controller: litersCtrl,
                  keyboardType: TextInputType.number,
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

                // Save button
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

  // ───────────────────────────────────────────
  // UI (list + grouping + actions)
  // ───────────────────────────────────────────

  String _monthLabel(String ym) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Irrigations')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: farmRef
            .collection('irrigations')
            .orderBy('date', descending: true)
            .orderBy('createdAt', descending: true) // tie-breaker
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const EmptyState(
              icon: Icons.water_drop_outlined,
              title: 'No irrigation logs yet',
              message: 'Tap “Add Irrigation” to record a watering activity.',
            );
          }

          // Group by YYYY-MM
          final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
          groups = {};
          for (final d in docs) {
            final ts = d.data()['date'] as Timestamp?;
            final dt = (ts?.toDate()) ?? DateTime.now();
            final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
            groups.putIfAbsent(key, () => []).add(d);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: groups.entries.map((entry) {
              final label = _monthLabel(entry.key);
              final items = entry.value;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 2),
                    child: SectionHeader(label),
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
                          '$dateStr • ${method.toUpperCase()}'
                          '${zone.isEmpty ? '' : ' • $zone'}',
                        ),
                        subtitle: Text(
                          'Duration: ${duration}m • Water: ${liters} L',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'edit') {
                              await _showIrrigationSheet(editingDoc: doc);
                            } else if (val == 'delete') {
                              // Optional confirm
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete irrigation'),
                                  content: const Text(
                                    'This action cannot be undone.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await _deleteIrrigation(doc);
                              }
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
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: notes.trim().isEmpty
                                ? Text(
                                    'No notes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  )
                                : Text(notes),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showIrrigationSheet(),
        icon: const Icon(Icons.water_drop),
        label: const Text('Add Irrigation'),
      ),
    );
  }
}
