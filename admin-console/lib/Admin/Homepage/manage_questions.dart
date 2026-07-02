import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';

/// Friendly section names shown alongside the section letter.
const Map<String, String> kSectionTitles = {
  'A': 'Season preparation',
  'B': 'Flowering',
  'C': 'Harvesting',
  'D': 'Storage & selling',
  'E': 'Overall & support',
};

/// The original hardcoded questionnaire. Used to seed Firestore the first time
/// and as a fallback so nothing ever renders blank.
const Map<String, String> kDefaultQuestionBank = {
  'A1': 'When do you start preparing your farm for the mango season?',
  'A2': 'What type of fertilizer do you use before flowering?',
  'A3': 'Do you check your soil condition or moisture before applying fertilizer?',
  'A4': 'How do you know when your trees are ready for flowering?',
  'A5': 'What is your biggest problem at the start of the season?',
  'A6': 'How often do you face unexpected rain or drought during preparation?',
  'A7': 'Do you record your fertilizer or chemical usage?',
  'A8': 'How do you get updates about weather for farming?',
  'A9': 'Do you think using an app to guide farm timing would help you?',
  'A10': 'What do you need most before flowering?',
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
  'E1': 'What is your biggest problem in mango farming right now?',
  'E2': 'Which part of farming do you find hardest to manage?',
  'E3': 'What do you think causes most of your farming losses?',
  'E4': 'Where do you usually ask for help or advice when problems happen?',
  'E5': 'What kind of help would improve your mango production the most?',
  'E6': 'Have you received any support or training from government or organizations?',
  'E7': 'Would you like more training about mango care and new farming methods?',
  'E8': 'Do you think an app that gives alerts and guides could reduce your farming problems?',
  'E9': 'What would make you trust a farming app like MangoMind more?',
  'E10': 'If MangoMind helps you increase your income or reduce losses, would you continue using it every season?',
};

CollectionReference<Map<String, dynamic>> _questionsCol() =>
    FirebaseFirestore.instance.collection('assessment_questions');

/// Loads the effective question bank: the hardcoded defaults with any
/// admin-managed questions from Firestore overlaid on top. Falls back to the
/// defaults if Firestore is empty or unreachable, so the answer view and PDF
/// export always have text to show.
Future<Map<String, String>> loadQuestionBank() async {
  final map = Map<String, String>.from(kDefaultQuestionBank);
  try {
    final snap = await _questionsCol().get();
    for (final d in snap.docs) {
      final data = d.data();
      final code = (data['code'] ?? d.id).toString();
      final text = (data['text'] ?? '').toString();
      if (text.isNotEmpty) map[code] = text;
    }
  } catch (_) {
    // keep defaults
  }
  return map;
}

class AssessmentQuestion {
  final String code; // e.g. A1
  final String section; // e.g. A
  final String text;
  final int order;

  AssessmentQuestion({
    required this.code,
    required this.section,
    required this.text,
    required this.order,
  });

  factory AssessmentQuestion.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final code = (data['code'] ?? doc.id).toString();
    final section = (data['section'] ?? (code.isNotEmpty ? code[0] : '?'))
        .toString();
    final orderRaw = data['order'];
    final order = orderRaw is int
        ? orderRaw
        : int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return AssessmentQuestion(
      code: code,
      section: section,
      text: (data['text'] ?? '').toString(),
      order: order,
    );
  }
}

