import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_training.dart';
import 'trainingdetails.dart';
import 'edittraining.dart';
import 'package:intl/intl.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';

class AdminTrainingsPage extends StatefulWidget {
  const AdminTrainingsPage({super.key});

  @override
  State<AdminTrainingsPage> createState() => _AdminTrainingsPageState();
}

class _AdminTrainingsPageState extends State<AdminTrainingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterCategory = 'All';
  bool _onlyPublished = false;

  final List<String> categories = [
    'All',
    'Pest Control',
    'Irrigation',
    'Fertilization',
    'Harvesting',
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () =>
          setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Compute status: upcoming or ended.
  String computeStatus(Timestamp? scheduledAt) {
    if (scheduledAt == null) return 'Upcoming';
    final DateTime scheduled = scheduledAt.toDate();
    final DateTime endedThreshold = scheduled.add(
      const Duration(days: 1),
    ); // ended after 1 day
    if (DateTime.now().isAfter(endedThreshold)) return 'Ended';
    return 'Upcoming';
  }

  Future<void> _confirmAndDelete(String trainingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete training?'),
        content: const Text(
          'This will delete the training and its enrollments & materials. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _deleteTrainingCascade(trainingId);
  }

  // Deletes training doc and its materials/enrollments (best-effort).
  Future<void> _deleteTrainingCascade(String trainingId) async {
    final trainingsRef = _firestore.collection('trainings').doc(trainingId);
    final batch = _firestore.batch();

    try {
      // Delete training doc
      batch.delete(trainingsRef);

      // Delete enrollments with a batch (read -> delete)
      final enrollSnap = await _firestore
          .collection('enrollments')
          .where('trainingId', isEqualTo: trainingId)
          .get();
      for (final d in enrollSnap.docs) {
        batch.delete(d.reference);
      }

      // Delete materials
      final matSnap = await _firestore
          .collection('materials')
          .where('trainingId', isEqualTo: trainingId)
          .get();
      for (final d in matSnap.docs) {
        batch.delete(d.reference);
      }

      // Commit batch (note: batch size limit ~500 operations)
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Training deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _showEnrollments(String trainingId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Enrolled users',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('enrollments')
                        .where('trainingId', isEqualTo: trainingId)
                        .where('status', whereIn: ['registered', 'attended'])
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(child: Text('Error: ${snap.error}'));
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final enrollDocs = snap.data!.docs;
                      if (enrollDocs.isEmpty) {
                        return const Center(
                          child: Text('No enrolled users yet.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: enrollDocs.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, i) {
                          final data =
                              enrollDocs[i].data() as Map<String, dynamic>;
                          final farmerId = data['farmerId'] as String?;
                          final status = data['status'] ?? 'registered';
                          return FutureBuilder<DocumentSnapshot>(
                            future: farmerId != null
                                ? _firestore
                                      .collection('users')
                                      .doc(farmerId)
                                      .get()
                                // ignore: null_argument_to_non_null_type
                                : Future.value(null),
                            builder: (ctx2, userSnap) {
                              String name = farmerId ?? 'Unknown';
                              String sub = 'ID: ${enrollDocs[i].id} • $status';
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final ud =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>;
                                name =
                                    '${ud['first_name'] ?? ''} '
                                    '${ud['last_name'] ?? ''}';
                                sub = ud['phone'] ?? '';
                              }
                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                title: Text(name),
                                subtitle: Text(sub),
                                trailing: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'attended'
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                ),
                              );
                            },
                          );
                        },
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

  Widget _buildTrainingCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final category = data['category'] ?? 'Uncategorized';
    final level = data['level'] ?? 'Beginner';
    final published = data['published'] ?? false;
    final ts = data['scheduledAt'] as Timestamp?;
    final scheduledAt = ts?.toDate();
    final status = computeStatus(ts);
    final venue = data['venue'] ?? '';
    final thumbnail = data['thumbnailUrl'] as String?;

    String formattedDate() {
      if (scheduledAt == null) return '';
      return DateFormat.yMMMd().add_jm().format(scheduledAt.toLocal());
    }

    final scheme = Theme.of(context).colorScheme;
    final ended = status == 'Ended';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          appRoute(TrainingDetailsPage(trainingId: doc.id)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: thumbnail != null
                      ? Image.network(
                          thumbnail,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _thumbFallback(scheme),
                        )
                      : _thumbFallback(scheme),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.2,
                        ),
                      ),
                      if (scheduledAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.event,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                formattedDate(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (venue.toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      Navigator.push(
                        context,
                        appRoute(EditTrainingPage(trainingId: doc.id)),
                      );
                    } else if (v == 'delete') {
                      await _confirmAndDelete(doc.id);
                    } else if (v == 'enroll') {
                      await _showEnrollments(doc.id);
                    } else if (v == 'open') {
                      Navigator.push(
                        context,
                        appRoute(TrainingDetailsPage(trainingId: doc.id)),
                      );
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'open', child: Text('Open details')),
                    PopupMenuItem(value: 'edit', child: Text('Edit training')),
                    PopupMenuItem(
                      value: 'enroll',
                      child: Text('View enrollments'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space1,
              children: [
                AppStatusChip(
                  status,
                  tone: ended ? StatusTone.danger : StatusTone.success,
                  icon: ended ? Icons.history : Icons.schedule,
                ),
                AppStatusChip(category, tone: StatusTone.info),
                AppStatusChip(level, tone: StatusTone.neutral),
                AppStatusChip(
                  published ? 'Published' : 'Draft',
                  tone: published ? StatusTone.success : StatusTone.warning,
                  icon: published ? Icons.public : Icons.edit_note,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback(ColorScheme scheme) {
    return Container(
      width: 64,
      height: 64,
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.school, color: scheme.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Base query: all trainings ordered by scheduledAt desc
    Stream<QuerySnapshot> trainingsStream = _firestore
        .collection('trainings')
        .orderBy('scheduledAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Trainings')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          appRoute(const CreateTrainingPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New training'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space2,
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search trainings',
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space4,
                ),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: AppTheme.space2),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _filterCategory == c,
                        onSelected: (_) =>
                            setState(() => _filterCategory = c),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: AppTheme.space2),
                    child: FilterChip(
                      label: const Text('Published'),
                      selected: _onlyPublished,
                      onSelected: (v) => setState(() => _onlyPublished = v),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.space2),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: trainingsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      icon: Icons.cloud_off,
                      title: 'Could not load trainings',
                      message: '${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const TrainingListSkeleton();
                  }

                  final filtered = snapshot.data!.docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final category = (data['category'] ?? '').toString();
                    final published = data['published'] ?? false;

                    if (_onlyPublished && !published) return false;
                    if (_filterCategory != 'All' &&
                        _filterCategory != category) {
                      return false;
                    }
                    if (_searchQuery.isNotEmpty &&
                        !title.contains(_searchQuery)) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    final filtering = _searchQuery.isNotEmpty ||
                        _onlyPublished ||
                        _filterCategory != 'All';
                    return EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: filtering
                          ? 'No matching trainings'
                          : 'No trainings yet',
                      message: filtering
                          ? 'Adjust your search or filters.'
                          : 'Tap “New training” to create your first one.',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.space4,
                      AppTheme.space2,
                      AppTheme.space4,
                      96,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) =>
                        _buildTrainingCard(filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
