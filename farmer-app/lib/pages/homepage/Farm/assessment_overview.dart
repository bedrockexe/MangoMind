// farmer_overview.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/transitions.dart';
import 'assessment_page.dart';
import 'assessment_history.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FarmerOverviewPage extends StatefulWidget {
  const FarmerOverviewPage({super.key});

  @override
  State<FarmerOverviewPage> createState() => _FarmerOverviewPageState();
}

class _FarmerOverviewPageState extends State<FarmerOverviewPage> {
  // Stats received from the stat listener (real-time)
  int _submissionCount = 0;
  DateTime? _lastAssessmentDate;

  void _openQuestionnaire() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(appRoute(const QuestionnairePage()));
  }

  void _openHistory() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(appRoute(const MySubmissionsPage()));
  }

  // Callback used by the listener to pass real-time stats up
  void _onStatsLoaded(int count, DateTime? latest) {
    if (!mounted) return;
    setState(() {
      _submissionCount = count;
      _lastAssessmentDate = latest;
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No submissions yet';
    return DateFormat.yMMMd().format(dt);
  }

  void _showHelp() {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space4,
          0,
          AppTheme.space4,
          AppTheme.space5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this works',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            _helpRow(
              theme,
              Icons.note_add_rounded,
              'Tap "Take assessment" to answer seasonal questions about your farm.',
            ),
            const SizedBox(height: AppTheme.space2),
            _helpRow(
              theme,
              Icons.history_rounded,
              'Open "History" to revisit past submissions and export them as PDFs.',
            ),
            const SizedBox(height: AppTheme.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.check),
                label: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpRow(ThemeData theme, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }

  Widget _hero(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space5),
      decoration: BoxDecoration(
        borderRadius: AppTheme.cardRadius,
        gradient: const LinearGradient(
          colors: [AppTheme.brandGreen, AppTheme.brandGreenDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGreen.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FARM ASSESSMENT',
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          const Text(
            'Know your season',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          const Text(
            'Answer a few questions about your farm to get guidance tailored to '
            'your crop cycle.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: AppTheme.space4),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  '$_submissionCount',
                  'Submissions',
                  Icons.fact_check_outlined,
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: _heroStat(
                  _formatDate(_lastAssessmentDate),
                  'Last assessment',
                  Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: AppTheme.space2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color tint,
    required VoidCallback onTap,
    Widget? badge,
  }) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(icon, color: tint, size: 26),
          ),
          const SizedBox(width: AppTheme.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (badge != null) badge,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.space2),
          Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'How this works',
            onPressed: _showHelp,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Invisible live-stats listener (keeps the original stream logic)
            _StatsListener(onStatsLoaded: _onStatsLoaded),
            ListView(
              padding: const EdgeInsets.all(AppTheme.space4),
              children: [
                _hero(theme).animate().fadeIn(duration: 350.ms),
                const SizedBox(height: AppTheme.space5),
                const SectionHeader('Get started'),
                _actionCard(
                  icon: Icons.note_add_rounded,
                  title: 'Take assessment',
                  subtitle: 'Answer seasonal questions — about 10 minutes.',
                  tint: theme.colorScheme.primary,
                  onTap: _openQuestionnaire,
                ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                const SizedBox(height: AppTheme.space3),
                _actionCard(
                  icon: Icons.history_rounded,
                  title: 'Assessment history',
                  subtitle: 'View past submissions and export reports.',
                  tint: theme.colorScheme.tertiary,
                  onTap: _openHistory,
                  badge: _submissionCount > 0
                      ? AppStatusChip(
                          '$_submissionCount',
                          tone: StatusTone.info,
                        )
                      : null,
                ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),
                const SizedBox(height: AppTheme.space5),
                const SectionHeader('Tips for better answers'),
                AppCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(
                        child: Text(
                          'Answer honestly to get useful recommendations, and use '
                          'your history to track how things change across seasons.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space5),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscribes to live updates for the signed-in farmer's assessment documents
/// and reports the submission count and latest date back up via [onStatsLoaded].
/// Renders nothing — it is purely a data listener.
class _StatsListener extends StatefulWidget {
  final void Function(int submissionCount, DateTime? latestDate) onStatsLoaded;
  const _StatsListener({required this.onStatsLoaded});

  @override
  State<_StatsListener> createState() => _StatsListenerState();
}

class _StatsListenerState extends State<_StatsListener> {
  StreamSubscription<QuerySnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onStatsLoaded(0, null),
      );
      return;
    }

    final query = FirebaseFirestore.instance
        .collection('assessments')
        .where('farmer_id', isEqualTo: user.uid)
        .orderBy('submitted_at', descending: true);

    _subscription = query.snapshots().listen(
      (snapshot) {
        final count = snapshot.docs.length;
        DateTime? latest;
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          final submittedAt = data['submitted_at'];
          if (submittedAt is Timestamp) {
            latest = submittedAt.toDate();
          } else if (submittedAt is DateTime) {
            latest = submittedAt;
          }
        }
        widget.onStatsLoaded(count, latest);
      },
      onError: (err) {
        widget.onStatsLoaded(0, null);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
