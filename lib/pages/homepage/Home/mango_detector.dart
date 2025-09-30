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
  String _status = 'Initializing...';
  Timer? _inferenceTimer;
  final int _inputSize = 224;

  @override
  void initState() {
    super.initState();
    _predictions = ['No detection yet – point at a mango leaf or fruit'];
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

      final labelsString = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsString
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (_labels!.isEmpty || _labels!.length != 4) {
        throw Exception('Expected 4 labels, got ${_labels?.length}');
      }

      _interpreter = await Interpreter.fromAsset('assets/model.tflite');
      final inputShape = _interpreter?.getInputTensor(0).shape;
      final outputShape = _interpreter?.getOutputTensor(0).shape;

      if (inputShape == null || outputShape == null || outputShape[1] != 4) {
        throw Exception(
          'Model shape mismatch: Expected output [1,4], got $outputShape',
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
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
      return;
    }

    _inferenceTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_isInitialized || _isLoading || _isProcessing) {
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
  }

  Future<void> _runInference() async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;
    if (_cameraController == null || _interpreter == null || _labels == null) {
      _isProcessing = false;
      return;
    }

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

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

      final output = [List<double>.filled(_labels!.length, 0.0)];
      _interpreter!.run(input, output);
      final probabilities = output[0] as List<double>;
      final probSum = probabilities.fold(0.0, (sum, p) => sum + p);

      if (probSum < 0.1) {
        throw Exception(
          'Invalid probabilities (sum too low: $probSum) – check model',
        );
      }

      // Get top prediction only
      final topIndex = _argmaxIndex(probabilities);
      final topLabel = _labels![topIndex];
      final confidence = probabilities[topIndex];

      if (mounted) {
        setState(() {
          _predictions = [
            '${_prettyLabel(topLabel)}: ${(confidence * 100).toStringAsFixed(1)}%',
          ];
          _currentTopLabel = topLabel;
          _currentConfidence = confidence;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _predictions = [
            'Inference Error: $e – Check model input/output shapes',
          ];
          _currentTopLabel = null;
          _currentConfidence = null;
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

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

  int _argmaxIndex(List<double> probabilities) {
    int maxIndex = 0;
    double maxProb = probabilities[0];
    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

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

  Color _labelColor(String label) {
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
        return Colors.blueGrey;
    }
  }

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
        return 'No description available.';
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

  String? _currentTopLabel;
  double? _currentConfidence;

  @override
  void dispose() {
    _inferenceTimer?.cancel();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mango Disease Detection',
          style: TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: Colors.green,
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.all(16.0),
        //     child: Text(
        //       _status,
        //       style: const TextStyle(color: Colors.white, fontSize: 12),
        //     ),
        //   ),
        // ],
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
                CameraPreview(_cameraController!),
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
                    child: _isProcessing
                        ? Row(
                            children: [
                              const Text(
                                'Detecting mango disease... ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(width: 20),
                              CircularProgressIndicator(strokeWidth: 3),
                            ],
                          )
                        : const Text(
                            'Point the camera at a mango leaf or fruit for detection.',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),
                Positioned(
                  bottom: 50,
                  left: 20,
                  right: 20,
                  child: _currentTopLabel == null
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'No detection yet – analyzing...',
                            style: TextStyle(
                              color: Colors.yellow,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _buildResultCard(
                          _currentTopLabel!,
                          _currentConfidence ?? 0,
                          theme,
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResultCard(String label, double confidence, ThemeData theme) {
    final prettyLabel = _prettyLabel(label);
    final color = _labelColor(prettyLabel);
    final confidencePercent = (confidence * 100).toStringAsFixed(1);
    final isError = prettyLabel == 'Not Mango';

    return Card(
      // color: isError ? Colors.red.shade700 : Colors.black87,
      color: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label and confidence row
            Row(
              children: [
                Icon(Icons.local_florist_rounded, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    prettyLabel,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 12,
                //     vertical: 6,
                //   ),
                //   decoration: BoxDecoration(
                //     color: Colors.white24,
                //     borderRadius: BorderRadius.circular(999),
                //   ),
                //   child: Text(
                //     '$confidencePercent%',
                //     style: theme.textTheme.titleMedium?.copyWith(
                //       color: Colors.white,
                //       fontWeight: FontWeight.w600,
                //     ),
                //   ),
                // ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              _descriptionFor(prettyLabel),
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 16),

            // Suggested actions or tips
            Text(
              'Suggested Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _actionFor(prettyLabel),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),

            // if (isError) ...[
            //   const SizedBox(height: 16),
            //   Text(
            //     'Tips for better photos:',
            //     style: theme.textTheme.titleMedium?.copyWith(
            //       color: Colors.white,
            //       fontWeight: FontWeight.w600,
            //     ),
            //   ),
            //   const SizedBox(height: 8),
            //   _buildTip(theme, 'Fill the frame with the mango leaf or fruit.'),
            //   _buildTip(theme, 'Use good lighting and avoid glare or shadows.'),
            //   _buildTip(
            //     theme,
            //     'Keep the camera steady and focus on the subject.',
            //   ),
            // ],
          ],
        ),
      ),
    );
  }

  Widget _buildTip(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
