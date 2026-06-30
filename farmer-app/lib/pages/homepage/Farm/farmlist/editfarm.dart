import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/interactions.dart';

class EditFarmPage extends StatefulWidget {
  final String farmId;

  const EditFarmPage({super.key, required this.farmId});

  @override
  State<EditFarmPage> createState() => _EditFarmPageState();
}

class _EditFarmPageState extends State<EditFarmPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  final TextEditingController areaHaCtrl = TextEditingController();
  final TextEditingController soilTypeCtrl = TextEditingController();
  final TextEditingController soilPhCtrl = TextEditingController();
  final TextEditingController irrigationCtrl = TextEditingController();

  bool anthracnose = false;
  bool powderyMildew = false;

  String? imageUrl;
  File? newImageFile;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFarmData();
  }

  Future<void> loadFarmData() async {
    final doc = await FirebaseFirestore.instance
        .collection("farms")
        .doc(widget.farmId)
        .get();

    final data = doc.data()!;

    nameCtrl.text = data['name'] ?? '';
    addressCtrl.text = data['address'] ?? '';
    areaHaCtrl.text = (data['areaHa'] ?? '').toString();

    soilTypeCtrl.text = data['soil']?['type'] ?? '';
    soilPhCtrl.text = (data['soil']?['ph'] ?? '').toString();

    irrigationCtrl.text = data['irrigation']?['type'] ?? '';

    anthracnose = data['diseasePest']?['anthracnose'] == true;
    powderyMildew = data['diseasePest']?['powderyMildew'] == true;

    imageUrl = data['imageUrl'];

    setState(() => loading = false);
  }

  Future<void> pickNewImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => newImageFile = File(picked.path));
    }
  }

  Future<String?> uploadImage(File file) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseStorage.instance
        .ref()
        .child("farm_images")
        .child(uid)
        .child("${widget.farmId}.jpg");

    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> saveFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);

    String? finalImageUrl = imageUrl;

    if (newImageFile != null) {
      finalImageUrl = await uploadImage(newImageFile!);
    }

    await FirebaseFirestore.instance
        .collection("farms")
        .doc(widget.farmId)
        .update({
      "name": nameCtrl.text,
      "address": addressCtrl.text,
      "areaHa": double.tryParse(areaHaCtrl.text) ?? 0,

      "soil": {
        "type": soilTypeCtrl.text,
        "ph": double.tryParse(soilPhCtrl.text) ?? 0,
      },

      "irrigation": {
        "type": irrigationCtrl.text,
      },

      "diseasePest": {
        "anthracnose": anthracnose,
        "powderyMildew": powderyMildew,
      },

      "imageUrl": finalImageUrl,
      "updatedAt": Timestamp.now(),
    });

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Farm")),
      body: SingleChildScrollView(
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
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: "Farm Name",
                        prefixIcon: Icon(Icons.agriculture_outlined),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Farm name can't be empty" : null,
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: addressCtrl,
                      decoration: const InputDecoration(
                        labelText: "Address",
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: areaHaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Area (hectares)",
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
                    TextFormField(
                      controller: soilTypeCtrl,
                      decoration: const InputDecoration(
                        labelText: "Soil Type",
                        prefixIcon: Icon(Icons.terrain_outlined),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: soilPhCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Soil pH",
                        prefixIcon: Icon(Icons.science_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space4),

              // Irrigation
              const SectionHeader('Irrigation'),
              AppCard(
                child: TextFormField(
                  controller: irrigationCtrl,
                  decoration: const InputDecoration(
                    labelText: "Irrigation Type",
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
                      title: const Text("Anthracnose"),
                      value: anthracnose,
                      onChanged: (v) => setState(() => anthracnose = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text("Powdery Mildew"),
                      value: powderyMildew,
                      onChanged: (v) => setState(() => powderyMildew = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.space5),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saveFarm,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tappable farm-photo picker showing the new pick, the existing remote
  /// image, or a placeholder — each with a "Change" affordance.
  Widget _photoField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget overlayChip() => Positioned(
      right: AppTheme.space2,
      bottom: AppTheme.space2,
      child: Container(
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
            Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );

    Widget content;
    if (newImageFile != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.file(newImageFile!, fit: BoxFit.cover),
          overlayChip(),
        ],
      );
    } else if (imageUrl != null) {
      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(imageUrl!, fit: BoxFit.cover),
          overlayChip(),
        ],
      );
    } else {
      content = Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 40, color: scheme.primary),
            const SizedBox(height: AppTheme.space2),
            Text(
              'Choose farm picture',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Pressable(
      onTap: pickNewImage,
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: SizedBox(width: double.infinity, height: 180, child: content),
      ),
    );
  }
}
