// Flutter Material
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TasksPage extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> farmRef;
  const TasksPage({super.key, required this.farmRef});

  @override
  State<TasksPage> createState() => _TasksPage();
}

class _TasksPage extends State<TasksPage> {
  DocumentReference<Map<String, dynamic>> get farmRef => widget.farmRef;

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
    final formKey = GlobalKey<FormState>();
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime? due;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add Task',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      prefixIcon: Icon(Icons.assignment),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return '*Task title is empty';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                    ),
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
                              if (!formKey.currentState!.validate()) return;
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
                      label: Text(saving ? 'Saving...' : 'Save Task'),
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

  @override
  Widget build(BuildContext context) {
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
}
