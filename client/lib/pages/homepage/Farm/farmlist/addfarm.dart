import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
    final pad8 = const SizedBox(height: 8);
    final pad16 = const SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Farm')),
      body: IgnorePointer(
        ignoring: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // ---------------------------
                // IMAGE PREVIEW + BUTTON
                // ---------------------------
                if (_pickedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_pickedImage!.path),
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.image, size: 60),
                  ),

                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text("Choose Farm Picture"),
                ),

                pad16,

                // BASIC INFO
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Farm Name *'),
                  validator: _req,
                ),
                pad16,
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Address / Barangay *',
                  ),
                  validator: _req,
                ),
                pad16,
                TextFormField(
                  controller: _areaHa,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Area (hectares)',
                    helperText: 'Example: 1.5',
                  ),
                ),

                pad16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Soil',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                pad8,
                DropdownButtonFormField<String>(
                  value: _soilType,
                  items: _soilTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _soilType = v),
                  decoration: const InputDecoration(labelText: 'Soil Type'),
                ),
                pad8,
                TextFormField(
                  controller: _soilPh,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Soil pH (optional)',
                  ),
                ),

                pad16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Planting',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                pad8,
                TextFormField(
                  controller: _plantingYear,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Planting Year (optional)',
                  ),
                ),

                pad16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Irrigation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                pad8,
                DropdownButtonFormField<String>(
                  value: _irrigationType,
                  items: _irrigationTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _irrigationType = v),
                  decoration: const InputDecoration(
                    labelText: 'Irrigation Type',
                  ),
                ),

                pad16,
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Disease',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SwitchListTile(
                  value: _anthracnose,
                  onChanged: (v) => setState(() => _anthracnose = v),
                  title: const Text('Anthracnose observed'),
                ),
                SwitchListTile(
                  value: _powderyMildew,
                  onChanged: (v) => setState(() => _powderyMildew = v),
                  title: const Text('Powdery Mildew observed'),
                ),

                const SizedBox(height: 24),
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
}
