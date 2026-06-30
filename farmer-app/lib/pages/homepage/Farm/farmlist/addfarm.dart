import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/interactions.dart';

class AddFarmPage extends StatefulWidget {
  const AddFarmPage({super.key});
  @override
  State<AddFarmPage> createState() => _AddFarmPageState();
}

class _AddFarmPageState extends State<AddFarmPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic profile
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _areaHa = TextEditingController();

  // Soil
  final List<String> _soilTypes = [
    'Loam',
    'Sandy',
    'Clay',
    'Silty',
    'Peaty',
    'Chalky',
  ];
  String? _soilType = 'Loam';
  final _soilPh = TextEditingController();

  // Planting
  final _plantingYear = TextEditingController();

  // Irrigation
  final List<String> _irrigationTypes = [
    'None',
    'Drip',
    'Sprinkler',
    'Surface',
  ];
  String? _irrigationType = 'None';

  // Disease flags
  bool _anthracnose = false;
  bool _powderyMildew = false;

  // Image
  XFile? _pickedImage;

  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _areaHa.dispose();
    _soilPh.dispose();
    _plantingYear.dispose();
    super.dispose();
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
  num? _numOrNull(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());
  int? _intOrNull(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

  // -----------------------------
  // PICK IMAGE
  // -----------------------------
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() => _pickedImage = img);
    }
  }

  // -----------------------------
  // SAVE FARM
  // -----------------------------
  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in first.')));
      return;
    }

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      String? imageUrl;

      // 1) Upload image if picked
      if (_pickedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('farm_images')
            .child(user.uid)
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        await storageRef.putFile(File(_pickedImage!.path));
        imageUrl = await storageRef.getDownloadURL();
      }

      // 2) Create farm document
      final farmRef = db.collection('farms').doc();
      final farmDoc = {
        'ownerUid': user.uid,
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'areaHa': _numOrNull(_areaHa.text),
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'soil': {
          if (_soilType != null) 'type': _soilType,
          'ph': _numOrNull(_soilPh.text),
        },
        'planting': {'year': _intOrNull(_plantingYear.text)},
        'irrigation': {if (_irrigationType != null) 'type': _irrigationType},
        'diseasePest': {
          'anthracnose': _anthracnose,
          'powderyMildew': _powderyMildew,
        },
      };

      batch.set(farmRef, farmDoc);

      // 3) Add farmId to user
      final userRef = db.collection('users').doc(user.uid);
      batch.set(userRef, {
        'farmIds': FieldValue.arrayUnion([farmRef.id]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Farm saved')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Farm')),
      body: IgnorePointer(
        ignoring: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo
                _photoField(context),
                const SizedBox(height: AppTheme.space5),

                // Basic info
                const SectionHeader('Basic info'),
                AppCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(
                          labelText: 'Farm Name *',
                          prefixIcon: Icon(Icons.agriculture_outlined),
                        ),
                        validator: _req,
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Address / Barangay *',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: _req,
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _areaHa,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Area (hectares)',
                          helperText: 'Example: 1.5',
                          prefixIcon: Icon(Icons.straighten),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                // Soil
                const SectionHeader('Soil'),
                AppCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _soilType,
                        items: _soilTypes
                            .map(
                              (t) =>
                                  DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _soilType = v),
                        decoration: const InputDecoration(
                          labelText: 'Soil Type',
                          prefixIcon: Icon(Icons.terrain_outlined),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _soilPh,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Soil pH (optional)',
                          prefixIcon: Icon(Icons.science_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                // Planting
                const SectionHeader('Planting'),
                AppCard(
                  child: TextFormField(
                    controller: _plantingYear,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Planting Year (optional)',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                // Irrigation
                const SectionHeader('Irrigation'),
                AppCard(
                  child: DropdownButtonFormField<String>(
                    value: _irrigationType,
                    items: _irrigationTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _irrigationType = v),
                    decoration: const InputDecoration(
                      labelText: 'Irrigation Type',
                      prefixIcon: Icon(Icons.water_drop_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),

                // Disease & pests
                const SectionHeader('Disease & pests'),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space2,
                    vertical: AppTheme.space1,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _anthracnose,
                        onChanged: (v) => setState(() => _anthracnose = v),
                        title: const Text('Anthracnose observed'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      SwitchListTile(
                        value: _powderyMildew,
                        onChanged: (v) => setState(() => _powderyMildew = v),
                        title: const Text('Powdery Mildew observed'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space5),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveFarm,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save Farm'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tappable farm-photo picker: shows the chosen image with a "Change" chip,
  /// or a dashed placeholder prompting the user to pick one.
  Widget _photoField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: _pickImage,
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: SizedBox(
          width: double.infinity,
          height: 180,
          child: _pickedImage != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(_pickedImage!.path), fit: BoxFit.cover),
                    Positioned(
                      right: AppTheme.space2,
                      bottom: AppTheme.space2,
                      child: _changeChip(),
                    ),
                  ],
                )
              : Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: AppTheme.cardRadius,
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: scheme.primary,
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        'Choose farm picture',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _changeChip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.edit, size: 14, color: Colors.white),
        SizedBox(width: 4),
        Text(
          'Change',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    ),
  );
}
