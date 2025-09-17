// lib/services/mango_classifier_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MangoClassifier {
  MangoClassifier._();
  static Interpreter? _it;
  static late List<String> labels;
  static const int size = 224;

  static Future<void> load() async {
    _it ??= await Interpreter.fromAsset(
      'assets/model.tflite',
      options: InterpreterOptions()..threads = 2,
    );
    labels = (await rootBundle.loadString(
      'assets/labels.txt',
    )).split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static Future<Result> classifyFile(File f) async =>
      classifyBytes(await f.readAsBytes());

  static Future<Result> classifyBytes(Uint8List bytes) async {
    await load();
    final it = _it!;
    final img.Image? dec = img.decodeImage(bytes);
    if (dec == null) throw StateError('Bad image');
    final r = img.copyResize(dec, width: size, height: size);

    final inT = it.getInputTensor(0), outT = it.getOutputTensor(0);
    final inType = inT.type, outType = outT.type;

    // ---- input ----
    Object input;
    if (_isF32(inType)) {
      final x = List.generate(
        1,
        (_) => List.generate(
          size,
          (_) => List.generate(size, (_) => List.filled(3, 0.0)),
        ),
      );
      int i = 0;
      for (final p in r) {
        final y = i ~/ size, xIdx = i % size;
        x[0][y][xIdx][0] = p.r / 255.0;
        x[0][y][xIdx][1] = p.g / 255.0;
        x[0][y][xIdx][2] = p.b / 255.0;
        i++;
      }
      input = x;
    } else {
      // int8/uint8 (quantized)
      final sc = inT.params.scale, zp = inT.params.zeroPoint;
      final x = List.generate(
        1,
        (_) => List.generate(
          size,
          (_) => List.generate(size, (_) => List.filled(3, 0)),
        ),
      );
      int i = 0;
      for (final p in r) {
        final y = i ~/ size, xIdx = i % size;
        int q(int v) => (((v / 255.0) / (sc == 0 ? 1.0 : sc) + zp).round())
            .clamp(-128, 255);
        x[0][y][xIdx][0] = q(p.r.toInt());
        x[0][y][xIdx][1] = q(p.g.toInt());
        x[0][y][xIdx][2] = q(p.b.toInt());
        i++;
      }
      input = x;
    }

    // ---- output ----
    final n = labels.length;
    final output = _isF32(outType)
        ? List.generate(1, (_) => List.filled(n, 0.0))
        : List.generate(1, (_) => List.filled(n, 0));

    it.run(input, output);

    // ---- post ----
    late List<double> probs;
    if (_isF32(outType)) {
      probs = (output as List).first.cast<double>();
    } else {
      final raw = (output as List).first.cast<int>();
      final sc = outT.params.scale, zp = outT.params.zeroPoint;
      probs = sc != 0
          ? raw.map((q) => (q - zp) * sc).toList()
          : raw.map((q) => q / 255.0).toList();
    }
    if (!_looksLikeProbs(probs)) probs = _softmax(probs);

    final top = _argmax(probs);
    final map = {for (var i = 0; i < n; i++) labels[i]: probs[i]};
    return Result(
      label: _pretty(labels[top]),
      confidence: probs[top],
      probs: map,
    );
  }

  static bool _isF32(t) => t.toString().contains('float32');
  static bool _looksLikeProbs(List<double> v) =>
      v.isNotEmpty &&
      v.every((x) => x >= 0 && x <= 1) &&
      ((v.reduce((a, b) => a + b)) > .98 && (v.reduce((a, b) => a + b)) < 1.02);
  static List<double> _softmax(List<double> z) {
    final m = z.reduce(math.max);
    final exps = z.map((x) => math.exp(x - m)).toList();
    final s = exps.fold(0.0, (a, b) => a + b);
    return exps.map((e) => e / s).toList();
  }

  static int _argmax(List<double> v) {
    var i = 0, bi = 0;
    var b = v[0];
    for (i = 1; i < v.length; i++) {
      if (v[i] > b) {
        b = v[i];
        bi = i;
      }
    }
    return bi;
  }

  static String _pretty(String raw) {
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
}

class Result {
  final String label;
  final double confidence;
  final Map<String, double> probs;
  Result({required this.label, required this.confidence, required this.probs});
}
