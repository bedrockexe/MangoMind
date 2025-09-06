import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    farmRef = FirebaseFirestore.instance.collection('farms').doc(widget.farmId);
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // Add Task Function
  Future<void> _addTaskSheet() async {
    final title = TextEditingController();
    final desc = TextEditingController();
    DateTime? due;
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
            Text('Add Task', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Description'),
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
                        initialDate: now,
                        firstDate: DateTime(now.year - 5),
                        lastDate: DateTime(now.year + 5),
                      );
                      if (picked != null) {
                        setState(() => due = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  await farmRef.collection('tasks').add({
                    'title': title.text.trim(),
                    'description': desc.text.trim(),
                    'status': 'Pending',
                    'dueDate': due == null ? null : Timestamp.fromDate(due!),
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save Task'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add Observation Function
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

  // Add Irrigation Function
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

  // Add Yield Function
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

  // Farm Overview
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
            Row(
              children: [
                Expanded(
                  child: _kpiCard(context, 'Open Tasks', _openTasksCount()),
                ),
                const SizedBox(width: 8),
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

  // Asynchronously count open tasks for KPI
  Future<int> _fetchOpenTasksCount() async {
    final snap = await farmRef
        .collection('tasks')
        .where('status', isNotEqualTo: 'Done')
        .count()
        .get();

    return snap.count ?? 0; // 👈 fallback to 0 if null
  }

  Widget _openTasksCount() {
    return FutureBuilder<int>(
      future: _fetchOpenTasksCount(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Text('…'); // loading placeholder
        }
        if (snap.hasError) {
          return const Text('0'); // fallback on error
        }
        final count = snap.data ?? 0;
        return Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        );
      },
    );
  }

  Widget _tasksTab() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: farmRef
                .collection('tasks')
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
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final t = d.data();
                  final status = (t['status'] ?? 'Pending') as String;
                  return Card(
                    child: ListTile(
                      title: Text(t['title'] ?? ''),
                      subtitle: Text(t['description'] ?? ''),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) async {
                          if (val == 'done') {
                            await d.reference.update({'status': 'Done'});
                          } else if (val == 'progress') {
                            await d.reference.update({'status': 'In-Progress'});
                          } else if (val == 'delete') {
                            await d.reference.delete();
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'progress',
                            child: Text('Mark In-Progress'),
                          ),
                          const PopupMenuItem(
                            value: 'done',
                            child: Text('Mark Done'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      leading: _statusChip(status),
                    ),
                  );
                },
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

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'Done':
        color = Colors.green;
        break;
      case 'In-Progress':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    return CircleAvatar(radius: 8, backgroundColor: color);
  }

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

  // ---------- Build ----------

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
        children: [_overviewTab(), _tasksTab(), _recordsTab()],
      ),
    );
  }
}
