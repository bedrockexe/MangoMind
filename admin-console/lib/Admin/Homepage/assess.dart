// admin_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'assessment_detail.dart';
import 'report_service.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';

class Assessment extends StatefulWidget {
  const Assessment({super.key});

  @override
  State<Assessment> createState() => _AssessmentState();
}

class _AssessmentState extends State<Assessment> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  static const Map<String, String> _questionBank = {
    'A1': 'When do you start preparing your farm for the mango season?',
    'A2': 'What type of fertilizer do you use before flowering?',
    'A3':
        'Do you check your soil condition or moisture before applying fertilizer?',
    'A4': 'How do you know when your trees are ready for flowering?',
    'A5': 'What is your biggest problem at the start of the season?',
    'A6':
        'How often do you face unexpected rain or drought during preparation?',
    'A7': 'Do you record your fertilizer or chemical usage?',
    'A8': 'How do you get updates about weather for farming?',
    'A9': 'Do you think using an app to guide farm timing would help you?',
    'A10': 'What do you need most before flowering?',

    // Section B
    'B1': 'When do your mango trees usually start flowering?',
    'B2': 'Do you use a flower inducer or let them flower naturally?',
    'B3': 'What weather problem affects flowering the most?',
    'B4': 'Do you often have pest problems during flowering?',
    'B5': 'How do you control pests during this stage?',
    'B6': 'Do you experience many fruits falling before harvest?',
    'B7': 'What do you think causes fruit drop?',
    'B8': 'How often do you water or irrigate your trees during flowering?',
    'B9': 'Do you record weather conditions during flowering?',
    'B10': 'What help do you need most during this stage?',

    // Section C
    'C1': 'When do you usually start harvesting?',
    'C2': 'Who helps you harvest?',
    'C3': 'How do you decide when fruits are ready to harvest?',
    'C4': 'What weather condition often affects your harvest?',
    'C5': 'Do you record your total harvest (number or weight)?',
    'C6': 'How do you keep your harvested fruits?',
    'C7': 'Do you experience fruit damage or loss during harvest?',
    'C8': 'What causes most harvest losses?',
    'C9': 'Would it help if the app reminds you of ideal harvest dates?',
    'C10': 'What support would make harvesting easier?',

    // Section D
    'D1': 'How do you store your mangoes after harvest?',
    'D2': 'Do you lose fruits due to spoilage before selling?',
    'D3': 'How do you bring mangoes to the buyer or market?',
    'D4': 'Where do you usually sell your mangoes?',
    'D5': 'How do you know the current market price?',
    'D6': 'What is your biggest selling problem?',
    'D7': 'Do you record your sales and income per harvest?',
    'D8': 'Would you use an app that shows daily mango prices?',
    'D9': 'How often do you face price changes during harvest time?',
    'D10': 'What kind of app feature would help you sell better?',

    // Section E
    'E1': 'What is your biggest problem in mango farming right now?',
    'E2': 'Which part of farming do you find hardest to manage?',
    'E3': 'What do you think causes most of your farming losses?',
    'E4': 'Where do you usually ask for help or advice when problems happen?',
    'E5': 'What kind of help would improve your mango production the most?',
    'E6':
        'Have you received any support or training from government or organizations?',
    'E7':
        'Would you like more training about mango care and new farming methods?',
    'E8':
        'Do you think an app that gives alerts and guides could reduce your farming problems?',
    'E9': 'What would make you trust a farming app like MangoMind more?',
    'E10':
        'If MangoMind helps you increase your income or reduce losses, would you continue using it every season?',
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _search = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _assessmentsStream() {
    return FirebaseFirestore.instance
        .collection('assessments')
        .orderBy('submitted_at', descending: true)
        .snapshots();
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;
    final name = (data['farmer_name'] ?? '').toString().toLowerCase();
    final email = (data['farmer_email'] ?? '').toString().toLowerCase();
    final farm = (data['farm_name'] ?? '').toString().toLowerCase();
    return name.contains(_search) ||
        email.contains(_search) ||
        farm.contains(_search);
  }

  Widget _buildCard(QueryDocumentSnapshot doc) {
    final scheme = Theme.of(context).colorScheme;
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['farmer_name'] ?? 'Unknown Farmer').toString();
    final email = (data['farmer_email'] ?? '').toString();
    final submittedAt = data['submitted_at'] as Timestamp?;
    final timeText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : 'Not submitted';

    final answers = (data['answers'] ?? {}) as Map<String, dynamic>;
    final tookAssessment = answers.isNotEmpty;

    final initials = name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: AppCard(
        onTap: () => Navigator.of(context).push(
          appRoute(AssessmentDetail(docId: doc.id, data: data)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                color: tookAssessment
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
              ),
              alignment: Alignment.center,
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  color: tookAssessment
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space2),
                      AppStatusChip(
                        tookAssessment ? 'Completed' : 'No response',
                        tone: tookAssessment
                            ? StatusTone.success
                            : StatusTone.neutral,
                      ),
                    ],
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppTheme.space2),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Export PDF',
                        onPressed: () =>
                            ReportService.generateSingleAssessmentPdf(
                              doc.id,
                              data,
                              questionBank: _questionBank,
                            ),
                      ),
                    ],
                  ),
                ],
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
      appBar: AppBar(
        title: const Text('Assessments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generate overall PDF report',
            onPressed: () async {
              // generate summary pdf for all assessments
              final snack = ScaffoldMessenger.of(context);
              snack.showSnackBar(
                const SnackBar(content: Text('Generating report...')),
              );
              try {
                await ReportService.generateSummaryPdf(
                  questionBank: _questionBank,
                );
              } catch (e) {
                snack.showSnackBar(
                  SnackBar(content: Text('Report generation failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by farmer name or email',
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _assessmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off,
                    title: 'Could not load assessments',
                    message: '${snapshot.error}',
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListSkeleton();
                }

                final docs = snapshot.data!.docs
                    .where(
                      (d) => _matchesSearch((d.data() as Map<String, dynamic>)),
                    )
                    .toList();
                if (docs.isEmpty) {
                  return EmptyState(
                    icon: Icons.assignment_outlined,
                    title: _search.isEmpty
                        ? 'No assessments yet'
                        : 'No matches',
                    message: _search.isEmpty
                        ? 'Submitted farmer assessments will appear here.'
                        : 'Try a different farmer name or email.',
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.space4,
                    AppTheme.space2,
                    AppTheme.space4,
                    AppTheme.space4,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildCard(docs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
