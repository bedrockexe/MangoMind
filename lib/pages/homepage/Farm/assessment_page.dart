import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SimpleAssessmentPage extends StatefulWidget {
  const SimpleAssessmentPage({super.key});

  @override
  State<SimpleAssessmentPage> createState() => _SimpleAssessmentPageState();
}

class _SimpleAssessmentPageState extends State<SimpleAssessmentPage>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();

  int currentIndex = 0;
  bool saving = false;
  bool showResults = false;

  // Form variables (unchanged names for Firestore)
  int numFarms = 1;
  double yieldKg = 100;
  String weatherCheck = 'sometimes';
  String pestMonitoring = 'regularly';
  String irrigationScheduling = 'regularly';
  String dataRecording = 'yes';
  String attendsTraining = 'occasionally';

  int score = 0;
  String classification = '';
  List<String> recommendations = [];

  // Visible step titles (FILIPINO — only UI text changed)
  final List<String> stepTitles = [
    'Ilang taniman ng mangga?', // Farms
    'Karaniwang ani?', // Yield
    'Tinitingnan ba ang panahon?', // Weather Awareness
    'Pagmomonitor ng peste', // Pest Monitoring
    'Irigasyon', // Irrigation
    'Pag-record ng datos', // Data Recording
    'Pagsasanay', // Training
  ];

  final int totalSteps = 7;

  // Animation controller used for small button animations
  late final AnimationController _btnAnimController;

  @override
  void initState() {
    super.initState();
    _btnAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _btnAnimController.dispose();
    super.dispose();
  }

  // ---------- Scoring logic (kept the same) ----------
  void computeScoreAndRecommendations() {
    int s = 0;
    List<String> recs = [];

    // 1. Number of farms (10)
    s += (numFarms >= 2) ? 10 : 5;

    // 2. Yield (20)
    if (yieldKg > 500) {
      s += 20;
    } else if (yieldKg >= 100)
      s += 10;
    else
      s += 5;

    // 3. Weather check (15)
    if (weatherCheck == 'always') {
      s += 15;
    } else if (weatherCheck == 'sometimes')
      s += 10;

    // 4. Pest monitoring (15)
    if (pestMonitoring == 'regularly') {
      s += 15;
    } else if (pestMonitoring == 'sometimes')
      s += 10;

    // 5. Irrigation scheduling (15)
    if (irrigationScheduling == 'regularly') {
      s += 15;
    } else if (irrigationScheduling == 'occasionally')
      s += 10;

    // 6. Data recording (10)
    if (dataRecording == 'yes') {
      s += 10;
    } else if (dataRecording == 'sometimes')
      s += 5;

    // 7. Training attendance (15)
    if (attendsTraining == 'regularly') {
      s += 15;
    } else if (attendsTraining == 'occasionally')
      s += 10;

    // Classification
    String cls;
    if (s >= 80) {
      cls = 'Excellent';
    } else if (s >= 60)
      cls = 'Good';
    else
      cls = 'Low';

    // Recommendations (FILIPINO messages shown to user)
    if (weatherCheck != 'always') {
      recs.add('Tingnan nang regular ang weather forecast.');
    }
    if (pestMonitoring != 'regularly') {
      recs.add('Dagdagan ang monitoring ng peste.');
    }
    if (dataRecording != 'yes') {
      recs.add('Sisimulan ang pag-record ng farm data.');
    }
    if (attendsTraining != 'regularly') {
      recs.add('Sumali sa mas maraming training at seminar.');
    }

    setState(() {
      score = s;
      classification = cls;
      recommendations = recs.take(3).toList();
    });
  }

  // ---------- Firestore save (unchanged schema keys) ----------
  Future<void> saveAssessment() async {
    // validate numeric field (yield)
    if (yieldKg <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid yield value.')),
      );
      return;
    }

    computeScoreAndRecommendations();
    setState(() => saving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get()
        .then((doc) {
          final data = doc.data();
          if (data == null) return 'Unknown Farmer';
          final firstName = data['first_name'] ?? '';
          final lastName = data['last_name'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          return fullName.isNotEmpty ? fullName : 'Unknown Farmer';
        });

    final doc = FirebaseFirestore.instance.collection('assessments').doc();

    await doc.set({
      'assessmentId': doc.id,
      'farmerId': uid,
      'farmerName': name,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'answers': {
        'numFarms': numFarms,
        'yieldKg': yieldKg,
        'weatherCheck': weatherCheck,
        'pestMonitoring': pestMonitoring,
        'irrigationScheduling': irrigationScheduling,
        'dataRecording': dataRecording,
        'attendsTraining': attendsTraining,
      },
      'score': score,
      'classification': classification,
      'recommendations': recommendations,
    });

    setState(() {
      saving = false;
      showResults = true;
    });
  }

  // ---------- Page navigation ----------
  void _nextPage() {
    if (currentIndex < totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------- UI pieces ----------
  Widget _stepHeader(BuildContext context) {
    final theme = Theme.of(context);
    final double progress = (currentIndex + 1) / totalSteps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stepTitles[currentIndex],
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${((progress) * 100).toInt()}%',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _numberStepper() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Ilang taniman ang inaasikaso mo?'),
      const SizedBox(height: 8),
      TextFormField(
        initialValue: numFarms.toString(),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: 'Hal. 1',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null && parsed >= 1 && parsed <= 100) {
            setState(() => numFarms = parsed);
          }
        },
        validator: (v) {
          if (v == null || v.isEmpty) return 'Kailangan ng value';
          final parsed = int.tryParse(v);
          if (parsed == null || parsed < 1 || parsed > 100) return 'Invalid number (1-100)';
          return null;
        },
      ),
      const SizedBox(height: 8),
      Text('You entered: $numFarms farms'),
    ],
  );
}

  Widget _yieldInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ilagay ang karaniwang ani ng mangga (sa kg):'),
        const SizedBox(height: 8),
        Form(
          key: _formKey,
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: yieldKg.toInt().toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: false,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Hal. 250',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) setState(() => yieldKg = parsed);
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Kailangan ng value';
                    final parsed = double.tryParse(v);
                    if (parsed == null || parsed <= 0) return 'Invalid number';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  setState(() => yieldKg = 100);
                },
                child: const Text('100kg'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => setState(() => yieldKg = 500),
                child: const Text('500kg'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('You entered: ${yieldKg.toInt()} kg'),
      ],
    );
  }

  Widget _optionCard({
    required String label,
    required String subtitle,
    required List<Map<String, String>> options,
    required String currentValue,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
        child: Column(
          children: [
            ListTile(
              title: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(subtitle),
            ),
            const Divider(),
            ...options.map((o) {
              final v = o['value']!;
              final t = o['text']!;
              // each option wrapped in AnimatedSwitcher for subtle transition
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) =>
                    SizeTransition(sizeFactor: anim, child: child),
                child: RadioListTile<String>(
                  key: ValueKey('$currentValue-$v'),
                  value: v,
                  groupValue: currentValue,
                  title: Text(t),
                  onChanged: (val) {
                    onChanged(val);
                    // tiny visual feedback
                    _btnAnimController.reverse().then(
                      (_) => _btnAnimController.forward(),
                    );
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(int index) {
    switch (index) {
      case 0:
        return Column(
          children: [
            const SizedBox(height: 8),
            const Text('Ilang taniman ang inaasikaso mo?'),
            const SizedBox(height: 16),
            _numberStepper(),
          ],
        );
      case 1:
        return _yieldInput();
      case 2:
        return _optionCard(
          label: 'Tinitingnan mo ba lagi ang weather forecast?',
          subtitle: 'Makakatulong ito sa pag-spray at pag-ani',
          options: [
            {'value': 'never', 'text': 'Hindi kailanman'},
            {'value': 'sometimes', 'text': 'Minsan lang / Paminsan-minsan'},
            {'value': 'always', 'text': 'Oo, regular'},
          ],
          currentValue: weatherCheck,
          onChanged: (v) => setState(() => weatherCheck = v ?? weatherCheck),
        );
      case 3:
        return _optionCard(
          label: 'Gaano ka kadalas mag-monitor ng peste?',
          subtitle: 'Importanteng malaman agad kapag may outbreak',
          options: [
            {'value': 'rarely', 'text': 'Bihira'},
            {'value': 'sometimes', 'text': 'Paminsan-minsan'},
            {'value': 'regularly', 'text': 'Regular / Weekly'},
          ],
          currentValue: pestMonitoring,
          onChanged: (v) =>
              setState(() => pestMonitoring = v ?? pestMonitoring),
        );
      case 4:
        return _optionCard(
          label: 'May maayos ka bang irrigation scheduling?',
          subtitle: 'Nakakatulong sa water efficiency',
          options: [
            {'value': 'none', 'text': 'Wala'},
            {'value': 'occasionally', 'text': 'Paminsan-minsan lang'},
            {'value': 'regularly', 'text': 'Oo, may schedule'},
          ],
          currentValue: irrigationScheduling,
          onChanged: (v) =>
              setState(() => irrigationScheduling = v ?? irrigationScheduling),
        );
      case 5:
        return _optionCard(
          label: 'Nirerecord mo ba ang iyong farm data (ani, peste, pataba)?',
          subtitle: 'Mahalaga para sa analysis at improvements',
          options: [
            {'value': 'no', 'text': 'Hindi'},
            {'value': 'sometimes', 'text': 'Minsan lang'},
            {'value': 'yes', 'text': 'Oo, regular'},
          ],
          currentValue: dataRecording,
          onChanged: (v) => setState(() => dataRecording = v ?? dataRecording),
        );
      case 6:
        return _optionCard(
          label: 'Sumasali ka ba sa farming trainings o seminar?',
          subtitle: 'Pinapabuti nito ang kaalaman sa modernong practices',
          options: [
            {'value': 'never', 'text': 'Hindi kailanman'},
            {'value': 'occasionally', 'text': 'Paminsan-minsan'},
            {'value': 'regularly', 'text': 'Oo, regular'},
          ],
          currentValue: attendsTraining,
          onChanged: (v) =>
              setState(() => attendsTraining = v ?? attendsTraining),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------- Animated results view with ring ----------
  Widget _resultsView(BuildContext context) {
    final theme = Theme.of(context);
    final int pct = (score).clamp(0, 100);
    Color clsColor = Colors.orange;
    if (classification == 'Excellent') clsColor = Colors.green;
    if (classification == 'Needs Improvement') clsColor = Colors.red;

    // The animated ring value (0..1)
    final double target = pct / 100.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Animated ring using TweenAnimationBuilder
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: target),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              final display = (value * 100).toInt();
              return Column(
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background circle
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: 1,
                            strokeWidth: 14,
                            color: theme.colorScheme.surfaceVariant,
                          ),
                        ),
                        // Animated progress
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 14,
                            valueColor: AlwaysStoppedAnimation<Color>(clsColor),
                          ),
                        ),
                        // Center text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$display',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('/100', style: theme.textTheme.titleMedium),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: value > 0.02 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 400),
                    child: Chip(
                      label: Text(
                        classification,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: clsColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Recommendations with small animated entrance
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: recommendations.isEmpty
                ? Text(
                    'Walang specific recommendation.',
                    key: const ValueKey('empty'),
                  )
                : Column(
                    key: ValueKey(recommendations.join(',')),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Recommendations',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...recommendations.map((r) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: clsColor.withOpacity(0.2),
                              child: Icon(
                                Icons.lightbulb_outline,
                                color: clsColor,
                              ),
                            ),
                            title: Text(r),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          // Raw answers saved to DB (informational)
          // Card(
          //   color: Colors.grey.shade50,
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Padding(
          //     padding: const EdgeInsets.all(12.0),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Text(
          //           'Raw answers (saved to DB):',
          //           style: theme.textTheme.bodyMedium,
          //         ),
          //         const SizedBox(height: 8),
          //         Text('numFarms: $numFarms'),
          //         Text('yieldKg: ${yieldKg.toInt()}'),
          //         Text('weatherCheck: $weatherCheck'),
          //         Text('pestMonitoring: $pestMonitoring'),
          //         Text('irrigationScheduling: $irrigationScheduling'),
          //         Text('dataRecording: $dataRecording'),
          //         Text('attendsTraining: $attendsTraining'),
          //       ],
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // restart
              setState(() {
                showResults = false;
                currentIndex = 0;
                numFarms = 1;
                yieldKg = 100;
                weatherCheck = 'sometimes';
                pestMonitoring = 'regularly';
                irrigationScheduling = 'regularly';
                dataRecording = 'yes';
                attendsTraining = 'occasionally';
                score = 0;
                classification = '';
                recommendations = [];
              });
              _pageController.jumpToPage(0);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Gumawa ng bagong assessment'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Build ----------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          showResults ? 'Resulta ng Assessment' : stepTitles[currentIndex],
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: showResults
            ? _resultsView(context)
            : Column(
                key: const ValueKey('formView'),
                children: [
                  _stepHeader(context),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: totalSteps,
                      onPageChanged: (i) => setState(() => currentIndex = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: _buildStepContent(i),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (i == 1)
                                const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'Tip: Kung hindi sigurado, mag-estimate base sa huling harvest.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          if (currentIndex > 0)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _prevPage,
                                icon: const Icon(Icons.arrow_back_ios),
                                label: const Text('Bago'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          if (currentIndex > 0) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: saving
                                  ? null
                                  : (currentIndex < totalSteps - 1
                                        ? _nextPage
                                        : () async {
                                            // validate form (yield input)
                                            if (currentIndex == 1) {
                                              if (!_formKey.currentState!
                                                  .validate()) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Pakiayos ang value ng ani.',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                            }
                                            await saveAssessment();
                                          }),
                              icon: saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward_ios),
                              label: Text(
                                saving
                                    ? 'Saving...'
                                    : (currentIndex < totalSteps - 1
                                          ? 'Susunod'
                                          : 'I-save'),
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
