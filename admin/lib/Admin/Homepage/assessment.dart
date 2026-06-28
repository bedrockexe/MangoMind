import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAssessmentsPage extends StatefulWidget {
  const AdminAssessmentsPage({super.key});

  @override
  State<AdminAssessmentsPage> createState() => _AdminAssessmentsPageState();
}

class _AdminAssessmentsPageState extends State<AdminAssessmentsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _classificationFilter =
      'All'; // All, Excellent, Good, Needs Improvement
  bool _onlyMyFarmers =
      false; // optional: toggle to show only current admin's assessments

  // For UI
  final DateFormat _df = DateFormat.yMMMd().add_jm();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _colorForClassification(String c) {
    switch (c.toLowerCase()) {
      case 'excellent':
        return Colors.green.shade600;
      case 'good':
        return Colors.orange.shade700;
      case 'low':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // parse timestamp (ISO string) -> DateTime safely
  DateTime _parseTimestamp(dynamic ts) {
    if (ts == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (ts is Timestamp)
      return ts.toDate(); // in case stored as Firestore Timestamp
    try {
      return DateTime.parse(ts.toString()).toLocal();
    } catch (_) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(
          int.parse(ts.toString()),
        ).toLocal();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
  }

  // Filtering logic on client side
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final q = _searchQuery.trim().toLowerCase();
    return docs.where((d) {
      final data = d.data();
      final farmerName = (data['farmerName'] ?? '').toString().toLowerCase();
      final classification = (data['classification'] ?? '').toString();
      // search
      if (q.isNotEmpty && !farmerName.contains(q)) return false;
      // classification filter
      if (_classificationFilter != 'All' &&
          classification.toLowerCase() != _classificationFilter.toLowerCase())
        return false;
      // optional: only show current user's assessments
      if (_onlyMyFarmers) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid == null || data['farmerId'] != currentUid) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _deleteAssessment(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete assessment'),
        content: const Text(
          'Are you sure you want to delete this assessment? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('assessments')
          .doc(docId)
          .delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Assessment deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final assessmentsRef = FirebaseFirestore.instance
        .collection('assessments')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
          toFirestore: (data, _) => data,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessments — Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
            onPressed: () {
              // open bottom sheet with filters
              showModalBottomSheet(
                context: context,
                builder: (ctx) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Filter assessments',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Classification:'),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _classificationFilter,
                                items:
                                    [
                                          'All',
                                          'Excellent',
                                          'Good',
                                          'Needs Improvement',
                                        ]
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e,
                                            child: Text(e),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => setState(() {
                                  _classificationFilter = v ?? 'All';
                                  Navigator.pop(ctx);
                                }),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Checkbox(
                              value: _onlyMyFarmers,
                              onChanged: (v) => setState(() {
                                _onlyMyFarmers = v ?? false;
                                Navigator.pop(ctx);
                              }),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Show only my farmers (current admin)',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _classificationFilter = 'All';
                              _onlyMyFarmers = false;
                              Navigator.pop(ctx);
                            }),
                            child: const Text('Reset filters'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + quick filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search farmer name...',
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                ),
                const SizedBox(width: 8),
                // quick classification dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: _classificationFilter,
                    underline: const SizedBox.shrink(),
                    items: ['All', 'Excellent', 'Good', 'Needs Improvement']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _classificationFilter = v ?? 'All'),
                  ),
                ),
              ],
            ),
          ),

          // Stream from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: assessmentsRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // raw docs
                final docs = snapshot.data?.docs ?? [];

                // apply client-side filters & search
                final filtered = _applyFilters(docs);

                // sort by timestamp desc
                filtered.sort((a, b) {
                  final ta = _parseTimestamp(a.data()['timestamp']);
                  final tb = _parseTimestamp(b.data()['timestamp']);
                  return tb.compareTo(ta);
                });

                if (filtered.isEmpty) {
                  return const Center(child: Text('No assessments found.'));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Firestore stream auto updates, but this gives manual refresh UX
                    await FirebaseFirestore.instance
                        .collection('assessments')
                        .get();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = filtered[index];
                      final data = doc.data();
                      final assessmentId = data['assessmentId'] ?? doc.id;
                      final farmerName = data['farmerName'] ?? 'Unknown';
                      final score = (data['score'] is int)
                          ? data['score'] as int
                          : int.tryParse('${data['score']}') ?? 0;
                      final classification =
                          data['classification'] ?? 'Unknown';
                      final timestamp = _parseTimestamp(data['timestamp']);
                      final answers =
                          (data['answers'] ?? {}) as Map<String, dynamic>;
                      final recommendations =
                          (data['recommendations'] ?? []) as List<dynamic>;

                      return _AssessmentCard(
                        assessmentId: assessmentId,
                        farmerName: farmerName,
                        score: score,
                        classification: classification,
                        timestamp: timestamp,
                        answers: answers,
                        recommendations: recommendations.cast<String>(),
                        color: _colorForClassification(classification),
                        onDelete: () => _deleteAssessment(doc.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentCard extends StatefulWidget {
  final String assessmentId;
  final String farmerName;
  final int score;
  final String classification;
  final DateTime timestamp;
  final Map<String, dynamic> answers;
  final List<String> recommendations;
  final Color color;
  final VoidCallback onDelete;

  const _AssessmentCard({
    required this.assessmentId,
    required this.farmerName,
    required this.score,
    required this.classification,
    required this.timestamp,
    required this.answers,
    required this.recommendations,
    required this.color,
    required this.onDelete,
  });

  @override
  State<_AssessmentCard> createState() => _AssessmentCardState();
}

class _AssessmentCardState extends State<_AssessmentCard> {
  bool _expanded = false;
  final DateFormat _df = DateFormat.yMMMd().add_jm();

  @override
  Widget build(BuildContext context) {
    final score = widget.score.clamp(0, 100);
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Column(
            children: [
              Row(
                children: [
                  // Score circle
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: widget.color.withValues(alpha: 0.12),
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.farmerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _df.format(widget.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      widget.classification,
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: widget.color,
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
              // expanded details
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    children: [
                      // Answers grid
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Answers',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _answersTable(widget.answers),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Recommendations',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      ...widget.recommendations.map(
                        (r) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lightbulb_outline),
                          title: Text(r),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // show details modal
                              showDialog(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(
                                    'Assessment Details — ${widget.farmerName}',
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Score: ${widget.score}'),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Classification: ${widget.classification}',
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Answers:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _answersTable(widget.answers),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Recommendations:',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        ...widget.recommendations.map(
                                          (r) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4.0,
                                            ),
                                            child: Text('• $r'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(Icons.visibility),
                            label: const Text('View'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: widget.onDelete,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answersTable(Map<String, dynamic> answers) {
    if (answers.isEmpty) return const Text('No answers saved.');
    // display each key-value in a two-column layout
    return Column(
      children: answers.entries.map((e) {
        final k = e.key;
        final v = e.value?.toString() ?? '-';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(k, style: const TextStyle(color: Colors.black87)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 6,
                child: Text(v, style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
