// farmer_overview.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'assessment_page.dart';
import 'assessment_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FarmerOverviewPage extends StatefulWidget {
  const FarmerOverviewPage({Key? key}) : super(key: key);

  @override
  State<FarmerOverviewPage> createState() => _FarmerOverviewPageState();
}

class _FarmerOverviewPageState extends State<FarmerOverviewPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // Stats received from the stat widget (real-time)
  int _submissionCount = 0;
  DateTime? _lastAssessmentDate;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openQuestionnaire() {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QuestionnairePage()));
  }

  void _openHistory() {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MySubmissionsPage()));
  }

  Widget _buildHeroCard({
    required Color start,
    required Color end,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required String badge,
  }) {
    return SlideTransition(
      position: _slideUp,
      child: FadeTransition(
        opacity: _fadeIn,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [start, end],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // icon circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(icon, size: 36, color: Colors.white),
                ),
                const SizedBox(width: 14),
                // text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // chevron
                Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.9)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallInfoCard(String label, String value, {IconData? icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          children: [
            if (icon != null) Icon(icon, size: 18, color: Colors.green),
            if (icon != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Callback used by the child to pass real-time stats up
  void _onStatsLoaded(int count, DateTime? latest) {
    setState(() {
      _submissionCount = count;
      _lastAssessmentDate = latest;
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No submissions yet';
    return DateFormat.yMMMd().add_jm().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    // Responsive paddings
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome, Farmer'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How this works',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'How to use',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Tap "Take Assessment" to answer seasonal questions about your farm.',
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '• Use "Assessment History" to view your past submissions and export PDFs.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Got it'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? width * 0.12 : 0,
            vertical: 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // greeting + short description
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Sweet Insights',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Get personalized farming guidance and keep track of your assessments.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // small stat cards (child will push stats up via callback)
                    SizedBox(
                      width: isWide ? 260 : 120,
                      child: Column(
                        children: [
                          _SmallStatRow(onStatsLoaded: _onStatsLoaded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // action cards
              _buildHeroCard(
                start: Colors.green.shade600,
                end: Colors.green.shade400,
                icon: Icons.note_add_rounded,
                title: 'Take Assessment',
                subtitle:
                    'Answer questions about your farm — takes ~10 minutes.',
                onTap: _openQuestionnaire,
                badge: 'Start',
              ),

              _buildHeroCard(
                start: Colors.indigo.shade600,
                end: Colors.indigo.shade400,
                icon: Icons.history_rounded,
                title: 'Assessment History',
                subtitle: 'View previous submissions and export reports.',
                onTap: _openHistory,
                badge: 'History',
              ),

              const SizedBox(height: 18),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildSmallInfoCard(
                        'Last assessment',
                        _formatDate(_lastAssessmentDate),
                        icon: Icons.calendar_month,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // help card and tips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Tips for better answers',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 6),
                              Text(
                                '• Answer honestly to get useful recommendations.\n• Use the history to track changes across seasons.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 38),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small widget that subscribes to live updates for the signed-in farmer's assessment documents.
/// It reports submission count and the latest assessment date back to the parent via `onStatsLoaded`.
class _SmallStatRow extends StatefulWidget {
  final void Function(int submissionCount, DateTime? latestDate) onStatsLoaded;
  const _SmallStatRow({Key? key, required this.onStatsLoaded})
    : super(key: key);

  @override
  State<_SmallStatRow> createState() => _SmallStatRowState();
}

class _SmallStatRowState extends State<_SmallStatRow> {
  late final StreamSubscription<QuerySnapshot> _subscription;
  int _submissionCount = 0;
  DateTime? _latestDate;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // no user: nothing to listen to. inform parent with zeros.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onStatsLoaded(0, null),
      );
      setState(() {
        _loading = false;
      });
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('assessments')
        .where('farmer_id', isEqualTo: user.uid)
        .orderBy('submitted_at', descending: true);

    _subscription = query.snapshots().listen(
      (snapshot) {
        int count = snapshot.docs.length;
        DateTime? latest;
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data() as Map<String, dynamic>;
          final submittedAt = data['submitted_at'];
          if (submittedAt is Timestamp) {
            latest = submittedAt.toDate();
          } else if (submittedAt is DateTime) {
            latest = submittedAt;
          } else {
            latest = null;
          }
        } else {
          latest = null;
        }

        setState(() {
          _submissionCount = count;
          _latestDate = latest;
          _loading = false;
        });

        // pass stats up
        widget.onStatsLoaded(_submissionCount, _latestDate);
      },
      onError: (err) {
        // On error, still inform parent with zeros
        widget.onStatsLoaded(0, null);
        setState(() {
          _submissionCount = 0;
          _latestDate = null;
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    try {
      _subscription.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$_submissionCount',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Submissions',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
