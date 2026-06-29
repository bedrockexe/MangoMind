// my_submissions.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:insights/theme/skeletons.dart';
import 'package:intl/intl.dart';
import 'assessment_review.dart';

class MySubmissionsPage extends StatelessWidget {
  const MySubmissionsPage({super.key});

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
    'E9': 'What would make you trust a farming app like MangoMind more?',
    'E10':
        'If MangoMind helps you increase your income or reduce losses, would you continue using it every season?',
  };

  Stream<QuerySnapshot> _myStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('assessments')
          .where('farmer_id', isEqualTo: user.uid)
          .orderBy('submitted_at', descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection('assessments')
          .orderBy('submitted_at', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Submissions')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _myStream(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) {
            return const ListSkeleton();
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No submissions yet.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data() as Map<String, dynamic>;
              final submittedAt = data['submitted_at'] as Timestamp?;
              final dt = submittedAt != null
                  ? DateFormat.yMMMd().add_jm().format(submittedAt.toDate())
                  : 'Not submitted';
              return ListTile(
                title: Text(data['farmer_name'] ?? 'Submission ${d.id}'),
                subtitle: Text(dt),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReviewPage(
                        docId: d.id,
                        answers: data['answers'],
                        questionBank: QUESTION_BANK,
                        docData: data,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
