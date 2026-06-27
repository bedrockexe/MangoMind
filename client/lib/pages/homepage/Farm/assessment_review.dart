// review_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'assessment_reporting.dart';

class ReviewPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> answers;
  final Map<String, String> questionBank;
  final Map<String, dynamic>? docData;

  const ReviewPage({
    Key? key,
    required this.docId,
    required this.answers,
    required this.questionBank,
    this.docData,
  }) : super(key: key);

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

  Widget _questionTile(String qKey, String qText, dynamic qAnswer) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qText, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              qAnswer?.toString() ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final name = docData?['farmer_name'] ?? 'You';
    final email = docData?['farmer_email'] ?? '';
    final submittedAt = docData?['submitted_at'] as Timestamp?;
    final submittedText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : DateFormat.yMMMd().addPattern(' h:mm a').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Answers'),
        actions: [
          IconButton(
            tooltip: 'Export as PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
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
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          (name.toString().isEmpty
                                  ? '?'
                                  : name
                                        .toString()
                                        .split(' ')
                                        .map((s) => s.isEmpty ? '' : s[0])
                                        .take(2)
                                        .join())
                              .toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email.toString(),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Submitted: $submittedText',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // TextButton.icon(
                      //   onPressed: () {
                      //     // optional: let them edit—navigate back to questionnaire with existing answers (not implemented)
                      //     ScaffoldMessenger.of(context).showSnackBar(
                      //       const SnackBar(
                      //         content: Text('Edit not implemented'),
                      //       ),
                      //     );
                      //   },
                      //   icon: const Icon(Icons.edit_outlined),
                      //   label: const Text('Edit'),
                      // ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // sections
            ...((grouped.keys.toList()..sort()).map((section) {
              final qmap = grouped[section]!;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Section $section',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...((qmap.keys.toList()..sort()).map((qKey) {
                      final qText = questionBank[qKey] ?? qKey;
                      final qAnswer = qmap[qKey];
                      return _questionTile(qKey, qText, qAnswer);
                    }).toList()),
                  ],
                ),
              );
            }).toList()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
