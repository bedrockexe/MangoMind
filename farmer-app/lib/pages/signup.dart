import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _RegisterForm();
}

class _RegisterForm extends State<Signup> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirmpass = TextEditingController();
  bool _loading = false;
  bool _isConfirmValid = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  final namePattern = r'^[A-Za-z\s]+$';
  final emailPattern = r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,}$';
  final phPhonePattern = r'^(?:\+?63|0)9\d{9}$'; // PH mobile
  final strongPassPattern = r'^.{6,}$';

  String? regexValidator({
    required String label,
    required String pattern,
    required String? value,
    String? hint,
  }) {
    if (value == null || value.isEmpty) return '$label is required';
    final ok = RegExp(pattern).hasMatch(value);
    return ok ? null : (hint ?? 'Invalid $label');
  }

  @override
  void initState() {
    super.initState();
    _password.addListener(_validatePassword);
    _confirmpass.addListener(_validateConfirm);
  }

  void _validatePassword() {
    final text = _password.text;
    setState(() {
      _isConfirmValid = _confirmpass.text == text;
    });
  }

  void _validateConfirm() {
    setState(() {
      _isConfirmValid = _confirmpass.text == _password.text;
    });
  }

  OutlineInputBorder _borderFor({required bool touched, required bool ok}) {
    final scheme = Theme.of(context).colorScheme;
    final color = !touched
        ? scheme.outline // default
        : (ok ? scheme.primary : scheme.error);
    return OutlineInputBorder(borderSide: BorderSide(color: color, width: 2));
  }

  @override
  void dispose() {
    _firstname.dispose();
    _lastname.dispose();
    _contact.dispose();
    _address.dispose();
    _email.dispose();
    _password.dispose();
    _confirmpass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final uid = cred.user!.uid;
      final data = {
        'uid': uid,
        'first_name': _firstname.text.trim(),
        'last_name': _lastname.text.trim(),
        'contact_number': _contact.text.trim(),
        'address': _address.text.trim(),
        'registration_date': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account created!')));

      Navigator.pushNamed(context, '/success');
    } on FirebaseAuthException catch (e) {
      debugPrint('AUTH code=${e.code} message=${e.message}');
      final msg =
          {
            'email-already-in-use': 'This email is already registered.',
            'weak-password': 'Password is too weak (min 6 chars).',
            'invalid-email': 'Please enter a valid email.',
          }[e.code] ??
          'Registration failed: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on FirebaseException catch (e) {
      debugPrint('FIREBASE code=${e.code} message=${e.message}');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Database error: ${e.code}')));
    } catch (e) {
      debugPrint('OTHER error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 8.0),
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),

          // Title Header
          Padding(
            padding: const EdgeInsets.all(15),
            child: Text(
              'Hi! Create an account to get started',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
          ),

          // Forms
          Padding(
            padding: EdgeInsets.all(15),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // First Name
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _firstname,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => regexValidator(
                        label: 'First Name',
                        pattern: namePattern,
                        value: v,
                        hint: 'Name contains invalid characters',
                      ),
                    ),
                  ),

                  // Last Name
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _lastname,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Last Name',
                        pattern: namePattern,
                        value: v,
                        hint: 'Name contains invalid characters',
                      ),
                    ),
                  ),

                  // Contact Number
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _contact,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Contact Number',
                        pattern: phPhonePattern,
                        value: v,
                        hint: 'number should be in PH Format. Ex. 0933-',
                      ),
                    ),
                  ),

                  // Address
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _address,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Home Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Address is required';
                        }
                        return null;
                      },
                    ),
                  ),

                  // Email Address
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _email,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Email Address',
                        pattern: emailPattern,
                        value: v,
                        hint: 'Invalid email address',
                      ),
                    ),
                  ),

                  // Password
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: "Password",
                        hintText: "Enter strong password",
                        border: const OutlineInputBorder(),
                        // Icons in form fields
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_password.text.isNotEmpty)
                              // Check or Error Icon
                              Icon(
                                (!RegExp(r'^.{6,}$').hasMatch(_password.text))
                                    ? Icons.error
                                    : Icons.check_circle,
                                color:
                                    (!RegExp(
                                      r'^.{6,}$',
                                    ).hasMatch(_password.text))
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),

                            // See Password Icon
                            IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showPassword = !_showPassword;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Password',
                        pattern: strongPassPattern,
                        value: v,
                        hint: 'Password should contain atleast 6 characters',
                      ),
                    ),
                  ),

                  // Confirm Password
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: TextFormField(
                      controller: _confirmpass,
                      obscureText: !_showConfirm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        hintText: "Re-enter password",
                        border: const OutlineInputBorder(),
                        enabledBorder: _borderFor(
                          touched: _confirmpass.text.isNotEmpty,
                          ok: _isConfirmValid,
                        ),
                        focusedBorder: _borderFor(
                          touched: _confirmpass.text.isNotEmpty,
                          ok: _isConfirmValid,
                        ),
                        errorBorder: _borderFor(touched: true, ok: false),
                        focusedErrorBorder: _borderFor(
                          touched: true,
                          ok: false,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_confirmpass.text.isNotEmpty)
                              Icon(
                                _isConfirmValid
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _isConfirmValid
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                            IconButton(
                              icon: Icon(
                                _showConfirm
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                            ),
                          ],
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _password.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Create Account button
          Padding(
            padding: EdgeInsets.all(15),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
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
