import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Initialize Class
class FarmDetailsPage extends StatefulWidget {
  final String farmId;
  const FarmDetailsPage({super.key, required this.farmId});

  @override
  State<FarmDetailsPage> createState() => _FarmDetailsPageState();
}

class _FarmDetailsPageState extends State<FarmDetailsPage>
    with SingleTickerProviderStateMixin {
  late final DocumentReference<Map<String, dynamic>> farmRef;
  late final TabController _tab;
  int? _openTasks;

  // Initialization
  @override
  void initState() {
    super.initState();
    farmRef = FirebaseFirestore.instance.collection('farms').doc(widget.farmId);
    _tab = TabController(length: 3, vsync: this);
    _loadOpenTasksCount();
  }

  // task Counter
  Future<void> _loadOpenTasksCount() async {
    try {
      final snap = await farmRef
          .collection('tasks')
          .where('status', isNotEqualTo: 'Done')
          .count()
          .get();
      setState(() => _openTasks = (snap.count ?? 0)); // snap.count is int?
    } catch (_) {
      setState(() => _openTasks = 0);
    }
  }

  void _refreshOpenTasks() => _loadOpenTasksCount();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ---------- Helpers: add sheets ----------

  // Task Section Additionals
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
                                'status': 'Pending', // keep for compatibility
                                'dueDate': due == null
                                    ? null
                                    : Timestamp.fromDate(due!),
                                'createdAt': FieldValue.serverTimestamp(),
                              });
                              _refreshOpenTasks();
                              if (mounted) {
                                final state = this;
                                // ignore: invalid_use_of_protected_member
                                if (state is dynamic &&
                                    (state as dynamic)._refreshOpenTasks !=
                                        null) {
                                  // safely try to call
                                  try {
                                    (state as dynamic)._refreshOpenTasks();
                                  } catch (_) {}
                                }
                              }
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
  // Task Section Additionals

  // Overview Section Additionals
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

  Widget _statusPillSmall(String status, BuildContext context) {
    final c = _statusColorSmall(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withOpacity(0.6)),
      ),
      child: Text(
        status,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }

  // Overview Section Additionals

  Future<void> _addObservationSheet() async {
    String type = 'anthracnose';
    String severity = 'low';
    final notes = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Record Disease Observation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
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
            DropdownButtonFormField<String>(
              initialValue: severity,
              decoration: const InputDecoration(labelText: 'Severity'),
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'med', child: Text('Medium')),
                DropdownMenuItem(value: 'high', child: Text('High')),
              ],
              onChanged: (v) => severity = v ?? 'low',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  await farmRef.collection('observations').add({
                    'type': type,
                    'severity': severity,
                    'observedAt': FieldValue.serverTimestamp(),
                    'notes': notes.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  // Update summary flags on farm doc
                  await farmRef
                      .update({
                        'diseasePest.lastObserved':
                            FieldValue.serverTimestamp(),
                        'diseasePest.anthracnose': type == 'anthracnose'
                            ? true
                            : FieldValue.delete(),
                        'diseasePest.powderyMildew': type == 'powdery_mildew'
                            ? true
                            : FieldValue.delete(),
                      })
                      .catchError(
                        (_) {},
                      ); // ignore if field path doesn’t exist yet
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Observation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addIrrigationSheet() async {
    final duration = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Log Irrigation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(
                'Date: ${date.toLocal().toString().split(' ').first}',
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(date.year - 5),
                  lastDate: DateTime(date.year + 5),
                );
                if (picked != null) {
                  setState(() => date = picked);
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
              ),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final dur = int.tryParse(duration.text.trim());
                  await farmRef.collection('irrigations').add({
                    'date': Timestamp.fromDate(date),
                    'durationMin': dur,
                    'notes': notes.text.trim(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Irrigation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addYieldSheet() async {
    final season = TextEditingController();
    final totalKg = TextEditingController();
    final avgKgTree = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Yield Entry',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: season,
              decoration: const InputDecoration(
                labelText: 'Season (e.g., 2025 Wet)',
              ),
            ),
            TextField(
              controller: totalKg,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total (kg)'),
            ),
            TextField(
              controller: avgKgTree,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Avg kg per tree (optional)',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final total = num.tryParse(totalKg.text.trim());
                  final avg = num.tryParse(avgKgTree.text.trim());
                  await farmRef.collection('yields').add({
                    'season': season.text.trim().isEmpty
                        ? null
                        : season.text.trim(),
                    'totalKg': total,
                    'avgKgPerTree': avg,
                    'recordedAt': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  // Update summary in farm doc
                  await farmRef
                      .update({
                        'yield.lastSeasonKg': total,
                        'yield.avgKgPerTree': avg,
                      })
                      .catchError((_) {});
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Yield'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Widgets ----------

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
                    }).toList(),
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
        final lastSeasonKg = (data['yield'] ?? {})['lastSeasonKg'];
        final dp = Map<String, dynamic>.from(data['diseasePest'] ?? {});
        final lastObs = dp['lastObserved'] as Timestamp?;
        final anth = dp['anthracnose'] == true;
        final pm = dp['powderyMildew'] == true;

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
            // KPIs
            // 🔹 Open Tasks preview (clickable → goes to Tasks tab)
            _openTasksPreviewCard(),
            const SizedBox(height: 12),

            // Keep the other KPIs
            Row(
              children: [
                Expanded(
                  child: _kpiCard(
                    context,
                    'Last Disease',
                    lastObs == null
                        ? '—'
                        : lastObs.toDate().toString().split(' ').first,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _kpiCard(
                    context,
                    'Last Season (kg)',
                    lastSeasonKg == null ? '—' : '$lastSeasonKg',
                  ),
                ),
              ],
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

  // Task Section Widgets
  Widget _statusPill(String status, BuildContext context) {
    final c = _taskStatusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withOpacity(0.6)),
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
    final dueStr = dueTs == null
        ? null
        : dueTs.toDate().toLocal().toString().split(' ').first;

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
              if (mounted) _refreshOpenTasks();
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
                if (mounted) _refreshOpenTasks();
              } else if (val == 'delete') {
                await ref.delete();
                if (mounted) _refreshOpenTasks();
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
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withOpacity(0.6)),
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
              if (mounted) _refreshOpenTasks();
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
                if (mounted) _refreshOpenTasks();
              } else if (val == 'to_progress') {
                await ref.update({'status': 'In-Progress', 'isDone': false});
              } else if (val == 'to_done') {
                await ref.update({
                  'status': 'Done',
                  'isDone': true,
                  'completedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) _refreshOpenTasks();
              } else if (val == 'delete') {
                await ref.delete();
                if (mounted) _refreshOpenTasks();
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
  // Task Section Widgets

  // Task Checklist Section
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

              // return ListView.separated(
              //   padding: const EdgeInsets.all(16),
              //   separatorBuilder: (_, __) => const SizedBox(height: 8),
              //   itemCount: docs.length,
              //   itemBuilder: (_, i) {
              //     final ref = docs[i].reference;
              //     final t = docs[i].data();
              //     final title = (t['title'] ?? '') as String;
              //     final notes = (t['notes'] ?? '') as String;
              //     final isDone = (t['isDone'] ?? false) as bool;
              //     final dueTs = t['dueDate'] as Timestamp?;
              //     final dueStr = dueTs == null
              //         ? null
              //         : dueTs.toDate().toLocal().toString().split(' ').first;
              //     final status =
              //         (t['status'] as String?) ??
              //         ((isDone == true) ? 'Done' : 'Pending');
              //     return Card(
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //       child: Theme(
              //         // make expansion tile denser
              //         data: Theme.of(
              //           context,
              //         ).copyWith(dividerColor: Colors.transparent),
              //         child: ExpansionTile(
              //           tilePadding: const EdgeInsets.only(left: 8, right: 8),
              //           childrenPadding: const EdgeInsets.fromLTRB(
              //             16,
              //             0,
              //             16,
              //             12,
              //           ),
              //           leading: Checkbox(
              //             value: isDone,
              //             onChanged: (val) async {
              //               await ref.update({
              //                 'isDone': val == true,
              //                 'status': (val == true) ? 'Done' : 'Pending',
              //                 'completedAt': (val == true)
              //                     ? FieldValue.serverTimestamp()
              //                     : FieldValue.delete(),
              //               });
              //               // refresh KPI if you use manual refresh method
              //               if (mounted) {
              //                 _refreshOpenTasks();
              //               }
              //             },
              //           ),
              //           title: Text(
              //             title,
              //             style: isDone
              //                 ? Theme.of(context).textTheme.bodyLarge?.copyWith(
              //                     decoration: TextDecoration.lineThrough,
              //                     color: Colors.grey,
              //                   )
              //                 : Theme.of(context).textTheme.bodyLarge,
              //           ),
              //           // subtitle: dueStr == null ? null : Text('Due: $dueStr'),
              //           subtitle: Column(
              //             crossAxisAlignment: CrossAxisAlignment.start,
              //             children: [
              //               if (dueStr != null) Text('Due: $dueStr'),
              //               const SizedBox(height: 4),
              //               _statusPill(status, context),
              //             ],
              //           ),
              //           trailing: PopupMenuButton<String>(
              //             onSelected: (val) async {
              //               if (val == 'edit_notes') {
              //                 await _editNotesDialog(ref, notes);
              //               } else if (val == 'delete') {
              //                 await ref.delete();
              //                 if (mounted) {
              //                   _refreshOpenTasks();
              //                 }
              //               }
              //             },
              //             itemBuilder: (_) => const [
              //               PopupMenuItem(
              //                 value: 'edit_notes',
              //                 child: Text('Edit notes'),
              //               ),
              //               PopupMenuItem(
              //                 value: 'delete',
              //                 child: Text('Delete'),
              //               ),
              //             ],
              //           ),
              //           children: [
              //             if (notes.trim().isEmpty)
              //               Text(
              //                 'No notes',
              //                 style: Theme.of(context).textTheme.bodySmall,
              //               )
              //             else
              //               Text(notes),
              //           ],
              //         ),
              //       ),
              //     );
              //   },
              // );

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

  // Records Section
  Widget _recordsTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Observations'),
              Tab(text: 'Irrigations'),
              Tab(text: 'Yields'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_listObs(), _listIrr(), _listYield()]),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addObservationSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Observation'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _addIrrigationSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Irrigation'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addYieldSheet,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Yield'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // List Observation Records
  Widget _listObs() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final type = (d['type'] ?? '').toString().replaceAll('_', ' ');
            final sev = d['severity'] ?? '';
            final obsAt = (d['observedAt'] as Timestamp?)?.toDate();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.coronavirus),
                title: Text(
                  '${type.toString().toUpperCase()} (${sev.toString().toUpperCase()})',
                ),
                subtitle: Text(
                  obsAt == null
                      ? ''
                      : 'Observed: ${obsAt.toLocal().toString().split(' ').first}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  // List Irrigation Records
  Widget _listIrr() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: farmRef
          .collection('irrigations')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No irrigation logs yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final date = (d['date'] as Timestamp?)?.toDate();
            final dur = d['durationMin'];
            final notes = d['notes'];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.water_drop),
                title: Text(
                  date == null
                      ? '—'
                      : date.toLocal().toString().split(' ').first,
                ),
                subtitle: Text(
                  'Duration: ${dur ?? '—'} min\n${(notes ?? '').toString()}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  // List Yield Records
  Widget _listYield() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: farmRef
          .collection('yields')
          .orderBy('recordedAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No yield records yet.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final season = d['season'] ?? '—';
            final total = d['totalKg'] ?? '—';
            final avg = d['avgKgPerTree'];
            final recAt = (d['recordedAt'] as Timestamp?)?.toDate();
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_florist),
                title: Text('$season • $total kg'),
                subtitle: Text(
                  'Avg kg/tree: ${avg ?? '—'}\n'
                  'Recorded: ${recAt == null ? '—' : recAt.toLocal().toString().split(' ').first}',
                ),
              ),
            );
          },
        );
      },
    );
  }

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
