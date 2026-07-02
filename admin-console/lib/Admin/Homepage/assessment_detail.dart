// assessment_detail.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_service.dart';
import 'manage_questions.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';

/// Modernized Assessment Detail page that shows question text + farmer answer.
/// Replace your old assessment_detail.dart with this file.
class AssessmentDetail extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AssessmentDetail({super.key, required this.docId, required this.data});

  @override
  State<AssessmentDetail> createState() => _AssessmentDetailState();
}

class _AssessmentDetailState extends State<AssessmentDetail>
    with SingleTickerProviderStateMixin {
  final Map<String, dynamic> answers = {};
  Map<String, Map<String, String>> groupedQuestions = {};
  late final AnimationController _controller;

  /// Effective question bank (admin-managed, with hardcoded defaults as a
  /// fallback). Loaded from Firestore after the first frame.
  Map<String, String> _questionBank = kDefaultQuestionBank;

  @override
  void initState() {
    super.initState();
    answers.addAll(Map<String, dynamic>.from(widget.data['answers'] ?? {}));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _controller.forward();

    _rebuildGroups();
    _loadBank();
  }

  Future<void> _loadBank() async {
    final bank = await loadQuestionBank();
    if (!mounted) return;
    setState(() {
      _questionBank = bank;
      _rebuildGroups();
    });
  }

  /// Group answered questions by section, using managed question text where
  /// available and falling back to the answer key.
  void _rebuildGroups() {
    final groups = <String, Map<String, String>>{};
    for (final entry in answers.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      final section = key[0].toUpperCase();
      groups.putIfAbsent(section, () => {});
      groups[section]![key] = _questionBank[key] ?? key;
    }
    groupedQuestions = groups;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _headerCard(
    String name,
    String email,
    String farm,
    String submittedText,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              name.isEmpty
                  ? '?'
                  : name
                        .split(' ')
                        .map((s) => s.isEmpty ? '' : s[0])
                        .take(2)
                        .join()
                        .toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Unknown farmer' : name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(email, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  submittedText,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(String qKey, String qText, dynamic qAnswer) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(qText, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              qAnswer?.toString() ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionBlock(String section, Map<String, String> qmap) {
    final questionKeys = qmap.keys.toList()..sort();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, val, child) {
        return Opacity(
          opacity: val,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - val)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space3),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppStatusChip(section, tone: StatusTone.success),
                  const SizedBox(width: AppTheme.space3),
                  Text(
                    'Section $section',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${questionKeys.length} Qs',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              Column(
                children: questionKeys.map((k) {
                  final text = qmap[k]!;
                  final ans = answers[k];
                  return _questionCard(k, text, ans);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.data['farmer_name'] ?? '').toString();
    final email = (widget.data['farmer_email'] ?? '').toString();
    final farm = (widget.data['farm_name'] ?? '').toString();
    final submittedAt = widget.data['submitted_at'] as Timestamp?;
    final submittedText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : 'Not submitted';

    final sections = groupedQuestions.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment Details'),
        actions: [
          IconButton(
            tooltip: 'Export detailed PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () async {
              await ReportService.generateSingleAssessmentPdf(
                widget.docId,
                widget.data,
                questionBank: _questionBank,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerCard(name, email, farm, submittedText),
            const SizedBox(height: AppTheme.space3),
            Row(
              children: [
                Expanded(child: _statTile('${answers.length}', 'Answered')),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: _statTile(
                    '${groupedQuestions.keys.length}',
                    'Sections',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            // sections
            ...sections.map((s) => _sectionBlock(s, groupedQuestions[s]!)),
            const SizedBox(height: AppTheme.space5),
          ],
        ),
      ),
    );
  }
}
