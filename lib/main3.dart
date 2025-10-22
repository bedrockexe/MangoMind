import 'dart:convert';
import 'dart:io';
// This import is no longer needed after simplifying the image preview
// import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  String? _base64;
  bool _sending = false;
  String? _responseText;

  // Use a Future to track Firebase initialization
  late final Future<FirebaseApp> _firebaseApp;

  @override
  void initState() {
    super.initState();
    // Assign the future in initState
    _firebaseApp = Firebase.initializeApp();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80, // reduce size if desired
      );
      if (file == null) return;

      // Read bytes *once*
      final bytes = await file.readAsBytes();
      final encoded = base64Encode(bytes);

      setState(() {
        _pickedFile = file;
        _base64 = encoded; // Set base64 at the same time
        _responseText = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  Future<void> _sendToCallable() async {
    if (_base64 == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick an image first')));
      return;
    }

    setState(() {
      _sending = true;
      _responseText = null;
    });

    try {
      // Replace 'analyzeMango' with the name of your callable function.
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeMango',
      );

      final result = await callable.call({'imageBase64': _base64});

      // result.data contains the response from your callable function
      setState(() {
        _responseText = 'Success: ${result.data}';
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _responseText = 'Functions error: ${e.code} - ${e.message}';
      });
    } catch (e) {
      setState(() {
        _responseText = 'Error: $e';
      });
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  // This widget is now used in the build method
  Widget _previewWidget() {
    if (_pickedFile == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No image selected')),
      );
    }

    // This is the most efficient way to display an image from a File
    return Image.file(
      File(_pickedFile!.path),
      height: 200,
      fit: BoxFit.contain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canSend = _base64 != null && !_sending;

    return MaterialApp(
      title: 'Gemini Mango Detector',
      home: Scaffold(
        appBar: AppBar(title: const Text('Pick image → Base64 → Callable')),
        // Use FutureBuilder to wait for Firebase to initialize
        body: FutureBuilder(
          future: _firebaseApp,
          builder: (context, snapshot) {
            // Show error if initialization fails
            if (snapshot.hasError) {
              return Center(
                child: Text('Error initializing Firebase: ${snapshot.error}'),
              );
            }

            // Show loading spinner while initializing
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            // Once initialized, build the main UI
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // --- FIX: Replaced the complex FutureBuilder with this ---
                  _previewWidget(),

                  // --------------------------------------------------------
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Pick from gallery'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Take a photo'),
                      ),
                      ElevatedButton.icon(
                        onPressed: canSend ? _sendToCallable : null,
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                        label: const Text('Send to callable'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_base64 != null)
                    Expanded(
                      child: SingleChildScrollView(
                        child: SelectableText(
                          'Base64 length: ${_base64!.length}\n\n(First 200 chars)\n${_base64!.substring(0, _base64!.length > 200 ? 200 : _base64!.length)}${_base64!.length > 200 ? "..." : ""}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  if (_responseText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _responseText!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
