// review_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'assessment_reporting.dart';

class ReviewPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> answers;
  final Map<String, String> questionBank;
  final Map<String, dynamic>? docData;

  const ReviewPage({
    super.key,
    required this.docId,
    required this.answers,
    required this.questionBank,
    this.docData,
  });

  // Friendly names for each section letter.
  static const Map<String, String> _sectionNames = {
    'A': 'Pre-season',
    'B': 'Flowering',
    'C': 'Harvest',
    'D': 'Selling',
    'E': 'Overall',
  };

  // group answers by section letter
  Map<String, Map<String, dynamic>> _grouped() {
    final Map<String, Map<String, dynamic>> grouped = {};
    for (final e in answers.entries) {
      final k = e.key;
      final section = k.isNotEmpty ? k[0].toUpperCase() : '?';
      grouped.putIfAbsent(section, () => {});
      grouped[section]![k] = e.value;
    }
    return grouped;
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    return name
        .split(' ')
        .map((s) => s.isEmpty ? '' : s[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  Future<void> _exportPdf(String name, String email) async {
    await ReportService.generateSingleAssessmentPdf(
      docId,
      docData ??
          {
            'answers': answers,
            'farmer_name': name,
            'farmer_email': email,
            'submitted_at': FieldValue.serverTimestamp(),
          },
      questionBank: questionBank,
    );
  }

  Widget _questionTile(BuildContext context, String qText, dynamic qAnswer) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space3),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              qText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              qAnswer?.toString() ?? '-',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grouped = _grouped();
    final name = (docData?['farmer_name'] ?? 'You').toString();
    final email = (docData?['farmer_email'] ?? '').toString();
    final submittedAt = docData?['submitted_at'] as Timestamp?;
    final submittedText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : DateFormat.yMMMd().add_jm().format(DateTime.now());
    final sectionKeys = grouped.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your answers'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Export as PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportPdf(name, email),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          // Header card
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: scheme.primaryContainer,
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space2),
                      Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              submittedText,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: AppTheme.space5),

          // Sections
          ...sectionKeys.map((section) {
            final qmap = grouped[section]!;
            final qKeys = qmap.keys.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  _sectionNames[section] ?? 'Section $section',
                ),
                ...qKeys.map((qKey) {
                  final qText = questionBank[qKey] ?? qKey;
                  return _questionTile(context, qText, qmap[qKey]);
                }),
                const SizedBox(height: AppTheme.space3),
              ],
            );
          }),

          const SizedBox(height: AppTheme.space2),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _exportPdf(name, email),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export as PDF'),
            ),
          ),
          const SizedBox(height: AppTheme.space5),
        ],
      ),
    );
  }
}
