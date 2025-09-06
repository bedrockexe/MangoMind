import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class MangoDiseaseDetectorPage extends StatefulWidget {
  const MangoDiseaseDetectorPage({super.key});

  @override
  State<MangoDiseaseDetectorPage> createState() =>
      _MangoDiseaseDetectorPageState();
}

class _MangoDiseaseDetectorPageState extends State<MangoDiseaseDetectorPage> {
  final _picker = ImagePicker();
  File? _imageFile;
  bool _analyzing = false;
  _MockResult? _result;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _result = null; // clear old result when picking a new image
    });
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (xfile == null) return;
    setState(() => _imageFile = File(xfile.path));
  }

  Future<void> _analyze() async {
    if (_imageFile == null) return;
    setState(() {
      _analyzing = true;
      _result = null;
    });
    // Simulate model latency
    await Future.delayed(const Duration(milliseconds: 900));
    // Mock classifier (deterministic per file content/length)
    final res = await _MockClassifier.classify(_imageFile!);
    setState(() {
      _result = res;
      _analyzing = false;
    });
  }

  void _reset() {
    setState(() {
      _imageFile = null;
      _analyzing = false;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = GoogleFonts.poppinsTextTheme(theme.textTheme);

    Color labelColor(String label) {
      switch (label) {
        case 'Healthy':
          return Colors.green;
        case 'Anthracnose':
          return Colors.orange;
        case 'Powdery Mildew':
          return Colors.purple;
        default:
          return theme.colorScheme.primary;
      }
    }

    return Theme(
      data: theme.copyWith(textTheme: textTheme),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mango Disease Check'),
          actions: [
            if (_imageFile != null || _result != null)
              IconButton(
                tooltip: 'Reset',
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Scan a mango leaf or fruit',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Detect Anthracnose, Powdery Mildew, or a Healthy sample.\n'
                'Take a photo or upload from gallery.',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded),
                      label: const Text('Take Photo'),
                      onPressed: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Upload Photo'),
                      onPressed: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Image preview
              AspectRatio(
                aspectRatio: 1,
                child: Ink(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _imageFile == null
                        ? const _EmptyPreview()
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Analyze button / progress
              _analyzing
                  ? FilledButton.icon(
                      onPressed: null,
                      icon: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Analyzing…'),
                    )
                  : FilledButton.icon(
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Analyze'),
                      onPressed: _imageFile == null ? null : _analyze,
                    ),

              const SizedBox(height: 16),

              // Results
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _result == null
                    ? const SizedBox.shrink()
                    : _ResultPanel(
                        label: _result!.label,
                        confidence: _result!.confidence,
                        severity: _result!.severity,
                        color: labelColor(_result!.label),
                      ),
                crossFadeState: _result != null
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 16),
              const _TipsCard(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final subdued = textTheme.bodyMedium?.copyWith(
      color: textTheme.bodyMedium?.color?.withOpacity(0.8),
    );
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.image_outlined, size: 48),
          const SizedBox(height: 8),
          Text('No image selected', style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Use Take Photo or Upload to begin.',
            style: subdued,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.label,
    required this.confidence,
    required this.severity,
    required this.color,
  });

  final String label;
  final double confidence; // 0..1
  final String severity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    String description() {
      switch (label) {
        case 'Healthy':
          return 'No visible signs of disease detected.';
        case 'Anthracnose':
          return 'Dark, sunken spots that may expand; common on leaves and fruit.';
        case 'Powdery Mildew':
          return 'White powdery growth on young leaves and fruit; may cause distortion.';
        default:
          return '—';
      }
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_florist_rounded, size: 18, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: text.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.of(context).maybePop(); // optional action
                  },
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'What is this?',
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(description(), style: text.bodyMedium),

            const SizedBox(height: 12),
            const Divider(height: 1),

            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                _StatChip(
                  icon: Icons.fact_check_rounded,
                  label: 'Confidence',
                  value: '${(confidence * 100).toStringAsFixed(0)}%',
                ),
                const SizedBox(width: 10),
                _StatChip(
                  icon: Icons.bubble_chart_rounded,
                  label: 'Severity',
                  value: severity,
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text('Suggested actions', style: text.titleMedium),
            const SizedBox(height: 6),
            _Bullet(
              text: switch (label) {
                'Anthracnose' =>
                  'Prune infected parts; avoid overhead irrigation; consider copper-based fungicide per local guidance.',
                'Powdery Mildew' =>
                  'Improve airflow; remove heavily infected leaves; consider sulfur-based fungicide if allowed.',
                'Healthy' => 'Maintain good sanitation and monitor regularly.',
                _ => 'Follow local best practices for orchard hygiene.',
              },
            ),
            const _Bullet(
              text: 'Ensure clear, well-lit photos for best results.',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.labelSmall?.copyWith(
                  color: text.bodySmall?.color?.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Photo tips', style: text.titleMedium),
            const SizedBox(height: 8),
            const _Bullet(text: 'Fill the frame with the leaf or fruit.'),
            const _Bullet(text: 'Good lighting, avoid glare/shadows.'),
            const _Bullet(text: 'Keep the subject sharp and steady.'),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

/// ------------------------------
/// Mock "Classifier"
/// ------------------------------
/// This is a *deterministic* fake classifier so demo results feel stable.
/// It chooses a label by hashing file length and a few bytes, then
/// synthesizes a confidence and severity.
class _MockClassifier {
  static Future<_MockResult> classify(File file) async {
    final len = await file.length();
    final raf = await file.open();
    final bytesToRead = min<int>(64, len);
    final buf = await raf.read(bytesToRead);
    await raf.close();

    // Simple hash-like score
    int score = len % 997; // prime-ish modulus
    for (final b in buf) {
      score = (score * 31 + b) % 10007;
    }

    // Map score to label
    final labels = ['Healthy', 'Anthracnose', 'Powdery Mildew'];
    final label = labels[score % labels.length];

    // Confidence between 0.72 and 0.96
    final confidence = 0.72 + ((score % 25) / 100.0);

    // Severity buckets
    final sevIdx = (score ~/ 3) % 3;
    final severity = ['Mild', 'Moderate', 'Severe'][sevIdx];

    return _MockResult(
      label: label,
      confidence: confidence,
      severity: severity,
    );
  }
}

class _MockResult {
  final String label;
  final double confidence;
  final String severity;
  _MockResult({
    required this.label,
    required this.confidence,
    required this.severity,
  });
}
