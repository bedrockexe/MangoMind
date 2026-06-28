// admin_home.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'assessment_detail.dart';
import 'report_service.dart';

class Assessment extends StatefulWidget {
  const Assessment({super.key});

  @override
  State<Assessment> createState() => _AssessmentState();
}

class _AssessmentState extends State<Assessment>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  late final AnimationController _animController;

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
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animController.forward();
    _searchCtrl.addListener(
      () => setState(() => _search = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
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

  Widget _buildCard(QueryDocumentSnapshot doc, int index) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['farmer_name'] ?? 'Unknown Farmer';
    final email = data['farmer_email'] ?? '';
    final submittedAt = data['submitted_at'] as Timestamp?;
    final timeText = submittedAt != null
        ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
        : 'Not submitted';

    // small summary: whether answers exist
    final answers = (data['answers'] ?? {}) as Map<String, dynamic>;
    final tookAssessment = answers.isNotEmpty;

    // staggered animation offset
    final anim = CurvedAnimation(
      parent: _animController,
      curve: Interval(
        (index * .03).clamp(0.0, 0.9),
        1.0,
        curve: Curves.easeOut,
      ),
    );
    return SizeTransition(
      sizeFactor: anim,
      axisAlignment: 0.0,
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AssessmentDetail(docId: doc.id, data: data),
            ),
          );
        },
        child: Card(
          elevation: 6,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // left avatar/status
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: tookAssessment
                          ? [Colors.green.shade300, Colors.green.shade600]
                          : [Colors.grey.shade300, Colors.grey.shade500],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      (name
                              .toString()
                              .split(' ')
                              .map((s) => s.isEmpty ? '' : s[0])
                              .take(2)
                              .join())
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // main info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              tookAssessment ? 'Completed' : 'No Response',
                            ),
                            backgroundColor: tookAssessment
                                ? Colors.green.shade50
                                : Colors.grey.shade200,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            onPressed: () async {
                              // Generate PDF for single assessment
                              await ReportService.generateSingleAssessmentPdf(
                                doc.id,
                                data,
                                questionBank: _questionBank,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Assessments'),
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
          // search bar with modern style
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by farmer name, email',
                  border: InputBorder.none,
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _assessmentsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs
                    .where(
                      (d) => _matchesSearch((d.data() as Map<String, dynamic>)),
                    )
                    .toList();
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text(
                        'No assessments found. Try clearing the search or wait for submissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // animate controller restart so new items animate
                _animController.reset();
                _animController.forward();

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (context, i) => _buildCard(docs[i], i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
