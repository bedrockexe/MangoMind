import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Result of an on-device classification.
class TfliteResult {
  /// Raw label as written in assets/labels.txt (e.g. "Powdery_Mildew").
  final String label;

  /// Confidence of the top label, 0.0 - 1.0.
  final double confidence;

  /// Full probability vector aligned to the labels file.
  final List<double> probabilities;

  TfliteResult(this.label, this.confidence, this.probabilities);
}

/// Loads and runs the bundled mango-disease classifier (assets/model.tflite).
///
/// This is the OFFLINE FALLBACK used only when the Gemini cloud function
/// (`imageAnalyzer`) is unreachable. The model is a 4-class image classifier:
///   Anthracnose · Powdery_Mildew · Healthy_Mango · Not_Mango
///
/// Model spec (verified from the .tflite file):
///   input : [1, 224, 224, 3] float32
///   output: [1, 4] float32, already soft-maxed (sums to 1)
class TfliteService {
  TfliteService._();
  static final TfliteService instance = TfliteService._();

  Interpreter? _interpreter;
  List<String>? _labels;

  static const int _inputSize = 224;

  /// Input normalization. The model was exported from Keras; most custom
  /// Keras image classifiers train with `rescale=1/255` → pixels in [0, 1].
  ///
  /// If on-device predictions look random/wrong on a real device, the model
  /// was likely trained with [-1, 1] normalization instead — flip this to
  /// `false` (that path applies `(v / 127.5) - 1`). This single switch is the
  /// only value that needs device-side confirmation.
  static const bool _normalizeToZeroOne = true;

  Future<void> _ensureLoaded() async {
    _interpreter ??= await Interpreter.fromAsset('assets/model.tflite');
    if (_labels == null) {
      final raw = await rootBundle.loadString('assets/labels.txt');
      _labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  /// Classifies [imageFile] and returns the top label with its confidence.
  /// Throws if the model can't load or the image can't be decoded.
  Future<TfliteResult> classify(File imageFile) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image for on-device analysis.');
    }
    final resized = img.copyResize(
      decoded,
      width: _inputSize,
      height: _inputSize,
    );

    // Build the [1, 224, 224, 3] float input tensor (row-major: y, then x).
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final px = resized.getPixel(x, y);
          double norm(num c) =>
              _normalizeToZeroOne ? c / 255.0 : (c / 127.5) - 1.0;
          return [norm(px.r), norm(px.g), norm(px.b)];
        }),
      ),
    );

    // Output buffer matches [1, labels.length].
    final output = List.generate(1, (_) => List<double>.filled(labels.length, 0.0));
    interpreter.run(input, output);

    final probs = output[0].map((e) => (e as num).toDouble()).toList();

    var bestIdx = 0;
    for (var i = 1; i < probs.length; i++) {
      if (probs[i] > probs[bestIdx]) bestIdx = i;
    }
    final label = bestIdx < labels.length ? labels[bestIdx] : 'Not_Mango';
    return TfliteResult(label, probs[bestIdx], probs);
  }
}
