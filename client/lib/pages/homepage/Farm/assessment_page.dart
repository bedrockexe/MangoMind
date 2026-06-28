import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assessment_review.dart';

class QuestionnairePage extends StatefulWidget {
  final Map<String, dynamic>? initialDraft;
  const QuestionnairePage({super.key, this.initialDraft});

  @override
  State<QuestionnairePage> createState() => _QuestionnairePageState();
}

class _QuestionnairePageState extends State<QuestionnairePage> {
  final Map<String, dynamic> answers = {};
  final Map<String, TextEditingController> textControllers = {};
  int currentSection = 0;
  final sections = ['A', 'B', 'C', 'D', 'E'];

  static const Map<String, String> QUESTION_BANK = {
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
    'E9': 'What would make you trust a farming app like Sweet Insights more?',
    'E10':
        'If Sweet Insights helps you increase your income or reduce losses, would you continue using it every season?',
  };

  final Map<String, List<String>> options = {
    'A1': [
      'Before October',
      'October–December',
      'January–February',
      'Just before flowering starts',
    ],
    'A2': ['Organic', 'Chemical', 'Both', 'None'],
    'A3': ['Yes', 'Sometimes', 'No', 'I don’t know how'],
    'A4': [
      'Based on weather',
      'Based on experience',
      'Advice from others',
      'Random timing',
    ],
    'A5': ['Weather', 'Lack of money', 'Labor', 'Pests'],
    'A6': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'A7': ['Yes', 'Sometimes', 'No', 'I don’t know how'],
    'A8': ['Phone or app', 'Radio or news', 'Other farmers', 'I don’t check'],
    'A9': ['Yes', 'Maybe', 'Not sure', 'No'],
    'A10': [
      'Better weather info',
      'Farm budget',
      'Equipment',
      'Pest control help',
    ],

    'B1': ['December', 'January', 'February', 'March or later'],
    'B2': ['Use inducer', 'Natural', 'Both', 'None'],
    'B3': ['Too much rain', 'Too dry', 'Strong wind', 'None'],
    'B4': ['Yes', 'Sometimes', 'Rarely', 'Never'],
    'B5': ['Spray', 'Organic control', 'Advice from others', 'Do nothing'],
    'B6': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'B7': ['Weather', 'Pests', 'Lack of nutrients', 'I don’t know'],
    'B8': ['Regularly', 'Only when dry', 'Rarely', 'Never'],
    'B9': ['Always', 'Sometimes', 'Rarely', 'Never'],
    // B10 is open: "What help do you need most during this stage?"
    'B10': [
      'Pest alerts',
      'Weather updates',
      'Fertilizer guide',
      'Labor assistance',
    ],

    'C1': ['March', 'April', 'May', 'Other'],
    'C2': ['Family', 'Hired workers', 'Both', 'Others'],
    'C3': ['Fruit color', 'Size', 'Buyer schedule', 'Random timing'],
    'C4': ['Rain', 'Heat', 'Wind', 'None'],
    'C5': ['Yes', 'Sometimes', 'No', 'Not sure how'],
    'C6': ['Basket', 'Sack', 'Crate', 'Other'],
    'C7': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'C8': ['Weather', 'Handling', 'Delay', 'Transport'],
    'C9': ['Yes', 'Maybe', 'Not sure', 'No'],
    'C10': ['Weather alert', 'Labor info', 'Equipment', 'Buyer coordination'],

    'D1': ['Cool area', 'Warehouse', 'Open space', 'None'],
    'D2': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'D3': ['Tricycle', 'Truck', 'Buyer pickup', 'Others'],
    'D4': ['Local market', 'Trader', 'Direct buyer', 'Online'],
    'D5': ['Buyers', 'Market visit', 'Online', 'Guess only'],
    'D6': ['Low price', 'No buyer', 'Late payment', 'Transport cost'],
    'D7': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'D8': ['Yes', 'Maybe', 'No', 'Not sure'],
    'D9': ['Always', 'Sometimes', 'Rarely', 'Never'],
    'D10': [
      'Price updates',
      'Buyer contacts',
      'Online selling',
      'Income tracking',
    ],

    'E1': [
      'Weather changes',
      'Pest and disease',
      'Low market price',
      'Lack of funds',
    ],
    'E2': ['Flowering', 'Fruit care', 'Harvest', 'Selling'],
    'E3': ['Bad weather', 'Pests', 'Poor timing', 'Lack of support'],
    'E4': [
      'Fellow farmers',
      'Agriculture office',
      'Technicians',
      'I handle it myself',
    ],
    'E5': [
      'Weather and pest updates',
      'Fertilizer and chemical guide',
      'Training',
      'Financial support',
    ],
    'E6': ['Yes', 'No', 'Sometimes', 'Not aware'],
    'E7': ['Yes', 'Maybe', 'Not sure', 'No'],
    'E8': ['Strongly agree', 'Agree', 'Disagree', 'Not sure'],
    'E9': [
      'Accurate data',
      'Easy to use',
      'Local language',
      'Supported by agriculture office',
    ],
    'E10': ['Yes', 'Maybe', 'Not sure', 'No'],
  };

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    for (final c in textControllers.values) c.dispose();
    super.dispose();
  }

  Widget _buildRadioQuestion(String key, String questionLabel) {
    final opts = options[key] ?? [];
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionLabel,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...opts.map((opt) {
              return RadioListTile<String>(
                value: opt,
                groupValue: answers[key],
                title: Text(opt),
                onChanged: (v) => setState(() => answers[key] = v),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  bool _validateSection(String section) {
    final keys = answers.keys; // current answers
    final requiredKeys = options.keys
        .where((k) => k.startsWith(section))
        .toList();
    for (final k in requiredKeys) {
      if (!answers.containsKey(k) ||
          answers[k] == null ||
          (answers[k] is String && (answers[k] as String).isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _submitAll() async {
    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;

    // load farmer name
    final name = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get()
        .then((doc) {
          final data = doc.data();
          if (data == null) return 'Unknown Farmer';
          final firstName = data['first_name'] ?? '';
          final lastName = data['last_name'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          return fullName.isNotEmpty ? fullName : 'Unknown Farmer';
        });

    // validation
    final missing = options.keys
        .where((k) => !answers.containsKey(k) || answers[k] == null)
        .toList();
    if (missing.isNotEmpty) {
      final snack =
          'Please answer all questions. First missing: ${missing.first}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(snack)));
      setState(() => _isSubmitting = false);
      return;
    }

    // include any open text fields
    for (final e in textControllers.entries) {
      answers[e.key] = e.value.text;
    }

    final farmerAssessment = <String, dynamic>{
      'answers': answers,
      'submitted_at':
          FieldValue.serverTimestamp(), // server will write real Timestamp
      'farmer_id': user.uid,
      'farmer_name': name,
      'farmer_email': user.email,
    };

    debugPrint('Questionnaire answers:\n${answers.toString()}');

    try {
      final assessments = FirebaseFirestore.instance.collection('assessments');
      // add() returns a DocumentReference
      final docRef = await assessments.add(farmerAssessment);

      final savedSnap = await docRef.get();
      final savedData = savedSnap.data() as Map<String, dynamic>? ?? {};

      // optionally merge id into savedData
      savedData['id'] = docRef.id;

      setState(() => _isSubmitting = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReviewPage(
            docId: docRef.id,
            answers: Map<String, dynamic>.from(answers),
            questionBank: QUESTION_BANK,
            docData: savedData,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Firestore save failed: $e');
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
  }

  // Build UI per section
  List<Widget> _sectionWidgets(String section) {
    switch (section) {
      case 'A':
        return [
          _buildRadioQuestion(
            'A1',
            'A1. When do you start preparing your farm for the mango season?',
          ),
          _buildRadioQuestion(
            'A2',
            'A2. What type of fertilizer do you use before flowering?',
          ),
          _buildRadioQuestion(
            'A3',
            'A3. Do you check your soil condition or moisture before applying fertilizer?',
          ),
          _buildRadioQuestion(
            'A4',
            'A4. How do you know when your trees are ready for flowering?',
          ),
          _buildRadioQuestion(
            'A5',
            'A5. What is your biggest problem at the start of the season?',
          ),
          _buildRadioQuestion(
            'A6',
            'A6. How often do you face unexpected rain or drought during preparation?',
          ),
          _buildRadioQuestion(
            'A7',
            'A7. Do you record your fertilizer or chemical usage?',
          ),
          _buildRadioQuestion(
            'A8',
            'A8. How do you get updates about weather for farming?',
          ),
          _buildRadioQuestion(
            'A9',
            'A9. Do you think using an app to guide farm timing would help you?',
          ),
          _buildRadioQuestion(
            'A10',
            'A10. What do you need most before flowering?',
          ),
        ];
      case 'B':
        return [
          _buildRadioQuestion(
            'B1',
            'B1. When do your mango trees usually start flowering?',
          ),
          _buildRadioQuestion(
            'B2',
            'B2. Do you use a flower inducer or let them flower naturally?',
          ),
          _buildRadioQuestion(
            'B3',
            'B3. What weather problem affects flowering the most?',
          ),
          _buildRadioQuestion(
            'B4',
            'B4. Do you often have pest problems during flowering?',
          ),
          _buildRadioQuestion(
            'B5',
            'B5. How do you control pests during this stage?',
          ),
          _buildRadioQuestion(
            'B6',
            'B6. Do you experience many fruits falling before harvest?',
          ),
          _buildRadioQuestion('B7', 'B7. What do you think causes fruit drop?'),
          _buildRadioQuestion(
            'B8',
            'B8. How often do you water or irrigate your trees during flowering?',
          ),
          _buildRadioQuestion(
            'B9',
            'B9. Do you record weather conditions during flowering?',
          ),
          _buildRadioQuestion(
            'B10',
            'B10. What help do you need most during this stage?',
          ),
        ];
      case 'C':
        return [
          _buildRadioQuestion(
            'C1',
            'C1. When do you usually start harvesting?',
          ),
          _buildRadioQuestion('C2', 'C2. Who helps you harvest?'),
          _buildRadioQuestion(
            'C3',
            'C3. How do you decide when fruits are ready to harvest?',
          ),
          _buildRadioQuestion(
            'C4',
            'C4. What weather condition often affects your harvest?',
          ),
          _buildRadioQuestion(
            'C5',
            'C5. Do you record your total harvest (number or weight)?',
          ),
          _buildRadioQuestion(
            'C6',
            'C6. How do you keep your harvested fruits?',
          ),
          _buildRadioQuestion(
            'C7',
            'C7. Do you experience fruit damage or loss during harvest?',
          ),
          _buildRadioQuestion('C8', 'C8. What causes most harvest losses?'),
          _buildRadioQuestion(
            'C9',
            'C9. Would it help if the app reminds you of ideal harvest dates?',
          ),
          _buildRadioQuestion(
            'C10',
            'C10. What support would make harvesting easier?',
          ),
        ];
      case 'D':
        return [
          _buildRadioQuestion(
            'D1',
            'D1. How do you store your mangoes after harvest?',
          ),
          _buildRadioQuestion(
            'D2',
            'D2. Do you lose fruits due to spoilage before selling?',
          ),
          _buildRadioQuestion(
            'D3',
            'D3. How do you bring mangoes to the buyer or market?',
          ),
          _buildRadioQuestion(
            'D4',
            'D4. Where do you usually sell your mangoes?',
          ),
          _buildRadioQuestion(
            'D5',
            'D5. How do you know the current market price?',
          ),
          _buildRadioQuestion(
            'D6',
            'D6. What is your biggest selling problem?',
          ),
          _buildRadioQuestion(
            'D7',
            'D7. Do you record your sales and income per harvest?',
          ),
          _buildRadioQuestion(
            'D8',
            'D8. Would you use an app that shows daily mango prices?',
          ),
          _buildRadioQuestion(
            'D9',
            'D9. How often do you face price changes during harvest time?',
          ),
          _buildRadioQuestion(
            'D10',
            'D10. What kind of app feature would help you sell better?',
          ),
        ];
      case 'E':
        return [
          _buildRadioQuestion(
            'E1',
            'E1. What is your biggest problem in mango farming right now?',
          ),
          _buildRadioQuestion(
            'E2',
            'E2. Which part of farming do you find hardest to manage?',
          ),
          _buildRadioQuestion(
            'E3',
            'E3. What do you think causes most of your farming losses?',
          ),
          _buildRadioQuestion(
            'E4',
            'E4. Where do you usually ask for help or advice when problems happen?',
          ),
          _buildRadioQuestion(
            'E5',
            'E5. What kind of help would improve your mango production the most?',
          ),
          _buildRadioQuestion(
            'E6',
            'E6. Have you received any support or training from government or organizations?',
          ),
          _buildRadioQuestion(
            'E7',
            'E7. Would you like more training about mango care and new farming methods?',
          ),
          _buildRadioQuestion(
            'E8',
            'E8. Do you think an app that gives alerts and guides could reduce your farming problems?',
          ),
          _buildRadioQuestion(
            'E9',
            'E9. What would make you trust a farming app like Sweet Insights more?',
          ),
          _buildRadioQuestion(
            'E10',
            'E10. If Sweet Insights helps you increase your income or reduce losses, would you continue using it every season?',
          ),
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final section = sections[currentSection];
    return Scaffold(
      appBar: AppBar(title: const Text('Farmers Assessment')),
      body: Stack(
        children: [
          // AbsorbPointer prevents interaction while submitting
          AbsorbPointer(
            absorbing: _isSubmitting,
            child: Opacity(
              opacity: _isSubmitting ? 0.6 : 1.0, // subtle dim while submitting
              child: Column(
                children: [
                  // Progress / section indicator
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text(
                          'Section ${section} (${currentSection + 1}/${sections.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'Please answer the questions below. All questions are required.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._sectionWidgets(section),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),

                  // Navigation buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (currentSection > 0)
                          ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => setState(() => currentSection--),
                            child: const Text('Previous'),
                          ),
                        const Spacer(),
                        if (currentSection < sections.length - 1)
                          ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () {
                                    // simple validation per section before moving forward
                                    if (!_validateSection(section)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please answer all questions in this section before continuing.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() => currentSection++);
                                  },
                            child: const Text('Next'),
                          ),
                        if (currentSection == sections.length - 1)
                          // Submit button shows spinner when submitting
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitAll,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                            child: _isSubmitting
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Submitting...'),
                                    ],
                                  )
                                : const Text('Submit'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full-screen modal progress indicator (centered)
          if (_isSubmitting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: const Center(
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(18.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 14),
                          Text(
                            'Submitting assessment...',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
