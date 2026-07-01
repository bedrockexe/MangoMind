import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';

class CreateTrainingPage extends StatefulWidget {
  const CreateTrainingPage({super.key});

  @override
  State<CreateTrainingPage> createState() => _CreateTrainingPageState();
}

class _CreateTrainingPageState extends State<CreateTrainingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _venueCtrl = TextEditingController();
  String? _category;
  String? _level;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _thumbnailFile;
  bool _isPublished = false;
  bool _isSaving = false;

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
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _venueCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked != null) setState(() => _thumbnailFile = File(picked.path));
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<String?> _uploadThumbnail(String trainingId) async {
    if (_thumbnailFile == null) return null;
    final filename = '${const Uuid().v4()}.jpg';
    final ref = _storage.ref('trainings/$trainingId/thumbnails/$filename');
    final uploadTask = ref.putFile(
      _thumbnailFile!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    await uploadTask;
    return await ref.getDownloadURL();
  }

  Future<void> _saveTraining() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser!;
      final docRef = _firestore.collection('trainings').doc();
      final trainingId = docRef.id;

      // Combine date + time
      final sessionDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      String? thumbnailUrl;
      if (_thumbnailFile != null) {
        thumbnailUrl = await _uploadThumbnail(trainingId);
      }

      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'category': _category,
        'level': _level,
        'venue': _venueCtrl.text.trim(),
        'scheduledAt': Timestamp.fromDate(sessionDateTime),
        'thumbnailUrl': thumbnailUrl,
        'published': _isPublished,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Training created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: (v) => v == null || v.isEmpty ? 'Required field' : null,
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(labelText: label),
      initialValue: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Select $label' : null,
    );
  }

  Widget _buildDateTimePicker() {
    final dateText = _selectedDate != null
        ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
        : 'Select Date';
    final timeText = _selectedTime != null
        ? _selectedTime!.format(context)
        : 'Select Time';
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(dateText),
            onPressed: _pickDate,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text(timeText),
            onPressed: _pickTime,
          ),
        ),
      ],
    );
  }

  Widget _buildThumbnail() {
    return GestureDetector(
      onTap: _pickThumbnail,
      child: _thumbnailFile != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _thumbnailFile!,
                height: 150,
                fit: BoxFit.cover,
              ),
            )
          : Container(
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 6),
                    const Text('Tap to upload thumbnail'),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHistorySection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('trainings')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text('No previous trainings found.');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Recent trainings'),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final title = d['title'] ?? 'Untitled';
              final date = (d['scheduledAt'] as Timestamp?)?.toDate();
              final formatted = date != null
                  ? DateFormat('MMM d, yyyy hh:mm a').format(date)
                  : '';
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space2),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: d['thumbnailUrl'] != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(d['thumbnailUrl']),
                          )
                        : const CircleAvatar(child: Icon(Icons.school)),
                    title: Text(title),
                    subtitle: Text('${d['venue'] ?? ''} • $formatted'),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Training')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildThumbnail(),
              const SizedBox(height: 12),
              _buildTextField('Training Title', _titleCtrl),
              const SizedBox(height: 12),
              _buildTextField('Description', _descriptionCtrl, maxLines: 4),
              const SizedBox(height: 12),
              _buildDropdown(
                'Category',
                _categories,
                _category,
                (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                'Level',
                _levels,
                _level,
                (v) => setState(() => _level = v),
              ),
              const SizedBox(height: 12),
              _buildTextField('Venue', _venueCtrl),
              const SizedBox(height: 12),
              _buildDateTimePicker(),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Publish Now'),
                subtitle: const Text(
                  'If off, training will be saved as draft.',
                ),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(_isSaving ? 'Saving...' : 'Save training'),
                  ),
                  onPressed: _isSaving ? null : _saveTraining,
                ),
              ),
              const SizedBox(height: 24),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }
}