class ManageQuestionsPage extends StatelessWidget {
  const ManageQuestionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assessment questions')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _questionsCol().snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off,
              title: 'Could not load questions',
              message: '${snap.error}',
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const ListSkeleton();
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return _EmptyQuestions();
          }

          // Group questions by section.
          final questions = docs.map(AssessmentQuestion.fromDoc).toList();
          final Map<String, List<AssessmentQuestion>> bySection = {};
          for (final q in questions) {
            bySection.putIfAbsent(q.section, () => []).add(q);
          }
          for (final list in bySection.values) {
            list.sort((a, b) => a.order.compareTo(b.order));
          }
          final sections = bySection.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              for (final section in sections) ...[
                SectionHeader(
                  kSectionTitles[section] != null
                      ? '$section · ${kSectionTitles[section]}'
                      : 'Section $section',
                  trailing: TextButton.icon(
                    onPressed: () =>
                        _showQuestionSheet(context, presetSection: section),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
                ),
                ...bySection[section]!.map(
                  (q) => _QuestionTile(question: q),
                ),
                const SizedBox(height: AppTheme.space3),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuestionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add question'),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});

  final AssessmentQuestion question;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete question?'),
        content: Text(
          'Remove ${question.code}? Existing farmer answers stay, but this '
          'question will no longer be shown.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _questionsCol().doc(question.code).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: AppCard(
        onTap: () => _showQuestionSheet(context, existing: question),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppStatusChip(question.code, tone: StatusTone.info),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Text(
                question.text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _showQuestionSheet(context, existing: question),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.delete_outline, color: scheme.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyQuestions extends StatefulWidget {
  @override
  State<_EmptyQuestions> createState() => _EmptyQuestionsState();
}

class _EmptyQuestionsState extends State<_EmptyQuestions> {
  bool _seeding = false;

  Future<void> _seed() async {
    setState(() => _seeding = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      kDefaultQuestionBank.forEach((code, text) {
        final section = code.isNotEmpty ? code[0] : '?';
        final order = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        batch.set(_questionsCol().doc(code), {
          'code': code,
          'section': section,
          'text': text,
          'order': order,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      await batch.commit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load questions: $e')));
      }
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.quiz_outlined,
      title: 'No questions yet',
      message:
          'Load the current questionnaire to start editing, then add or change '
          'questions anytime.',
      action: FilledButton.icon(
        onPressed: _seeding ? null : _seed,
        icon: _seeding
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: Text(_seeding ? 'Loading…' : 'Load starter questions'),
      ),
    );
  }
}

/// Bottom sheet to add a new question or edit an existing one.
Future<void> _showQuestionSheet(
  BuildContext context, {
  AssessmentQuestion? existing,
  String? presetSection,
}) async {
  final isEdit = existing != null;
  final textCtrl = TextEditingController(text: existing?.text ?? '');
  String section = existing?.section ?? presetSection ?? 'A';
  bool saving = false;

  Future<String> nextCode(String sec) async {
    final snap = await _questionsCol().where('section', isEqualTo: sec).get();
    int maxN = 0;
    for (final d in snap.docs) {
      final o = d.data()['order'];
      if (o is int && o > maxN) maxN = o;
    }
    return '$sec${maxN + 1}';
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => Padding(
        padding: EdgeInsets.only(
          left: AppTheme.space4,
          right: AppTheme.space4,
          top: AppTheme.space2,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppTheme.space4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Edit question ${existing.code}' : 'Add question',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppTheme.space4),
            DropdownButtonFormField<String>(
              initialValue: section,
              decoration: const InputDecoration(
                labelText: 'Section',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: kSectionTitles.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text('${e.key} · ${e.value}'),
                    ),
                  )
                  .toList(),
              // Section is fixed once created so the answer key (code) stays stable.
              onChanged: isEdit
                  ? null
                  : (v) => setLocal(() => section = v ?? 'A'),
            ),
            const SizedBox(height: AppTheme.space3),
            TextField(
              controller: textCtrl,
              autofocus: true,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Type the question farmers will answer…',
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        final text = textCtrl.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter the question text.'),
                            ),
                          );
                          return;
                        }
                        setLocal(() => saving = true);
                        try {
                          if (isEdit) {
                            await _questionsCol().doc(existing.code).update({
                              'text': text,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            final code = await nextCode(section);
                            final order =
                                int.tryParse(
                                  code.replaceAll(RegExp(r'[^0-9]'), ''),
                                ) ??
                                0;
                            await _questionsCol().doc(code).set({
                              'code': code,
                              'section': section,
                              'text': text,
                              'order': order,
                              'createdAt': FieldValue.serverTimestamp(),
                            });
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setLocal(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Could not save: $e')),
                            );
                          }
                        }
                      },
                icon: saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isEdit ? 'Save changes' : 'Add question'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
