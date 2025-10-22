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

class _MangoDiseaseDetectionPageState extends State<MangoDiseaseDetectionPage>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String>? _labels;
  List<String>? _predictions;
  bool _isLoading = true;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isScanning = false;
  String _status = 'Initializing...';
  final int _inputSize = 224;
  bool _didPrecache = false;

  // Animation controller for 5 second scan animation
  late AnimationController _scanController;

  String? _currentTopLabel;
  double? _currentConfidence;

  @override
  void initState() {
    super.initState();
    _predictions = ['No detection yet – point at a mango leaf or fruit'];
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _scanController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // scanning UI turned off in _startScan after wait
      }
    });
    _initializeAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      precacheImage(const AssetImage('assets/loading.gif'), context);
      _didPrecache = true;
    }
  }

  Future<void> _initializeAll() async {
    setState(() {
      _isLoading = true;
      _status = 'Initializing camera & model...';
    });
    await _loadModelAndLabels();
    await _initializeCamera();
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
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();

      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _status = 'Camera Ready – Tap preview to scan';
      });
    } catch (e) {
      setState(() {
        _status = 'Camera Error: $e';
        _isLoading = false;
        _isInitialized = false;
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
      final outputShape = _interpreter?.getOutputTensor(0).shape;

      if (outputShape == null || outputShape[1] != 4) {
        throw Exception(
          'Model shape mismatch: Expected output [1,4], got $outputShape',
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Model Error: $e – Check assets/model.tflite and labels.txt';
        _isLoading = false;
        _predictions = ['Error loading model: $e'];
      });
    }
  }

  // Start a scan: run both the animation and inference, wait for both to finish,
  // then stop the camera and show the result page.
  Future<void> _startScan() async {
    if (!_isInitialized || _isLoading || _isProcessing) return;
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
      _currentTopLabel = null;
      _currentConfidence = null;
    });

    // Start the animation
    final animationFuture = _scanController.forward(from: 0.0);

    // Start inference
    final inferenceFuture = _runInference();

    // Wait for both to finish
    final results = await Future.wait<dynamic>([
      animationFuture,
      inferenceFuture,
    ]);

    // inference result is at index 1
    final Map<String, dynamic> inferenceResult =
        results[1] as Map<String, dynamic>;

    // Stop / dispose camera so we can show the captured image without camera occupying the device
    try {
      await _cameraController?.dispose();
    } catch (_) {}
    _cameraController = null;

    setState(() {
      _isScanning = false;
      _isInitialized = false;
    });

    // Navigate to full screen result page. After the user pops the result page,
    // reinitialize the camera so user can scan again.
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          imageBytes: inferenceResult['bytes'] as Uint8List?,
          label: inferenceResult['label'] as String?,
          confidence: inferenceResult['confidence'] as double?,
          error: inferenceResult['error'] as String?,
        ),
      ),
    );

    // Re-initialize camera for next scans
    await _initializeCamera();
  }

  // Run inference and return a map containing the captured bytes and results.
  // This ensures caller can wait for inference result.
  Future<Map<String, dynamic>> _runInference() async {
    if (_isProcessing) {
      return {
        'bytes': null,
        'label': null,
        'confidence': null,
        'error': 'Already processing',
      };
    }
    _isProcessing = true;

    Uint8List? bytes;
    String? topLabel;
    double? confidence;
    String? error;

    if (_cameraController == null || _interpreter == null || _labels == null) {
      _isProcessing = false;
      return {
        'bytes': null,
        'label': null,
        'confidence': null,
        'error': 'Missing camera/model',
      };
    }

    try {
      final picture = await _cameraController!.takePicture();
      bytes = await picture.readAsBytes();

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

      if (probSum < 0.01) {
        throw Exception('Invalid probabilities (sum too low: $probSum)');
      }

      final topIndex = _argmaxIndex(probabilities);
      final rawTopLabel = _labels![topIndex];
      topLabel = rawTopLabel;
      confidence = probabilities[topIndex];

      if (mounted) {
        setState(() {
          _predictions = [
            '${_prettyLabel(topLabel!)}: ${(confidence! * 100).toStringAsFixed(1)}%',
          ];
          _currentTopLabel = topLabel;
          _currentConfidence = confidence;
        });
      }
    } catch (e) {
      error = e.toString();
      if (mounted) {
        setState(() {
          _predictions = ['Inference Error: $e'];
          _currentTopLabel = null;
          _currentConfidence = null;
        });
      }
    } finally {
      _isProcessing = false;
    }

    return {
      'bytes': bytes,
      'label': topLabel,
      'confidence': confidence,
      'error': error,
    };
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

  @override
  void dispose() {
    _scanController.dispose();
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  // Put this method inside your State class (_MangoDiseaseDetectionPageState)
  Widget _buildScanOverlay() {
    const double boxSize = 360;
    const double cornerLength = 24;
    final double borderWidth = 3.0;

    return AnimatedOpacity(
      opacity: _isScanning ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_isScanning,
        child: Container(
          alignment: Alignment.center,
          color: _isScanning ? Colors.black45 : Colors.transparent,
          child: SizedBox(
            width: boxSize,
            height: boxSize,
            child: Stack(
              children: [
                // The scanning box background (slightly transparent so preview is visible)
                Center(
                  child: Container(
                    width: boxSize,
                    height: boxSize,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),

                // Pulsing border (animated by _scanController)
                Center(
                  child: AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      // pulse value between 0.7 and 1.0
                      final pulse =
                          0.7 +
                          0.3 *
                              (0.5 +
                                  0.5 *
                                      (1 -
                                          (_scanController.value - 0.5).abs() *
                                              2));
                      return Center(
                        child: Transform.scale(
                          scale: pulse,
                          child: Container(
                            width: boxSize,
                            height: boxSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.greenAccent.withOpacity(
                                  0.9 * (1 - _scanController.value * 0.4),
                                ),
                                width: borderWidth,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Corner markers
                // Top-left
                Positioned(
                  left: 6,
                  top: 6,
                  child: _CornerMarker(length: cornerLength),
                ),
                // Top-right
                Positioned(
                  right: 6,
                  top: 6,
                  child: Transform(
                    transform: Matrix4.identity()..rotateZ(3.1416 / 2),
                    alignment: Alignment.center,
                    child: _CornerMarker(length: cornerLength),
                  ),
                ),
                // Bottom-left
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Transform(
                    transform: Matrix4.identity()..rotateZ(-3.1416 / 2),
                    alignment: Alignment.center,
                    child: _CornerMarker(length: cornerLength),
                  ),
                ),
                // Bottom-right
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Transform(
                    transform: Matrix4.identity()..rotateZ(3.1416),
                    alignment: Alignment.center,
                    child: _CornerMarker(length: cornerLength),
                  ),
                ),

                // Moving laser line
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    // y position inside the box [0..boxSize]
                    final double y = (_scanController.value) * (boxSize - 4);
                    return Positioned(
                      left: 2,
                      right: 2,
                      top: y,
                      child: Opacity(
                        opacity: 0.95,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.transparent,
                                Colors.greenAccent.withOpacity(0.9),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Small status text inside box (optional)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Analyzing…',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          : !_isInitialized || _cameraController == null
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
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: null,
                    child: Text('Retry (reopen app)'),
                  ),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Make preview tappable to start scan
                GestureDetector(
                  onTap: () {
                    if (!_isScanning && !_isProcessing) {
                      _startScan();
                    }
                  },
                  child: CameraPreview(_cameraController!),
                ),

                // Top status/info bar
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
                    child: _isScanning
                        ? Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Scanning... hold steady',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: AnimatedBuilder(
                                  animation: _scanController,
                                  builder: (context, child) {
                                    return LinearProgressIndicator(
                                      value: _scanController.value,
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : _isProcessing
                        ? Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Processing image...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Point the camera at a mango leaf or fruit and tap to scan.',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                  ),
                ),

                _buildScanOverlay(),
              ],
            ),
    );
  }

  Widget _buildResultCard(String label, double confidence, ThemeData theme) {
    final color = _labelColor(label);

    return Card(
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
                    label,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${(confidence * 100).toStringAsFixed(1)}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            Text(
              _descriptionFor(label),
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
              _actionFor(label),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),

            // Action row with Scan Again
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Start scan again from card (user might prefer to stay on same screen)
                    _startScan();
                  },
                  child: const Text('Scan Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen result page that shows the captured image on top and result below.
class ResultPage extends StatelessWidget {
  final Uint8List? imageBytes;
  final String? label; // raw label from model (e.g., 'Powdery_Mildew')
  final double? confidence;
  final String? error;

  const ResultPage({
    super.key,
    required this.imageBytes,
    required this.label,
    required this.confidence,
    required this.error,
  });

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

  @override
  Widget build(BuildContext context) {
    final pretty = label == null ? null : _prettyLabel(label!);
    final color = pretty == null ? Colors.blueGrey : _labelColor(pretty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Display the captured image (or placeholder)
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: imageBytes != null
                  ? Image.memory(imageBytes!, fit: BoxFit.cover)
                  : const Center(
                      child: Text(
                        'No image captured',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ),

          // Result card
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.grey[100],
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: error != null
                    ? Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Inference error:\n$error',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    : Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.local_florist_rounded,
                                    color: color,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      pretty ?? 'Unknown',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _descriptionFor(pretty ?? 'Unknown'),
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(color: Colors.black87),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Suggested Actions',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _actionFor(pretty ?? 'Unknown'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: Colors.black87),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Scan Again'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerMarker extends StatelessWidget {
  final double length;
  const _CornerMarker({Key? key, required this.length}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: length,
      height: length,
      child: CustomPaint(painter: _CornerPainter()),
    );
  }
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // draw two short lines to form a corner (L shape)
    // horizontal line
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width * 0.6, size.height),
      paint,
    );
    // vertical line
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, size.height * 0.6),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
