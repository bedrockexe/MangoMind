// assessment_detail.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'report_service.dart';

/// Modernized Assessment Detail page that shows question text + farmer answer.
/// Replace your old assessment_detail.dart with this file.
class AssessmentDetail extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const AssessmentDetail({Key? key, required this.docId, required this.data})
    : super(key: key);

  @override
  State<AssessmentDetail> createState() => _AssessmentDetailState();
}

class _AssessmentDetailState extends State<AssessmentDetail>
    with SingleTickerProviderStateMixin {
  late final Map<String, dynamic> answers;
  late final Map<String, Map<String, String>> groupedQuestions;
  late final AnimationController _controller;

  static const Map<String, String> _questionBank = {
    // Section A (example — copy exact prompts from your questionnaire PDF)
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
    answers = Map<String, dynamic>.from(widget.data['answers'] ?? {});
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _controller.forward();

    // group answers by section and keep question text where available
    groupedQuestions = {};
    for (final entry in answers.entries) {
      final key = entry.key.toString();
      if (key.isEmpty) continue;
      final section = key[0].toUpperCase();
      groupedQuestions.putIfAbsent(section, () => {});
      final qText =
          _questionBank[key] ?? key; // fallback to key if question text missing
      groupedQuestions[section]![key] = qText;
    }
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
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.green[300],
              child: Text(
                name.isEmpty
                    ? '?'
                    : name
                          .split(' ')
                          .map((s) => s.isEmpty ? '' : s[0])
                          .take(2)
                          .join()
                          .toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        submittedText,
                        style: const TextStyle(color: Colors.grey),
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

  Widget _questionCard(String qKey, String qText, dynamic qAnswer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qText, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                qAnswer?.toString() ?? '-',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
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
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      section,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Section $section',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${questionKeys.length} Qs',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.only(right: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '${answers.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Answered',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.only(left: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            '${groupedQuestions.keys.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sections',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // sections
            ...sections
                .map((s) => _sectionBlock(s, groupedQuestions[s]!))
                .toList(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}
