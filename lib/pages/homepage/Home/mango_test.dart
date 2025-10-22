// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class MangoDetector extends StatefulWidget {
  const MangoDetector({super.key});
  @override
  State<MangoDetector> createState() => _MangoDetectorState();
}

class _MangoDetectorState extends State<MangoDetector> {
  late final List<CameraDescription> cameras;

  Future<void> initializeCameras() async {
    cameras = await availableCameras();
  }

  @override
  void initState() {
    super.initState();
    initializeCameras();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFe6f7ea), Color(0xFFeaf9ff)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.eco, size: 36, color: Colors.green),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Sweet Insights',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('Mango Detector', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'mango-logo',
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD473), Color(0xFFFFB347)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.food_bank,
                            size: 64,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Scan a mango leaf or fruit to get instant disease and ripeness insights — powered by on-device camera & AI.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 6,
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Scan now'),
                      onPressed: () {
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(
                              milliseconds: 650,
                            ),
                            pageBuilder: (context, a1, a2) =>
                                CameraScanPage(cameras: cameras),
                            transitionsBuilder:
                                (context, animation, secondary, child) {
                                  final fade = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOut,
                                  );
                                  return FadeTransition(
                                    opacity: fade,
                                    child: child,
                                  );
                                },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Tip: Good daylight and single object in frame gives best results',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
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
      MaterialPageRoute(
        builder: (_) => DetectionLoadingPage(imageFile: File(raw.path)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                          Colors.black.withOpacity(0.15),
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
                                color: Colors.white.withOpacity(0.9),
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
                                            color: Colors.white.withOpacity(
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
                                ? Colors.grey
                                : Colors.green,
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
  String _raw = '';
  Map<String, dynamic>? _parsed;
  String _error = '';
  bool _done = false;

  // Keep model instance here; supply your own apiKey safely in production
  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: '***REMOVED_GEMINI_KEY***',
  );

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

      final content = [
        Content.multi([TextPart(prompt), DataPart("image/jpeg", bytes)]),
      ];

      final response = await _model.generateContent(
        content,
      ); // adjust if your package differs
      final text = response.text ?? '';
      setState(() {
        _raw = text;
      });
      // parse with same validator used before:
      final parsed = _safeParseAndValidateJson(text);
      setState(() {
        _parsed = parsed;
        _done = true;
      });

      // navigate to result page after small delay to show transition
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DetectionResultPage(parsed: parsed, imageFile: widget.imageFile),
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Analysis error: $e';
        _done = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf6fbf8),
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
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.12),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.analytics_outlined,
                      size: 56,
                      color: Colors.green,
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
                    style: const TextStyle(color: Colors.red),
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

  // --- JSON validate/parse copied/adapted from your original code ---
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
        !["Leaf", "Fruit", "Other"].contains(objectType))
      return unsureFallback();

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
    if (diseaseLabel is! String || !allowedDiseases.contains(diseaseLabel))
      return unsureFallback();

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
    if (ripenessStage is! String || !allowedRipeness.contains(ripenessStage))
      return unsureFallback();

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
  const DetectionResultPage({
    super.key,
    required this.parsed,
    required this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    final isMango = parsed['is_mango'] as bool;
    final objectType = parsed['object_type'] as String;
    final disease = parsed['disease_label'] as String;
    final diseaseConf = (parsed['disease_confidence'] as num).toDouble();
    final ripeness = (parsed['fruit_ripeness_pct'] as num).toDouble();
    final ripenessStage = parsed['ripeness_stage'] as String;
    final recs = List<String>.from(parsed['recommendations'] as List);
    final tips = List<String>.from(parsed['photo_tips'] as List);
    final boxes = List<Map<String, dynamic>>.from(
      parsed['bounding_boxes'] as List,
    );
    final explainers = List<String>.from(parsed['explainers'] as List);
    final overall = (parsed['overall_confidence'] as num).toDouble();
    final timestamp = parsed['timestamp_utc'] as String;

    // choose icon + label
    final mainLabel = isMango ? 'Mango detected' : 'Not a mango';
    final icon = isMango ? Icons.check_circle_outline : Icons.block;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Detection',
          style: TextStyle(color: Colors.green.shade700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.green),
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFFfbfefb),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Hero(tag: 'mango-logo', child: _imageCard(imageFile, boxes)),
              const SizedBox(height: 14),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 28,
                            color: isMango ? Colors.green : Colors.redAccent,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              mainLabel,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _smallBadge(
                            'Confidence: ${(overall).toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!isMango) ...[
                        const Text(
                          'Photo tips',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (final t in tips) _smallBullet(t),
                      ] else ...[
                        Row(
                          children: [
                            _pill('Type: $objectType'),
                            const SizedBox(width: 8),
                            if (objectType == 'Fruit')
                              _pill('Stage: $ripenessStage'),
                            const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (objectType == 'Fruit') ...[
                          Text(
                            'Ripeness: ${ripeness.toStringAsFixed(2)}%',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (ripeness / 100).clamp(0.0, 1.0),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Health: $disease (${(diseaseConf).toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (disease != 'Healthy' && disease != 'UNSURE') ...[
                            const Text(
                              'Recommendations',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            for (final r in recs) _smallBullet(r),
                          ] else if (disease == 'Healthy') ...[
                            _smallBullet(
                              'Fruit appears healthy. Consider harvesting at ripe stage.',
                            ),
                          ],
                        ] else if (objectType == 'Leaf') ...[
                          Text(
                            'Leaf health: $disease (${(diseaseConf).toStringAsFixed(2)})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          if (disease != 'Healthy' && disease != 'UNSURE') ...[
                            const Text(
                              'Recommendations',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            for (final r in recs) _smallBullet(r),
                          ] else ...[
                            _smallBullet(
                              'Leaf looks healthy. Keep monitoring regularly.',
                            ),
                          ],
                        ],
                      ],
                      const SizedBox(height: 10),
                      if (explainers.isNotEmpty) ...[
                        const Text(
                          'Why this result?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        for (final e in explainers) _smallBullet(e),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                            ),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                            ),
                            label: const Text('Scan again'),
                            onPressed: () async {
                              // get available cameras again and push CameraScanPage
                              try {
                                final cams = await availableCameras();
                                // replace current page with a fresh camera scan page
                                if (!Navigator.of(context).mounted) return;
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CameraScanPage(cameras: cams),
                                  ),
                                );
                              } catch (e) {
                                // fallback: go back to first route (welcome) if camera init fails
                                if (!Navigator.of(context).mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not start camera: $e'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageCard(File file, List<Map<String, dynamic>> boxes) {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(file, fit: BoxFit.cover),
            // overlay boxes if any
            if (boxes.isNotEmpty)
              ...boxes.map((b) {
                final left = (b['x'] as int).toDouble();
                final top = (b['y'] as int).toDouble();
                final w = (b['w'] as int).toDouble();
                final h = (b['h'] as int).toDouble();
                // they are in pixel coordinates — here we fallback to showing a translucent box anchored to top-left
                return Positioned(
                  left:
                      left /
                      4, // best-effort scaling; for production we would map real pixel to widget size
                  top: top / 4,
                  width: w / 4,
                  height: h / 4,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 2),
                      color: Colors.redAccent.withOpacity(0.08),
                    ),
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _smallBadge(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.green.shade700,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );

  Widget _pill(String text) => Container(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6),
      ],
    ),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
  );

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

  Future<void> _shareOrSave(
    BuildContext context,
    Map<String, dynamic> parsed,
    File imageFile,
  ) async {
    // Simple save: write JSON report to app documents and show confirmation.
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final fJson = File('${dir.path}/mango_report_$ts.json');
      await fJson.writeAsString(json.encode(parsed));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report saved to app documents.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    }
  }
}
