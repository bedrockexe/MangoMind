import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class EditTrainingPage extends StatefulWidget {
  final String trainingId;
  const EditTrainingPage({super.key, required this.trainingId});

  @override
  State<EditTrainingPage> createState() => _EditTrainingPageState();
}

class _EditTrainingPageState extends State<EditTrainingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  String? _category;
  String? _level;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _thumbnailFile;
  String? _existingThumbnailUrl;
  bool _isPublished = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  final _categories = [
    'Pest Control',
    'Irrigation',
    'Fertilization',
    'Harvesting',
  ];
  final _levels = ['Beginner', 'Intermediate', 'Advanced'];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadTraining();
  }

  Future<void> _loadTraining() async {
    final doc = await _firestore
        .collection('trainings')
        .doc(widget.trainingId)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      _titleCtrl.text = data['title'] ?? '';
      _descriptionCtrl.text = data['description'] ?? '';
      _category = data['category'];
      _level = data['level'];
      _venueCtrl.text = data['venue'] ?? '';
      _existingThumbnailUrl = data['thumbnailUrl'];
      _isPublished = data['published'] ?? false;
      final ts = data['scheduledAt'] as Timestamp?;
      if (ts != null) {
        final dt = ts.toDate();
        _selectedDate = DateTime(dt.year, dt.month, dt.day);
        _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }
    });
  }

  Future<void> _pickThumbnail() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (x != null) setState(() => _thumbnailFile = File(x.path));
  }

  Future<String?> _uploadThumbnail(String trainingId) async {
    if (_thumbnailFile == null) return _existingThumbnailUrl;
    final filename = '${const Uuid().v4()}.jpg';
    final ref = _storage.ref().child(
      'trainings/$trainingId/thumbnail/$filename',
    );
    final uploadTask = ref.putFile(_thumbnailFile!);
    uploadTask.snapshotEvents.listen((snap) {
      setState(() => _uploadProgress = snap.bytesTransferred / snap.totalBytes);
    });
    final snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _selectedTime = t);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose date and time')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final user = _auth.currentUser!;
      final docRef = _firestore.collection('trainings').doc(widget.trainingId);

      final sessionDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      String? thumb = await _uploadThumbnail(widget.trainingId);

      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'category': _category,
        'level': _level,
        'venue': _venueCtrl.text.trim(),
        'scheduledAt': Timestamp.fromDate(sessionDateTime),
        'thumbnailUrl': thumb,
        'published': _isPublished,
        'updatedBy': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(data);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Training updated')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDeleteTraining() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete training?'),
        content: const Text(
          'This will delete the training and related enrollments & materials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      // delegate deletion back to admin page function or run same cascade delete
      await _firestore.runTransaction((tx) async {
        tx.delete(_firestore.collection('trainings').doc(widget.trainingId));
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deleted')));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Training'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDeleteTraining,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickThumbnail,
                  child: _thumbnailFile != null
                      ? Image.file(
                          _thumbnailFile!,
                          height: 160,
                          fit: BoxFit.cover,
                        )
                      : (_existingThumbnailUrl != null
                            ? Image.network(
                                _existingThumbnailUrl!,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 160,
                                color: Colors.grey.shade200,
                                child: const Center(child: Icon(Icons.image)),
                              )),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null) return 'Select';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _level,
                  items: _levels
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _level = v),
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null) return 'Select';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _venueCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _selectedDate == null
                              ? 'Pick date'
                              : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}',
                        ),
                        onPressed: _pickDate,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text(
                          _selectedTime == null
                              ? 'Pick time'
                              : _selectedTime!.format(context),
                        ),
                        onPressed: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isPublished,
                  onChanged: (v) => setState(() => _isPublished = v),
                  title: const Text('Publish'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_isSaving ? 'Saving...' : 'Save changes'),
                  ),
                ),
                if (_isSaving && _uploadProgress > 0)
                  LinearProgressIndicator(value: _uploadProgress),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
