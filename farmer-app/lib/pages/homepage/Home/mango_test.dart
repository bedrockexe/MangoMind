// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:insights/theme/transitions.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:insights/pages/services/tflite_service.dart';

class MangoDetector extends StatefulWidget {
  const MangoDetector({super.key});
  @override
  State<MangoDetector> createState() => _MangoDetectorState();
}

class _MangoDetectorState extends State<MangoDetector> {
  List<CameraDescription>? _cameras;
  bool _loadingCameras = true;
  String? _cameraError;

  Future<void> _initializeCameras() async {
    try {
      final cams = await availableCameras();
      if (!mounted) return;
      setState(() {
        _cameras = cams;
        _loadingCameras = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera unavailable: $e';
        _loadingCameras = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  void _openCamera() {
    final cams = _cameras;
    if (cams == null || cams.isEmpty) return;
    Navigator.of(context).push(appRoute(CameraScanPage(cameras: cams)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cameraReady = _cameras != null && _cameras!.isNotEmpty;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Mango Scanner'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surface, scheme.surfaceContainerHighest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space5,
              AppTheme.space2,
              AppTheme.space5,
              AppTheme.space5,
            ),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glowing mango disc — the focal point of the screen.
                      Hero(
                            tag: 'mango-logo',
                            child: Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFD473), Color(0xFFFFB347)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFB347,
                                    ).withValues(alpha: 0.4),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.center_focus_strong,
                                  size: 72,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.04, 1.04),
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          ),
                      const SizedBox(height: AppTheme.space5),
                      Text(
                        'Scan your mango',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        'Point your camera at a mango leaf or fruit for an '
                        'instant disease and ripeness reading — powered by '
                        'on-device camera & AI.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 400.ms),
                ),

                // For-best-results tips.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.tips_and_updates_outlined,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'For best results',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space2),
                      _tipRow(
                        context,
                        Icons.wb_sunny_outlined,
                        'Use bright, even daylight',
                      ),
                      _tipRow(
                        context,
                        Icons.center_focus_weak,
                        'Keep a single leaf or fruit in frame',
                      ),
                      _tipRow(
                        context,
                        Icons.blur_off,
                        'Avoid blur and busy backgrounds',
                      ),
                    ],
                  ),
                ),

