import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:insights/pages/homepage/Home/mango_classifier.dart';

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

  Result? _result;

  // Image Picker
  Future<void> _pick(ImageSource source) async {
    setState(() {
      _result = null;
    });
    final xfile = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (xfile == null) return;
    setState(() => _imageFile = File(xfile.path));
  }

  // Image Analyzer
  Future<void> _analyze() async {
    if (_imageFile == null) return;
    setState(() {
      _analyzing = true;
      _result = null;
    });

    try {
      await MangoClassifier.load();
      final r = await MangoClassifier.classifyFile(_imageFile!);

      final prettyLabel = _prettyLabel(r.label);

      setState(() {
        _result = Result(
          label: prettyLabel,
          confidence: r.confidence,
          probs: r.probs,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  // Label Formatter
  String _prettyLabel(String raw) {
    switch (raw) {
      case 'Powdery_Mildew':
        return 'Powdery Mildew';
      case 'Healthy_Mango':
        return 'Healthy';
      case 'Not_Mango':
        return 'Not Mango';
      default:
        return raw;
    }
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
        case 'Not Mango':
          return Colors.red;
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
                'Scan a mango leaf',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Detect Anthracnose, Powdery Mildew, Healthy, or Not Mango.\n'
                'Take a photo or upload from gallery.',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
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
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.4),
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

              // Results (no severity)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _result == null
                    ? const SizedBox.shrink()
                    : _ResultPanel(
                        label: _result!.label,
                        confidence: _result!.confidence,
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
      color: textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
    required this.color,
  });

  final String label;
  final double confidence;
  final Color color;

  String _descriptionFor(String label) {
    switch (label) {
      case 'Healthy':
        return 'No visible signs of disease detected.';
      case 'Anthracnose':
        return 'Dark, sunken spots that may expand; common on leaves and fruit.';
      case 'Powdery Mildew':
        return 'White powdery growth on young leaves and fruit; may cause distortion.';
      case 'Not Mango':
        return 'This image likely isn’t a mango leaf or fruit. Please retake a clearer photo of a mango sample.';
      default:
        return '—';
    }
  }

  String _actionFor(String label) {
    switch (label) {
      case 'Anthracnose':
        return 'Prune infected parts; avoid overhead irrigation; consider copper-based fungicide per local guidance.';
      case 'Powdery Mildew':
        return 'Improve airflow; remove heavily infected leaves; consider sulfur-based fungicide if allowed.';
      case 'Healthy':
        return 'Maintain good sanitation and monitor regularly.';
      case 'Not Mango':
        return 'Retake the photo focusing on a mango leaf or fruit. Fill the frame and use good lighting.';
      default:
        return 'Follow local best practices for orchard hygiene.';
    }
  }

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
            // Title + chip
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
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
                _ConfidencePill(confidence: confidence),
              ],
            ),

            const SizedBox(height: 12),
            Text(_descriptionFor(label), style: text.bodyMedium),

            const SizedBox(height: 12),
            const Divider(height: 1),

            const SizedBox(height: 12),
            Text('Suggested actions', style: text.titleMedium),
            const SizedBox(height: 6),
            _Bullet(text: _actionFor(label)),
            const _Bullet(
              text: 'Ensure clear, well-lit photos for best results.',
            ),
          ],
        ),
      ),
    );
  }
}

// Confidence
class _ConfidencePill extends StatelessWidget {
  const _ConfidencePill({required this.confidence});
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fact_check_rounded, size: 18),
          const SizedBox(width: 8),
          Text(
            '${(confidence * 100).toStringAsFixed(0)}%',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Photo Tips
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

// Bullet Widget
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
