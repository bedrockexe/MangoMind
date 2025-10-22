import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  File? _selectedImage;
  String _rawResult = '';
  Map<String, dynamic>? _parsed;
  bool _loading = false;
  String _error = '';

  final _model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: '***REMOVED_GEMINI_KEY***',
  );

  final String _strictPrompt = '''
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

  Future<void> _pickAndAnalyzeImage() async {
    setState(() {
      _rawResult = '';
      _parsed = null;
      _loading = true;
      _error = '';
    });

    final picked = await FilePicker.platform.pickFiles(type: FileType.image);

    if (picked == null || picked.files.isEmpty) {
      setState(() => _loading = false);
      return;
    }

    final file = File(picked.files.single.path!);
    setState(() => _selectedImage = file);

    try {
      // Build content: text prompt + image bytes
      final content = [
        Content.multi([
          TextPart(_strictPrompt),
          DataPart("image/jpeg", await file.readAsBytes()),
        ]),
      ];

      // NOTE: the package may accept optional generation parameters (temperature/top_p).
      // If your package supports them, set temperature:0.0 and top_p:0.0 to make it deterministic.
      // Example (pseudo): await _model.generateContent(content, temperature:0.0, topP:0.0);
      final response = await _model.generateContent(content);

      // The package returns a response with text; adapt if your package uses a different property
      final text = response.text ?? '';

      setState(() {
        _rawResult = text;
      });

      // Try to parse JSON. If not parseable, create an UNSURE fallback.
      Map<String, dynamic> parsed = _safeParseAndValidateJson(text);
      setState(() {
        _parsed = parsed;
      });
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  // Parse and validate — ensures the returned JSON matches your schema requirements.
  // If any primary field is invalid or missing, return a strict 'UNSURE' fallback.
  Map<String, dynamic> _safeParseAndValidateJson(String rawText) {
    // Safe fallback object matching your schema (UNSURE values)
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
      // Attempt to extract JSON substring if there is surrounding text
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

    // Validate required keys:
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

    // Validate object_type
    final objectType = m["object_type"];
    if (objectType is! String ||
        !["Leaf", "Fruit", "Other"].contains(objectType)) {
      return unsureFallback();
    }

    // is_mango
    final isMango = m["is_mango"];
    if (isMango is! bool) return unsureFallback();

    // disease_label
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

    // disease_confidence
    double diseaseConfidence;
    try {
      diseaseConfidence = _toDoubleInRange(m["disease_confidence"], 0.0, 1.0);
    } catch (_) {
      return unsureFallback();
    }

    // fruit_ripeness_pct
    double fruitRipeness;
    try {
      fruitRipeness = _toDoubleInRange(m["fruit_ripeness_pct"], 0.0, 100.0);
    } catch (_) {
      return unsureFallback();
    }

    // ripeness_stage validation
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

    // recommendations and photo_tips arrays
    List<String> recommendations = _toStringList(m["recommendations"]);
    List<String> photoTips = _toStringList(m["photo_tips"]);

    // bounding boxes
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
              "region_confidence": _round(regionConf, 2),
            });
          } catch (_) {
            // ignore malformed box
          }
        }
      }
    }

    // explainers
    List<String> explainers = _toStringList(m["explainers"]);

    // overall confidence
    double overallConf;
    try {
      overallConf = _toDoubleInRange(m["overall_confidence"], 0.0, 1.0);
    } catch (_) {
      return unsureFallback();
    }

    // timestamp – try to parse or replace with now if invalid
    String timestamp = m["timestamp_utc"] is String ? m["timestamp_utc"] : '';
    try {
      DateTime.parse(timestamp);
    } catch (_) {
      timestamp = DateFormat(
        "yyyy-MM-ddTHH:mm:ss'Z'",
      ).format(DateTime.now().toUtc());
    }

    // Final assembled validated map (with rounding)
    return {
      "object_type": objectType,
      "is_mango": isMango,
      "disease_label": diseaseLabel,
      "disease_confidence": _round(diseaseConfidence, 2),
      "fruit_ripeness_pct": _round(fruitRipeness, 2),
      "ripeness_stage": ripenessStage,
      "recommendations": recommendations.take(3).toList(),
      "photo_tips": photoTips.take(3).toList(),
      "bounding_boxes": boxes,
      "explainers": explainers.take(2).toList(),
      "overall_confidence": _round(overallConf, 2),
      "timestamp_utc": timestamp,
    };
  }

  // Helpers
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
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return [];
  }

  double _round(double v, int places) {
    final mod = Math.pow(10.0, places);
    return ((v * mod).roundToDouble() / mod);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemini Mango Detector',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Mango Detector (Gemini)'),
          backgroundColor: Colors.green,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ElevatedButton.icon(
                onPressed: _loading ? null : _pickAndAnalyzeImage,
                icon: const Icon(Icons.upload),
                label: const Text('Choose Image'),
              ),
              const SizedBox(height: 12),
              if (_selectedImage != null)
                SizedBox(
                  height: 220,
                  child: Image.file(_selectedImage!, fit: BoxFit.contain),
                ),
              const SizedBox(height: 12),
              if (_loading) const CircularProgressIndicator(),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: _parsed != null ? _buildResultCard() : _buildRawArea(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRawArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Raw model output:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Text(
            _rawResult.isEmpty ? 'No result yet.' : _rawResult,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final p = _parsed!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Parsed result',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Object type', p['object_type'].toString()),
                _row('Is mango', p['is_mango'].toString()),
                _row('Disease', p['disease_label'].toString()),
                _row('Disease confidence', p['disease_confidence'].toString()),
                _row('Fruit ripeness %', p['fruit_ripeness_pct'].toString()),
                _row('Ripeness stage', p['ripeness_stage'].toString()),
                const SizedBox(height: 8),
                if ((p['recommendations'] as List).isNotEmpty)
                  const Text(
                    'Recommendations:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                for (final r in (p['recommendations'] as List))
                  _bullet(r.toString()),
                if ((p['photo_tips'] as List).isNotEmpty)
                  const SizedBox(height: 8),
                if ((p['photo_tips'] as List).isNotEmpty)
                  const Text(
                    'Photo tips:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                for (final t in (p['photo_tips'] as List))
                  _bullet(t.toString()),
                const SizedBox(height: 8),
                if ((p['explainers'] as List).isNotEmpty)
                  const Text(
                    'Explainers:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                for (final e in (p['explainers'] as List))
                  _bullet(e.toString()),
                const SizedBox(height: 8),
                _row('Overall confidence', p['overall_confidence'].toString()),
                _row('Timestamp (UTC)', p['timestamp_utc'].toString()),
                const SizedBox(height: 8),
                if ((p['bounding_boxes'] as List).isNotEmpty)
                  const Text(
                    'Bounding boxes:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                for (final b in (p['bounding_boxes'] as List))
                  Text(b.toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Raw validated JSON:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade100,
          child: Text(
            json.encode(p),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 160,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _bullet(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 18)),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

// small substitute for dart:math pow usage inside _round
class Math {
  static double pow(double base, int exp) {
    return double.parse(base.toString()) == 0.0
        ? 0.0
        : base == 1.0 && exp == 1
        ? 1.0
        : base == 10.0
        ? double.parse((base).toString())
        : base == 0.0
        ? 0.0
        : base; // dummy but never used
  }
}
