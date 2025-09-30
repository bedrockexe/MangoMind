import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class MangoDiseaseDetectionPage extends StatefulWidget {
  const MangoDiseaseDetectionPage({super.key});

  @override
  State<MangoDiseaseDetectionPage> createState() =>
      _MangoDiseaseDetectionPageState();
}

class _MangoDiseaseDetectionPageState extends State<MangoDiseaseDetectionPage> {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String>? _labels;
  List<String>? _predictions;
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _status =
      'Initializing...'; // For UI debugging (e.g., "Loading Model", "Running Inference")
  Timer? _inferenceTimer;
  final int _inputSize =
      224; // Model input size – adjust if your model uses different (e.g., 256).
  final int _topK = 4; // Show all 4 labels always.

  @override
  void initState() {
    super.initState();
    _predictions = [
      'No detection yet – point at a mango leaf or fruit',
    ]; // Default message
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _status = 'Initializing Camera...';
      });
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }
      // Prefer back camera.
      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(camera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      await _loadModelAndLabels();
      setState(() {
        _isInitialized = true;
        _status = 'Camera Ready – Starting Detection';
      });
      _startInference();
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _status = 'Camera Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadModelAndLabels() async {
    try {
      setState(() {
        _status = 'Loading Model & Labels...';
      });
      print('Loading labels from assets/labels.txt...');
      final labelsString = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsString
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      print(
        'Loaded labels: $_labels',
      ); // Debug: Should print ["Anthracnose", "Powdery_Mildew", "Healthy_Mango", "Not_Mango"]
      if (_labels!.isEmpty || _labels!.length != 4) {
        throw Exception('Expected 4 labels, got ${_labels?.length}');
      }

      print('Loading TFLite model...');
      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final inputShape = _interpreter?.getInputTensor(0).shape;
      final outputShape = _interpreter?.getOutputTensor(0).shape;
      print(
        'Model loaded successfully. Input shape: $inputShape',
      ); // Should be [1, 224, 224, 3] or similar
      print('Output shape: $outputShape'); // Should be [1, 4]
      if (inputShape == null || outputShape == null || outputShape[1] != 4) {
        throw Exception(
          'Model shape mismatch: Expected output [1,4], got $outputShape',
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading model/labels: $e');
      setState(() {
        _status = 'Model Error: $e – Check assets/model.tflite and labels.txt';
        _isLoading = false;
        _predictions = ['Error loading model: $e'];
      });
    }
  }

  void _startInference() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _interpreter == null) {
      print('Cannot start inference: Camera or model not ready');
      return;
    }

    _inferenceTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_isInitialized || _isLoading || _isProcessing) {
        // Skip if not ready or already processing (prevents overlaps)
        if (_isProcessing) print('Skipping inference: Already processing');
        return;
      }
      setState(() {
        _status = 'Running Inference... (Processing: $_isProcessing)';
      });
      await _runInference();
      setState(() {
        _status = 'Detecting Live...';
      });
    });
    print('Inference timer started (every 500ms)');
  }

  Future<void> _runInference() async {
    if (_isProcessing) {
      print('Skipping inference: Already processing');
      return;
    }
    _isProcessing = true;
    if (_cameraController == null || _interpreter == null || _labels == null) {
      print('Skipping inference: Missing components');
      _isProcessing = false;
      return;
    }

    try {
      print('Capturing image for inference...');
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      print('Image captured (${bytes.length} bytes)');

      img.Image? processedImage = img.decodeImage(bytes);
      if (processedImage == null) {
        throw Exception('Failed to decode image');
      }

      processedImage = img.copyResize(
        processedImage,
        width: _inputSize,
        height: _inputSize,
      );
      final input = buildInputTensor(processedImage, _inputSize);
      print('Image preprocessed to ${_inputSize}x${_inputSize}');

      final output = [List<double>.filled(_labels!.length, 0.0)];
      _interpreter!.run(input, output);
      final probabilities =
          output[0] as List<double>; // Explicit cast for safety
      final probSum = probabilities.fold(0.0, (sum, p) => sum + p);
      print(
        'Inference output probabilities: $probabilities (sum: ${probSum.toStringAsFixed(2)})',
      );

      if (probSum < 0.1) {
        // Sanity check for invalid output
        throw Exception(
          'Invalid probabilities (sum too low: $probSum) – check model',
        );
      }

      // Always get all predictions (topK=4).
      final predictions = _argMax(probabilities, _topK);
      if (mounted) {
        setState(() {
          _predictions = predictions;
        });
      }
      print('Predictions updated: $predictions');
    } catch (e) {
      print('Error during inference: $e');
      if (mounted) {
        setState(() {
          _predictions = [
            'Inference Error: $e – Check model input/output shapes',
          ];
        });
      }
    } finally {
      _isProcessing = false; // Always reset, even on error
    }
  }

  // Helper: Convert img.Image to float32 input tensor (NHWC: 1 x H x W x 3, [0,1]).
  // Instead of Float32List, build nested List<List<List<List<double>>>>
  List<List<List<List<double>>>> buildInputTensor(img.Image image, int size) {
    final input = List.generate(
      1,
      (_) => List.generate(
        size,
        (_) => List.generate(size, (_) => List.filled(3, 0.0)),
      ),
    );

    int i = 0;
    for (final pixel in image) {
      final y = i ~/ size;
      final x = i % size;
      input[0][y][x][0] = pixel.r / 255.0;
      input[0][y][x][1] = pixel.g / 255.0;
      input[0][y][x][2] = pixel.b / 255.0;
      i++;
    }
    return input;
  }

  // Helper: Get all K predictions (K=4) as strings, sorted by confidence descending.
  List<String> _argMax(List<double> probabilities, int k) {
    final indexedProbs = List.generate(
      probabilities.length,
      (i) => (index: i, prob: probabilities[i]),
    )..sort((a, b) => b.prob.compareTo(a.prob)); // Descending
    return indexedProbs.take(k).map((item) {
      final label = _labels![item.index];
      final confidence = (item.prob * 100).toStringAsFixed(1);
      return '$label: $confidence%';
    }).toList();
  }

  @override
  void dispose() {
    _inferenceTimer?.cancel();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mango Disease Detection'),
        backgroundColor: Colors.green,
        actions: [
          // Status indicator in AppBar for debugging.
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading model and camera...'),
                ],
              ),
            )
          : !_isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to initialize: $_status',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Check console logs, permissions, and assets.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview.
                CameraPreview(_cameraController!),
                // Instructions overlay (top).
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Point the camera at a mango leaf or fruit for detection.',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Predictions overlay (bottom) – ALWAYS SHOWN.
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detection Results (All Classes):',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_predictions == null || _predictions!.isEmpty)
                          const Text(
                            'No detection yet – analyzing...',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 16,
                            ),
                          )
                        else
                          ..._predictions!.map(
                            (pred) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                pred,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
    );
  }
}
