// flutter packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditFarm extends StatefulWidget {
  final Map<String, dynamic> farm;
  final String userId;
  final String farmId;
  const EditFarm({
    super.key,
    required this.farm,
    required this.userId,
    required this.farmId,
  });

  @override
  State<EditFarm> createState() => _EditFarmState();
}

class _EditFarmState extends State<EditFarm>
    with SingleTickerProviderStateMixin {
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
  String? _irrigationType = 'Drip';

  // Disease flags
  bool _anthracnose = false;
  bool _powderyMildew = false;

  // IMAGE
  String? _imageUrl;
  File? _pickedImage;

  bool _saving = false;
  late final AnimationController _heroController;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final f = widget.farm;

    // LOAD ORIGINAL DATA
    _name.text = (f['name'] ?? '').toString();
    _address.text = (f['address'] ?? '').toString();
    _areaHa.text = (f['areaHa'] ?? '').toString();
    _soilType = (f['soil']?['type'] ?? _soilType)?.toString();
    _soilPh.text = (f['soil']?['ph'] ?? '').toString();
    _plantingYear.text = (f['planting']?['year'] ?? '').toString();
    _irrigationType = (f['irrigation']?['type'] ?? _irrigationType)?.toString();
    _anthracnose = (f['diseasePest']?['anthracnose'] ?? false) as bool;
    _powderyMildew = (f['diseasePest']?['powderyMildew'] ?? false) as bool;

    // IMAGE LOADING
    _imageUrl = f['imageUrl'];
  }

  @override
  void dispose() {
    _heroController.dispose();
    _name.dispose();
    _address.dispose();
    _areaHa.dispose();
    _soilPh.dispose();
    _plantingYear.dispose();
    super.dispose();
  }

  // VALIDATION HELPERS
  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
  num? _numOrNull(String s) => s.trim().isEmpty ? null : num.tryParse(s.trim());
  int? _intOrNull(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

  // PICK AN IMAGE
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);

    if (img != null) {
      setState(() {
        _pickedImage = File(img.path);
      });
    }
  }

  // UPLOAD IMAGE IF CHANGED
  Future<String?> _uploadImageIfNeeded() async {
    if (_pickedImage == null) return _imageUrl;

    final ref = FirebaseStorage.instance
        .ref()
        .child("farm_images")
        .child(widget.userId)
        .child("${widget.farmId}.jpg");

    await ref.putFile(_pickedImage!);
    return await ref.getDownloadURL();
  }

  // SAVE FUNCTION
  Future<void> _saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    _heroController.forward();

    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Upload image if changed
      final imageUrl = await _uploadImageIfNeeded();

      final farmRef = db.collection('farms').doc(widget.farmId);

      final farmDoc = {
        'ownerUid': widget.userId,
        'name': _name.text.trim(),
        'address': _address.text.trim(),
        'areaHa': _numOrNull(_areaHa.text),
        'imageUrl': imageUrl,
        'createdAt': widget.farm['createdAt'] ?? FieldValue.serverTimestamp(),
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
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(farmRef, farmDoc, SetOptions(merge: true));

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Farm updated')),
      );
      Navigator.of(context).maybePop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        _heroController.reverse();
      }
    }
  }

  // Label helper
  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Farm'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _saveFarm,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _saving
                  ? const SizedBox(
                      key: ValueKey('saving'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, key: ValueKey('saveIcon')),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 800 : double.infinity,
              ),

              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ==========================
                    // IMAGE SECTION
                    // ==========================
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text("Farm Picture",
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),

                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _pickedImage != null
                                  ? Image.file(
                                      _pickedImage!,
                                      width: double.infinity,
                                      height: 200,
                                      fit: BoxFit.cover,
                                    )
                                  : (_imageUrl != null &&
                                          _imageUrl!.isNotEmpty)
                                      ? Image.network(
                                          _imageUrl!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: double.infinity,
                                          height: 200,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image,
                                              size: 60, color: Colors.grey),
                                        ),
                            ),

                            const SizedBox(height: 12),

                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo),
                              label: const Text("Change Picture"),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==========================
                    // BASIC INFO CARD
                    // ==========================
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Basic Info'),
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: 'Farm name *',
                                prefixIcon: Icon(Icons.home_outlined),
                              ),
                              validator: _req,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _address,
                              decoration: const InputDecoration(
                                labelText: 'Address / Barangay *',
                                prefixIcon: Icon(Icons.location_on_outlined),
                              ),
                              validator: _req,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _areaHa,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Area (hectares)',
                                prefixIcon: Icon(Icons.square_foot),
                                helperText: 'Example: 1.5',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================
                    // SOIL CARD
                    // ==========================
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Soil'),
                            DropdownButtonFormField<String>(
                              value: _soilType,
                              items: _soilTypes
                                  .map((t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _soilType = v),
                              decoration: const InputDecoration(
                                labelText: 'Soil type',
                                prefixIcon: Icon(Icons.terrain_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _soilPh,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Soil pH',
                                prefixIcon: Icon(Icons.show_chart),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==========================
                    // PLANTING & IRRIGATION
                    // ==========================
                    isWide
                        ? Row(
                            children: [
                              Expanded(child: _plantingCard()),
                              const SizedBox(width: 12),
                              Expanded(child: _irrigationCard()),
                            ],
                          )
                        : Column(
                            children: [
                              _plantingCard(),
                              const SizedBox(height: 12),
                              _irrigationCard(),
                            ],
                          ),

                    const SizedBox(height: 12),

                    // ==========================
                    // DISEASE CARD
                    // ==========================
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionLabel('Disease / Pest'),

                            SwitchListTile(
                              value: _anthracnose,
                              onChanged: (v) =>
                                  setState(() => _anthracnose = v),
                              title: const Text('Anthracnose observed'),
                              secondary:
                                  const Icon(Icons.warning_amber_rounded),
                              contentPadding: EdgeInsets.zero,
                            ),

                            SwitchListTile(
                              value: _powderyMildew,
                              onChanged: (v) =>
                                  setState(() => _powderyMildew = v),
                              title: const Text('Powdery Mildew observed'),
                              secondary: const Icon(Icons.bug_report_outlined),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ==========================
                    // BUTTONS
                    // ==========================
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () {
                                    Navigator.of(context).maybePop(false);
                                  },
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveFarm,
                            icon: AnimatedSwitcher(
                              duration:
                                  const Duration(milliseconds: 250),
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                            ),
                            label:
                                Text(_saving ? 'Saving...' : 'Update Farm'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // CARD BUILDERS
  Widget _plantingCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Planting'),
            TextFormField(
              controller: _plantingYear,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Planting year',
                prefixIcon: Icon(Icons.calendar_month),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _irrigationCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Irrigation'),
            DropdownButtonFormField<String>(
              value: _irrigationType,
              items: _irrigationTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _irrigationType = v),
              decoration: const InputDecoration(
                labelText: 'Irrigation type',
                prefixIcon: Icon(Icons.water_drop_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
