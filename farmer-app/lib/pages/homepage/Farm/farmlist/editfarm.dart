import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              
              // IMAGE
              Center(
                child: GestureDetector(
                  onTap: pickNewImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: newImageFile != null
                        ? Image.file(newImageFile!,
                            width: 150, height: 150, fit: BoxFit.cover)
                        : imageUrl != null
                            ? Image.network(imageUrl!,
                                width: 150, height: 150, fit: BoxFit.cover)
                            : Container(
                                width: 150,
                                height: 150,
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.image, size: 60),
                              ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // NAME
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Farm Name"),
                validator: (v) =>
                    v!.isEmpty ? "Farm name can't be empty" : null,
              ),

              const SizedBox(height: 12),

              // ADDRESS
              TextFormField(
                controller: addressCtrl,
                decoration: const InputDecoration(labelText: "Address"),
              ),

              const SizedBox(height: 12),

              // AREA
              TextFormField(
                controller: areaHaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Area (hectares)"),
              ),

              const SizedBox(height: 12),

              // SOIL TYPE
              TextFormField(
                controller: soilTypeCtrl,
                decoration: const InputDecoration(labelText: "Soil Type"),
              ),

              const SizedBox(height: 12),

              // SOIL PH
              TextFormField(
                controller: soilPhCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Soil pH"),
              ),

              const SizedBox(height: 12),

              // IRRIGATION
              TextFormField(
                controller: irrigationCtrl,
                decoration: const InputDecoration(labelText: "Irrigation Type"),
              ),

              const SizedBox(height: 20),

              const Text("Diseases / Pests",
                  style: TextStyle(fontWeight: FontWeight.bold)),

              SwitchListTile(
                title: const Text("Anthracnose"),
                value: anthracnose,
                onChanged: (v) => setState(() => anthracnose = v),
              ),

              SwitchListTile(
                title: const Text("Powdery Mildew"),
                value: powderyMildew,
                onChanged: (v) => setState(() => powderyMildew = v),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saveFarm,
                  child: const Text("Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
