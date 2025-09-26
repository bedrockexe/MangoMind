import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ObservationsPage extends StatelessWidget {
  const ObservationsPage({super.key, required this.farmRef});

  final DocumentReference<Map<String, dynamic>> farmRef;

  Future<void> _addObservationSheet(BuildContext context) async {
    String type = 'anthracnose';
    String severity = 'low';
    final notes = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool saving = false; // local state for this sheet

        return StatefulBuilder(
          builder: (context, setLocal) => Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: AbsorbPointer(
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

                                // 2) optional farm summary updates
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

                                if (ctx.mounted) Navigator.pop(ctx);
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

  // ────────────────────────────────────────────────────────────────────────────
  // UI helpers
  // ────────────────────────────────────────────────────────────────────────────
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

  Widget _obsCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();
    final type = (d['type'] ?? '').toString();
    final sev = (d['severity'] ?? '').toString();
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
                                    if (ctx.mounted) Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
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
                ...anth.map((d) => _obsCard(context, d)),

              const SizedBox(height: 8),

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
                ...pm.map((d) => _obsCard(context, d)),

              if (other.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('OTHER'),
                ...other.map((d) => _obsCard(context, d)),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addObservationSheet(context),
        icon: const Icon(Icons.coronavirus),
        label: const Text('Add Observation'),
      ),
    );
  }
}
