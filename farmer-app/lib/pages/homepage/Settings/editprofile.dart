import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountEditPage extends StatefulWidget {
  const AccountEditPage({super.key});

  @override
  State<AccountEditPage> createState() => _AccountEditPageState();
}

class _AccountEditPageState extends State<AccountEditPage> {
  final _formKey = GlobalKey<FormState>();

  final _first = TextEditingController();
  final _last = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  String? _photoUrl;
  File? _newPhotoFile;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _loadError = 'No user signed in.';
          _loading = false;
        });
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? {};

      _first.text = (data['first_name'] ?? '').toString();
      _last.text = (data['last_name'] ?? '').toString();
      _phone.text = (data['phone'] ?? data['contact'] ?? '').toString();
      _address.text = (data['address'] ?? '').toString();
      _photoUrl = (data['photo_url'] ?? data['profilePath'])?.toString();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loadError = 'Failed to load profile. ${e.toString()}';
        _loading = false;
      });
    }
  }

  // --- NEW: pick image from gallery ---
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _newPhotoFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not pick image: $e')));
    }
  }

  // --- NEW: upload file to Firebase Storage and return URL ---
  Future<String?> _uploadPhoto(String uid) async {
    if (_newPhotoFile == null) return _photoUrl; // unchanged
    final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
    await ref.putFile(
      _newPhotoFile!,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  String? _required(String? v, {String label = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Contact number is required';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    // Example: PH numbers (10–11 digits). Adjust as needed for your app.
    if (digits.length < 10 || digits.length > 11) {
      return 'Enter a valid contact number';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uploadedUrl = await _uploadPhoto(user.uid);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        if (uploadedUrl != null) 'photo_url': uploadedUrl,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      Navigator.pop(context); // go back after saving
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    ImageProvider? image;
    if (_newPhotoFile != null) {
      image = FileImage(_newPhotoFile!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      image = NetworkImage(_photoUrl!);
    }

    final initials = (_first.text.isNotEmpty || _last.text.isNotEmpty)
        ? '${_first.text.isNotEmpty ? _first.text[0] : ''}${_last.text.isNotEmpty ? _last.text[0] : ''}'
              .toUpperCase()
        : 'U';

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: image,
          child: image == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _saving ? null : _pickImage,
              icon: const Icon(Icons.photo),
              label: const Text('Change photo'),
            ),
            const SizedBox(width: 12),
            if (_photoUrl != null || _newPhotoFile != null)
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        setState(() {
                          _newPhotoFile = null;
                          _photoUrl = null;
                        });
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Edit Account')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Account')),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _avatar(),
              const SizedBox(height: 20),

              TextFormField(
                controller: _first,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, label: 'First name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, label: 'Last name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Contact number',
                  hintText: 'e.g. 0917 123 4567',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => _required(v, label: 'Address'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