                if (_cameraError != null) ...[
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    _cameraError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: AppTheme.space4),
                SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        // Disabled until cameras have loaded, preventing a
                        // LateInitializationError if tapped too early.
                        onPressed: cameraReady ? _openCamera : null,
                        icon: _loadingCameras
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.camera_alt_outlined),
                        label: Text(
                          _loadingCameras ? 'Preparing camera…' : 'Scan now',
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tipRow(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// -------------------
/// Camera Scan Page
/// -------------------
class CameraScanPage extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScanPage({super.key, required this.cameras});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isReady = false;
  bool _scanning = false;
  late AnimationController _scanLineController;
  final Duration minScanDuration = const Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: false);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cam = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => widget.cameras.first,
    );
    _controller = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _isReady = true);
    } catch (e) {
      // handle camera errors gracefully
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _startScanAndCapture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _scanning = true);

    // Ensure we show scanning animation at least minScanDuration
    final start = DateTime.now();

    // wait a tiny moment so animation is visible
    await Future.delayed(const Duration(milliseconds: 200));

    // capture to temporary file
    final XFile raw = await _controller!.takePicture();

    final elapsed = DateTime.now().difference(start);
    if (elapsed < minScanDuration) {
      await Future.delayed(minScanDuration - elapsed);
    }

    // pass to analysis page
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      appRoute(DetectionLoadingPage(imageFile: File(raw.path))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isReady && _controller != null
            ? Stack(
                children: [
                  CameraPreview(_controller!),
                  // dark overlay vignette
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                      ),
                    ),
                  ),
                  // scanning frame
                  Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.86,
                      height:
                          MediaQuery.of(context).size.width * 0.86 * (4 / 3),
                      child: Stack(
                        children: [
                          // rounded frame
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 3,
                              ),
                            ),
                          ),
                          // moving scan line
                          AnimatedBuilder(
                            animation: _scanLineController,
                            builder: (context, child) {
                              final t = _scanLineController.value;
                              final top =
                                  t *
                                  (MediaQuery.of(context).size.width *
                                          0.86 *
                                          (4 / 3) -
                                      6);
                              return Positioned(
                                top: top,
                                left: 0,
                                right: 0,
                                child: Opacity(
                                  opacity: 0.9,
                                  child: Container(
                                    height: 4,
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.greenAccent,
                                          Colors.white70,
                                          Colors.greenAccent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // pulsing center ring
                          Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 600),
                              opacity: _scanning ? 0.6 : 1.0,
                              child: SizedBox(
                                width: 92,
                                height: 92,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.9, end: 1.2),
                                      duration: const Duration(
                                        milliseconds: 900,
                                      ),
                                      curve: Curves.easeInOut,
                                      builder: (context, scale, child) =>
                                          Transform.scale(
                                            scale: scale,
                                            child: child,
                                          ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 
                                              0.9,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.center_focus_strong,
                                      size: 36,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // top bar
                  Positioned(
                    top: 18,
                    left: 16,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // bottom controls
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _scanning
                                ? Theme.of(context).colorScheme.outline
                                : Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _scanning ? null : _startScanAndCapture,
                          child: _scanning
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('Scanning...'),
                                  ],
                                )
                              : const Text('Scan now'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Align fruit or leaf inside the frame',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// -------------------
/// Detection + Loading Page (performs AI call)
/// -------------------
class DetectionLoadingPage extends StatefulWidget {
  final File imageFile;
  const DetectionLoadingPage({super.key, required this.imageFile});

  @override
  State<DetectionLoadingPage> createState() => _DetectionLoadingPageState();
}

class _DetectionLoadingPageState extends State<DetectionLoadingPage>
    with SingleTickerProviderStateMixin {
  String _error = '';
  bool _done = false;

  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _analyze();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    try {
      final String prompt = '''
SYSTEM: You are an expert plant pathologist and fruit quality specialist. ALWAYS RETURN ONLY A SINGLE VALID JSON OBJECT matching the schema exactly (no extra keys, no commentary, no markdown, no code fences, no emojis, nothing else). If any value cannot be determined confidently, follow the "UNSURE" rules in the schema. DO NOT produce any natural language outside the JSON.

ROLE: Mango detector + disease & ripeness reporter.

TASK: Analyze the attached photo. Determine:
  1) object_type: one of ["Leaf","Fruit","Other"]
  2) is_mango: true/false
  3) If is_mango and object_type == "Leaf": diagnose disease (one of ["Healthy","Anthracnose","PowderyMildew","BacterialSpot","OtherPestDamage"]) or "UNSURE".
  4) If is_mango and object_type == "Fruit": diagnose fruit disease (same label set) or "UNSURE", and predict ripeness as a percentage and a ripeness_stage.
  5) If not a mango (is_mango == false): provide up to 3 short photo_tips for retaking a mango-identifiable photo.

OUTPUT: Return exactly this JSON object and nothing else. All keys must exist exactly as shown. Use the specified value formats.

JSON SCHEMA:
{
  "object_type": "<string>",            // "Leaf" | "Fruit" | "Other"
  "is_mango": <boolean>,
  "disease_label": "<string>",          // one of allowed disease labels or "UNSURE"
  "disease_confidence": <float>,        // 0.00 - 1.00 (two decimals)
  "fruit_ripeness_pct": <float>,        // 0.00 - 100.00 (two decimals). If not applicable set 0.00
  "ripeness_stage": "<string>",         // "Unripe" | "SlightlyRipe" | "Ripe" | "Overripe" | "UNSURE"
  "recommendations": ["<string>",...],  // array of 0-3 short remediation tips (each <= 20 words)
  "photo_tips": ["<string>",...],       // array of 0-3 short tips for taking photo (each <= 12 words)
  "bounding_boxes": [                   // may be empty array; boxes in image pixels ints
     {"x":<int>,"y":<int>,"w":<int>,"h":<int>,"region_confidence":<float>}
  ],
  "explainers": ["<string>",...],       // 0-2 short factual reasons (<=12 words each)
  "overall_confidence": <float>,        // 0.00 - 1.00 (two decimals) combined confidence
  "timestamp_utc": "<YYYY-MM-DDThh:mm:ssZ>"
}

CONFIDENCE_THRESHOLD: 0.85

END: Process the attached image and return the JSON object only.
''';

      final bytes = await widget.imageFile.readAsBytes();

      final encodedImage = base64Encode(bytes);

      final callable = FirebaseFunctions.instance.httpsCallable(
        'imageAnalyzer',
      );

      final result = await callable.call({
        'prompt': prompt,
        'imageBase64': encodedImage,
      });

      final data = result.data['text'];
      final datafinal = data.replaceAll(RegExp(r'```json|```'), '');

      final parsed = _safeParseAndValidateJson(datafinal);

      setState(() => _done = true);

      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        appRoute(
          DetectionResultPage(parsed: parsed, imageFile: widget.imageFile),
        ),
      );
    } catch (e) {
      // Cloud (Gemini) analysis failed — fall back to the on-device model so
      // the farmer still gets a (limited) result while offline.
      try {
        final tfl = await TfliteService.instance.classify(widget.imageFile);
        final parsed = _fallbackParsedFromTflite(tfl);
        if (!mounted) return;
        setState(() => _done = true);
        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          appRoute(
            DetectionResultPage(
              parsed: parsed,
              imageFile: widget.imageFile,
              usedFallback: true,
            ),
          ),
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = 'Analysis error: $e';
          _done = true;
        });
      }
    }
  }

  /// Maps a 4-class on-device classification into the same result schema the
  /// Gemini path produces, so [DetectionResultPage] can render it unchanged.
  /// The model only knows disease/identity, so ripeness, bounding boxes and
  /// explainers are left empty and the result is flagged as a fallback.
  Map<String, dynamic> _fallbackParsedFromTflite(TfliteResult r) {
    final ts = DateFormat(
      "yyyy-MM-ddTHH:mm:ss'Z'",
    ).format(DateTime.now().toUtc());

    final isMango = r.label != 'Not_Mango';
    String diseaseLabel;
    switch (r.label) {
      case 'Anthracnose':
        diseaseLabel = 'Anthracnose';
        break;
      case 'Powdery_Mildew':
        diseaseLabel = 'PowderyMildew';
        break;
      default: // Healthy_Mango or Not_Mango
        diseaseLabel = 'Healthy';
    }

    final recs = <String>[];
    if (diseaseLabel == 'Anthracnose') {
      recs.addAll([
        'Prune and destroy infected leaves and twigs.',
        'Apply a copper-based or mancozeb fungicide.',
        'Improve airflow and avoid overhead watering.',
      ]);
    } else if (diseaseLabel == 'PowderyMildew') {
      recs.addAll([
        'Apply a sulfur or potassium-bicarbonate fungicide.',
        'Remove severely infected panicles and leaves.',
        'Ensure good sunlight and spacing between trees.',
      ]);
    }

    final conf = (r.confidence * 100).roundToDouble() / 100.0;
    return {
      "object_type": isMango ? "Leaf" : "Other",
      "is_mango": isMango,
      "disease_label": diseaseLabel,
      "disease_confidence": conf,
      "fruit_ripeness_pct": 0.00,
      "ripeness_stage": "UNSURE",
      "recommendations": recs,
      "photo_tips": isMango
          ? <String>[]
          : <String>[
              "Center the mango leaf or fruit in frame",
              "Use bright, even daylight",
              "Avoid blur and busy backgrounds",
            ],
      "bounding_boxes": <Map<String, dynamic>>[],
      "explainers": <String>[],
      "overall_confidence": conf,
      "timestamp_utc": ts,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween(begin: 1.0, end: 1.08).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.12),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 56,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _done ? 'Processing complete' : 'Scanning and analyzing...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (!_done)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: LinearProgressIndicator(),
                ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _error,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _safeParseAndValidateJson(String rawText) {
    Map<String, dynamic> unsureFallback() {
      final ts = DateFormat(
        "yyyy-MM-ddTHH:mm:ss'Z'",
      ).format(DateTime.now().toUtc());
      return {
        "object_type": "Other",
        "is_mango": false,
        "disease_label": "UNSURE",
        "disease_confidence": 0.00,
        "fruit_ripeness_pct": 0.00,
        "ripeness_stage": "UNSURE",
        "recommendations": [],
        "photo_tips": [
          "Center mango in frame",
          "Ensure bright daylight",
          "Include leaf and fruit together",
        ],
        "bounding_boxes": [],
        "explainers": [],
        "overall_confidence": 0.00,
        "timestamp_utc": ts,
      };
    }

    if (rawText.trim().isEmpty) return unsureFallback();

    dynamic decoded;
    try {
      decoded = json.decode(rawText);
    } catch (_) {
      final start = rawText.indexOf('{');
      final end = rawText.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        try {
          decoded = json.decode(rawText.substring(start, end + 1));
        } catch (_) {
          return unsureFallback();
        }
      } else {
        return unsureFallback();
      }
    }

    if (decoded is! Map<String, dynamic>) return unsureFallback();
    final Map<String, dynamic> m = Map<String, dynamic>.from(decoded);

    final requiredKeys = [
      "object_type",
      "is_mango",
      "disease_label",
      "disease_confidence",
      "fruit_ripeness_pct",
      "ripeness_stage",
      "recommendations",
      "photo_tips",
      "bounding_boxes",
      "explainers",
      "overall_confidence",
      "timestamp_utc",
    ];
    for (final k in requiredKeys) {
      if (!m.containsKey(k)) return unsureFallback();
    }

    final objectType = m["object_type"];
    if (objectType is! String ||
        !["Leaf", "Fruit", "Other"].contains(objectType)) {
      return unsureFallback();
    }

    final isMango = m["is_mango"];
    if (isMango is! bool) return unsureFallback();

    final diseaseLabel = m["disease_label"];
    const allowedDiseases = [
      "Healthy",
      "Anthracnose",
      "PowderyMildew",
      "BacterialSpot",
      "OtherPestDamage",
      "UNSURE",
    ];
    if (diseaseLabel is! String || !allowedDiseases.contains(diseaseLabel)) {
      return unsureFallback();
    }

    double diseaseConfidence;
    try {
      diseaseConfidence = _toDoubleInRange(m["disease_confidence"], 0.0, 1.0);
    } catch (_) {
      return unsureFallback();
    }

    double fruitRipeness;
    try {
      fruitRipeness = _toDoubleInRange(m["fruit_ripeness_pct"], 0.0, 100.0);
    } catch (_) {
      return unsureFallback();
    }

    final ripenessStage = m["ripeness_stage"];
    const allowedRipeness = [
      "Unripe",
      "SlightlyRipe",
      "Ripe",
      "Overripe",
      "UNSURE",
    ];
    if (ripenessStage is! String || !allowedRipeness.contains(ripenessStage)) {
      return unsureFallback();
    }

    List<String> recommendations = _toStringList(m["recommendations"]);
    List<String> photoTips = _toStringList(m["photo_tips"]);

    List<dynamic> boxesRaw = m["bounding_boxes"];
    List<Map<String, dynamic>> boxes = [];
    if (boxesRaw is List) {
      for (final b in boxesRaw) {
        if (b is Map<String, dynamic>) {
          try {
            final x = (b["x"] is int) ? b["x"] : int.parse(b["x"].toString());
            final y = (b["y"] is int) ? b["y"] : int.parse(b["y"].toString());
            final w = (b["w"] is int) ? b["w"] : int.parse(b["w"].toString());
            final h = (b["h"] is int) ? b["h"] : int.parse(b["h"].toString());
            final regionConf = _toDoubleInRange(
              b["region_confidence"],
              0.0,
              1.0,
            );
            boxes.add({
              "x": x,
              "y": y,
              "w": w,
              "h": h,
              "region_confidence": (regionConf * 100).roundToDouble() / 100.0,
            });
          } catch (_) {}
        }
      }
    }

    List<String> explainers = _toStringList(m["explainers"]);
    double overallConf;
    try {
      overallConf = _toDoubleInRange(m["overall_confidence"], 0.0, 1.0);
    } catch (_) {
      return unsureFallback();
    }

    String timestamp = m["timestamp_utc"] is String ? m["timestamp_utc"] : '';
    try {
      DateTime.parse(timestamp);
    } catch (_) {
      timestamp = DateFormat(
        "yyyy-MM-ddTHH:mm:ss'Z'",
      ).format(DateTime.now().toUtc());
    }

    return {
      "object_type": objectType,
      "is_mango": isMango,
      "disease_label": diseaseLabel,
      "disease_confidence": ((diseaseConfidence * 100).roundToDouble() / 100.0),
      "fruit_ripeness_pct": ((fruitRipeness * 100).roundToDouble() / 100.0),
      "ripeness_stage": ripenessStage,
      "recommendations": recommendations.take(3).toList(),
      "photo_tips": photoTips.take(3).toList(),
      "bounding_boxes": boxes,
      "explainers": explainers.take(2).toList(),
      "overall_confidence": ((overallConf * 100).roundToDouble() / 100.0),
      "timestamp_utc": timestamp,
    };
  }

  double _toDoubleInRange(dynamic v, double min, double max) {
    if (v is double) {
      if (v.isNaN) throw Exception('NaN');
      if (v < min || v > max) throw Exception('out of range');
      return v;
    }
    if (v is int) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(v);
      if (parsed == null) throw Exception('not double');
      if (parsed < min || parsed > max) throw Exception('out of range');
      return parsed;
    }
    throw Exception('invalid type for double');
  }

  List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// -------------------
/// Detection Result Page (beautiful UI + icons + animations)
/// -------------------
class DetectionResultPage extends StatelessWidget {
  final Map<String, dynamic> parsed;
  final File imageFile;

  /// True when this result came from the on-device model because the Gemini
  /// cloud analysis was unavailable. Shows a notice and a simplified report.
  final bool usedFallback;

  const DetectionResultPage({
    super.key,
    required this.parsed,
    required this.imageFile,
    this.usedFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMango = parsed['is_mango'] as bool;
    final objectType = parsed['object_type'] as String;
    final disease = parsed['disease_label'] as String;
    final ripeness = (parsed['fruit_ripeness_pct'] as num).toDouble();
    final ripenessStage = parsed['ripeness_stage'] as String;
    final recs = List<String>.from(parsed['recommendations'] as List);
    final tips = List<String>.from(parsed['photo_tips'] as List);
    final explainers = List<String>.from(parsed['explainers'] as List);

    final hasDisease =
        disease != 'Healthy' && disease.toUpperCase() != 'UNSURE';
    final displayDisease = (disease.toUpperCase() == 'UNSURE')
        ? 'Healthy'
        : disease;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (usedFallback) ...[
            _fallbackBanner(context),
            const SizedBox(height: 14),
          ],

          // Scanned photo
          Hero(tag: 'mango-logo', child: _imageCard(context, imageFile)),
          const SizedBox(height: 16),

          // Verdict hero — the headline result, revealed with a soft animation.
          _verdictCard(
            context,
            isMango: isMango,
            objectType: objectType,
            displayDisease: displayDisease,
            hasDisease: hasDisease,
          ).animate().fadeIn(duration: 400.ms).slideY(
            begin: 0.1,
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          ),

          // Ripeness (fruit only)
          if (isMango && objectType == 'Fruit') ...[
            const SizedBox(height: 14),
            _ripenessCard(context, ripeness, ripenessStage),
          ],

          // Recommendations / healthy note (mango only)
          if (isMango) ...[
            const SizedBox(height: 14),
            if (hasDisease)
              _bulletCard(
                context,
                title: 'Recommendations',
                icon: Icons.medical_services_outlined,
                bullets: recs,
              )
            else
              _bulletCard(
                context,
                title: 'Looking good',
                icon: Icons.verified_outlined,
                bullets: [
                  objectType == 'Fruit'
                      ? 'Fruit appears healthy. Consider harvesting at ripe stage.'
                      : 'Leaf looks healthy. Keep monitoring regularly.',
                ],
              ),
          ],

          // Photo tips (when not a mango)
          if (!isMango && tips.isNotEmpty) ...[
            const SizedBox(height: 14),
            _bulletCard(
              context,
              title: 'Photo tips',
              icon: Icons.photo_camera_outlined,
              bullets: tips,
            ),
          ],

          // Explainers
          if (explainers.isNotEmpty) ...[
            const SizedBox(height: 14),
            _bulletCard(
              context,
              title: 'Why this result?',
              icon: Icons.help_outline,
              bullets: explainers,
            ),
          ],

          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan again'),
              onPressed: () async {
                try {
                  final cams = await availableCameras();
                  if (!Navigator.of(context).mounted) return;
                  Navigator.of(
                    context,
                  ).pushReplacement(appRoute(CameraScanPage(cameras: cams)));
                } catch (e) {
                  if (!Navigator.of(context).mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not start camera: $e')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// The headline verdict card with a colored accent badge and status chips.
  Widget _verdictCard(
    BuildContext context, {
    required bool isMango,
    required String objectType,
    required String displayDisease,
    required bool hasDisease,
  }) {
    final scheme = Theme.of(context).colorScheme;

    // Accent reflects the most important signal: not-a-mango / disease are
    // alarming (error), a clean mango is reassuring (primary green).
    final Color accent = !isMango
        ? scheme.error
        : (hasDisease ? scheme.error : scheme.primary);
    final IconData badge = !isMango
        ? Icons.block
        : (hasDisease ? Icons.warning_amber_rounded : Icons.check_circle);
    final String title = isMango ? 'Mango detected' : 'Not a mango';
    final String subtitle = isMango
        ? (hasDisease ? 'Condition needs attention' : 'No issues detected')
        : 'Try another photo for a reading';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Icon(badge, color: accent, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isMango) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppStatusChip(objectType, icon: Icons.category_outlined),
                AppStatusChip(
                  displayDisease,
                  tone: hasDisease ? StatusTone.danger : StatusTone.success,
                  icon: hasDisease
                      ? Icons.coronavirus_outlined
                      : Icons.eco_outlined,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Ripeness gauge for fruit results.
  Widget _ripenessCard(BuildContext context, double ripeness, String stage) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ripeness',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              AppStatusChip(stage, tone: StatusTone.warning),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (ripeness / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${ripeness.toStringAsFixed(0)}% ripe',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// A titled card listing bullet points.
  Widget _bulletCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<String> bullets,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final b in bullets) _smallBullet(b),
        ],
      ),
    );
  }

  Widget _imageCard(BuildContext context, File file) {
    // Note: the model returns bounding boxes in image-pixel coordinates, but we
    // don't know the source dimensions they were measured against, so they
    // can't be mapped reliably onto the displayed widget. The overlay was
    // removed rather than show misaligned boxes; just display the photo.
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, fit: BoxFit.cover),
      ),
    );
  }

  Widget _fallbackBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cloud analysis unavailable — showing a limited on-device estimate. '
              'Reconnect to the internet for a full AI report.',
              style: TextStyle(
                fontSize: 12.5,
                color: scheme.onTertiaryContainer,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBullet(String txt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 18, height: 1.4)),
        Expanded(child: Text(txt, style: const TextStyle(fontSize: 14))),
      ],
    ),
  );

}
