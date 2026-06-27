import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_training.dart';
import 'trainingdetails.dart';
import 'edittraining.dart';
import 'package:intl/intl.dart';

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
                                    (ud['first_name'] ?? '') +
                                    ' ' +
                                    (ud['last_name'] ?? '');
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

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 12,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrainingDetailsPage(trainingId: doc.id),
            ),
          );
        },
        leading: thumbnail != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumbnail,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              )
            : Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school),
              ),
        // Title row: title (limited lines) + status badge
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 2, // <-- limit lines so it doesn't wrap into a column
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'Ended'
                    ? Colors.red.shade100
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: status == 'Ended'
                      ? Colors.red.shade700
                      : Colors.green.shade800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        // Subtitle - minimal main axis size so it doesn't force extra height
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  formattedDate(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            if (venue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Venue: $venue',
                  maxLines: 2, // allow two lines for longer venue text
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(label: Text(category)),
                Chip(label: Text(level)),
                if (published)
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.public, size: 14),
                        SizedBox(width: 4),
                        Text('Published'),
                      ],
                    ),
                  )
                else
                  const Chip(label: Text('Draft')),
              ],
            ),
          ],
        ),
        isThreeLine: false,
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditTrainingPage(trainingId: doc.id),
                ),
              );
            } else if (v == 'delete') {
              await _confirmAndDelete(doc.id);
            } else if (v == 'enroll') {
              await _showEnrollments(doc.id);
            } else if (v == 'open') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainingDetailsPage(trainingId: doc.id),
                ),
              );
            }
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'open', child: Text('Open details')),
            const PopupMenuItem(value: 'edit', child: Text('Edit training')),
            const PopupMenuItem(
              value: 'enroll',
              child: Text('View enrollments'),
            ),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
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
      appBar: AppBar(
        title: const Text('Admin — Trainings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Training',
            onPressed: () {
              // Navigate to create page (instead of showing form inline)
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTrainingPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // filters + search
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: 'Search trainings',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _filterCategory,
                        items: categories
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _filterCategory = v ?? 'All'),
                      ),
                      const SizedBox(width: 8),
                      Checkbox(
                        value: _onlyPublished,
                        onChanged: (v) =>
                            setState(() => _onlyPublished = v ?? false),
                      ),
                      const Text('Published'),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: trainingsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('No trainings available. Click + to add.'),
                    );
                  } else {
                    final filtered = docs.where((d) {
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
                      return const Center(
                        child: Text('No trainings match your filters.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) =>
                          _buildTrainingCard(filtered[i]),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
