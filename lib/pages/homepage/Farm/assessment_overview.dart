import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assessment_history.dart';
import 'assessment_page.dart';

class AssessmentOverviewPage extends StatelessWidget {
  const AssessmentOverviewPage({super.key});

  Future<Map<String, dynamic>?> _fetchLatestAssessment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance
        .collection('assessments')
        .where('farmerId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2E7D32);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom + 12.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Assessment Overview',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: accent,
        elevation: 0,
      ),
      // Body is scrollable and responsive
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomPadding + 64),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'assessment-hero',
                            child: Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.eco,
                                color: accent,
                                size: 34,
                              ),
                            ),
                          ),

                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Farmer Assessment',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'A short questionnaire to evaluate farm readiness and produce practical recommendations.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: accent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              SimpleAssessmentPage(),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      label: const Text(
                                        'Start',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder:
                                              (
                                                BuildContext dialogContext,
                                              ) => AlertDialog(
                                                title: const Text(
                                                  'About this assessment',
                                                ),
                                                content: const Text(
                                                  'This quick questionnaire helps generate practical, recommendations for your farm.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                        ),
                                                    child: const Text('OK'),
                                                  ),
                                                ],
                                              ),
                                        );
                                      },
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('Why this?'),
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

                  const SizedBox(height: 14),

                  isWide
                      ? Row(
                          children: [
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.timer,
                                title: 'Estimated time',
                                subtitle: '~ 5 - 10 minutes',
                                color: accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _InfoTile(
                                icon: Icons.list_alt,
                                title: 'Questions',
                                subtitle: '7 short steps',
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _InfoTile(
                              icon: Icons.timer,
                              title: 'Estimated time',
                              subtitle: '~ 5 - 10 minutes',
                              color: accent,
                            ),
                            const SizedBox(height: 12),
                            _InfoTile(
                              icon: Icons.list_alt,
                              title: 'Questions',
                              subtitle: '8 short steps',
                              color: Colors.orange,
                            ),
                          ],
                        ),

                  const SizedBox(height: 14),

                  // What we will ask
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'What we will ask',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 10),
                          _BulletText('Farm number'),
                          _BulletText('Average yield per harvest'),
                          _BulletText('Weather forecast awareness'),
                          _BulletText('Pest Monitoring'),
                          _BulletText('Irrigation practices'),
                          _BulletText('Data Record Keeping'),
                          _BulletText('Training and Education'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Latest assessment preview
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: FutureBuilder<Map<String, dynamic>?>(
                        future: _fetchLatestAssessment(),
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading latest assessment...'),
                                ],
                              ),
                            );
                          }
                          final data = snap.data;
                          if (data == null) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No previous assessment',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'You haven\'t completed an assessment yet. Start now to get recommendations and track progress over time.',
                                  style: TextStyle(color: Colors.black54),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => SimpleAssessmentPage(),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.play_circle,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Start first assessment',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          final int score = (data['score'] is int)
                              ? data['score']
                              : int.tryParse('${data['score']}') ?? 0;
                          final String classif =
                              data['classification'] ??
                              (score <= 40
                                  ? 'Low'
                                  : (score <= 70 ? 'Medium' : 'High'));
                          final String timestamp = (data['timestamp'] ?? '')
                              .toString();
                          final List recs = data['recommendations'] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // score circle
                                  SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Transform.scale(
                                          scale: 2.0,
                                          child: CircularProgressIndicator(
                                            value: (score / 100).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            strokeWidth: 8,
                                            valueColor: AlwaysStoppedAnimation(
                                              classif == 'High'
                                                  ? Colors.green
                                                  : (classif == 'Good'
                                                        ? Colors.orange
                                                        : Colors.redAccent),
                                            ),
                                            backgroundColor:
                                                Colors.grey.shade200,
                                          ),
                                        ),

                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$score',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              classif,
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Last assessment: ${timestamp.isNotEmpty ? timestamp.split('T').first : 'Unknown'}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Top recommendation:',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        if (recs.isEmpty)
                                          const Text(
                                            '—',
                                            style: TextStyle(
                                              color: Colors.black54,
                                            ),
                                          )
                                        else
                                          Text(
                                            '- ${recs.first}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      SimpleAssessmentPage(),
                                                ),
                                              ),
                                              icon: const Icon(Icons.replay),
                                              label: const Text('Re-take'),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      AssessmentHistoryPage(),
                                                ),
                                              ),
                                              icon: const Icon(Icons.history),
                                              label: const Text('History'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Full recommendations:',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (recs.isEmpty)
                                const Text(
                                  'No recommendations found.',
                                  style: TextStyle(color: Colors.black54),
                                )
                              else
                                ...recs
                                    .map(
                                      (r) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.circle,
                                              size: 8,
                                              color: Colors.black54,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text('$r')),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Big start button (ensures not overlapped by bottom nav)
                  Center(
                    child: SizedBox(
                      width: isWide ? 360 : double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SimpleAssessmentPage(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Start Assessment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// small helper widgets used above
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, size: 14, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
