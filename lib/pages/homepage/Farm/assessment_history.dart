import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'assessment_page.dart';

class AssessmentHistoryPage extends StatefulWidget {
  const AssessmentHistoryPage({super.key});

  @override
  State<AssessmentHistoryPage> createState() => _AssessmentHistoryPageState();
}

class _AssessmentHistoryPageState extends State<AssessmentHistoryPage> {
  final _fire = FirebaseFirestore.instance;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _historyStream() {
    final uid = _uid;
    if (uid == null) {
      // return an empty stream so UI can show "not signed in"
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }
    return _fire
        .collection('assessments')
        .where('farmerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String _formatDate(dynamic ts) {
    // Accepts Firestore Timestamp or ISO string or DateTime
    if (ts == null) return 'Unknown';
    if (ts is Timestamp) {
      final dt = ts.toDate();
      return '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';
    }
    if (ts is DateTime) {
      return '${ts.year}-${_two(ts.month)}-${_two(ts.day)}';
    }
    final s = ts.toString();
    if (s.contains('T')) return s.split('T').first;
    return s;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  Color _classificationColor(String classif) {
    switch (classif.toLowerCase()) {
      case 'high':
        return Colors.green;
      case 'Good':
        return Colors.orange;
      case 'Low':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  int _parseScore(dynamic s) {
    if (s == null) return 0;
    if (s is int) return s;
    if (s is double) return s.toInt();
    return int.tryParse(s.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF2E7D32);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment History'),
        backgroundColor: accent,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _historyStream(),
          builder: (context, snap) {
            if (_uid == null) {
              return const Center(
                child: Text('You must be signed in to view history.'),
              );
            }

            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 60, color: Colors.black26),
                    const SizedBox(height: 12),
                    const Text(
                      'No assessments yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Complete an assessment to see history and track progress over time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                    ),
                  ],
                ),
              );
            }

            final docs = snap.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final doc = docs[index].data();
                final score = _parseScore(doc['score']);
                final classification =
                    (doc['classification'] ??
                            (score <= 40
                                ? 'Low'
                                : (score <= 70 ? 'Medium' : 'High')))
                        .toString();
                final ts = doc['timestamp'];
                final dateStr = _formatDate(ts);
                final recs = List.from(doc['recommendations'] ?? []);
                final notes = doc['notes'] ?? '';

                return _HistoryListTile(
                  score: score,
                  classification: classification,
                  dateStr: dateStr,
                  recommendations: recs.cast<String>(),
                  notes: notes.toString(),
                  color: _classificationColor(classification),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      builder: (context) {
                        return Padding(
                          padding: MediaQuery.of(
                            context,
                          ).viewInsets.add(const EdgeInsets.all(16)),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 74,
                                      height: 74,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CircularProgressIndicator(
                                            value: (score / 100).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            strokeWidth: 8,
                                            valueColor: AlwaysStoppedAnimation(
                                              _classificationColor(
                                                classification,
                                              ),
                                            ),
                                            backgroundColor:
                                                Colors.grey.shade200,
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '$score',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                classification,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Date: $dateStr',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (recs.isNotEmpty) ...[
                                            const Text(
                                              'Top recommendation:',
                                              style: TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '- ${recs.first}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ] else
                                            const Text(
                                              'No recommendations found.',
                                              style: TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Full recommendations',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 8),
                                if (recs.isEmpty)
                                  const Text(
                                    'No Recommendations. Good Job!',
                                    style: TextStyle(color: Colors.black54),
                                  )
                                else
                                  ...recs.map(
                                    (r) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(child: Text('$r')),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (notes.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Notes',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(notes),
                                ],
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          // Re-take: navigate to assessment page (same as Start)
                                          Navigator.pop(
                                            context,
                                          ); // close bottom sheet
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  SimpleAssessmentPage(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.replay),
                                        label: const Text('Re-take'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Close'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// --- Helper list tile for history rows ---
class _HistoryListTile extends StatelessWidget {
  final int score;
  final String classification;
  final String dateStr;
  final List<String> recommendations;
  final String notes;
  final VoidCallback onTap;
  final Color color;

  const _HistoryListTile({
    required this.score,
    required this.classification,
    required this.dateStr,
    required this.recommendations,
    required this.notes,
    required this.onTap,
    required this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final topRec = recommendations.isNotEmpty ? recommendations.first : '—';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: (score / 100).clamp(0.0, 1.0),
                      strokeWidth: 6,
                      valueColor: AlwaysStoppedAnimation(color),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$score',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          classification,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topRec,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
