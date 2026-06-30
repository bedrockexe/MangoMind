import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/pages/auth_header.dart';

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
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      borderSide: BorderSide(color: color, width: 2),
    );
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          AuthHeader(
            title: 'Create account',
            subtitle: 'Join MangoMind to get started',
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space5),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _firstname,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => regexValidator(
                        label: 'First Name',
                        pattern: namePattern,
                        value: v,
                        hint: 'Name contains invalid characters',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _lastname,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Last Name',
                        pattern: namePattern,
                        value: v,
                        hint: 'Name contains invalid characters',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _contact,
                      keyboardType: TextInputType.phone,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Contact Number',
                        pattern: phPhonePattern,
                        value: v,
                        hint: 'number should be in PH Format. Ex. 0933-',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _address,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Home Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Address is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => regexValidator(
                        label: 'Email Address',
                        pattern: emailPattern,
                        value: v,
                        hint: 'Invalid email address',
                      ),
                    ),
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: "Password",
                        hintText: "Enter strong password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_password.text.isNotEmpty)
                              Icon(
                                (!RegExp(r'^.{6,}$').hasMatch(_password.text))
                                    ? Icons.error
                                    : Icons.check_circle,
                                color:
                                    (!RegExp(
                                      r'^.{6,}$',
                                    ).hasMatch(_password.text))
                                    ? scheme.error
                                    : scheme.primary,
                              ),
                            IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
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
                    const SizedBox(height: AppTheme.space3),
                    TextFormField(
                      controller: _confirmpass,
                      obscureText: !_showConfirm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        hintText: "Re-enter password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        enabledBorder: _borderFor(
                          touched: _confirmpass.text.isNotEmpty,
                          ok: _isConfirmValid,
                        ),
                        focusedBorder: _borderFor(
                          touched: _confirmpass.text.isNotEmpty,
                          ok: _isConfirmValid,
                        ),
                        errorBorder: _borderFor(touched: true, ok: false),
                        focusedErrorBorder: _borderFor(touched: true, ok: false),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_confirmpass.text.isNotEmpty)
                              Icon(
                                _isConfirmValid
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _isConfirmValid
                                    ? scheme.primary
                                    : scheme.error,
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
                    const SizedBox(height: AppTheme.space5),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: Text(
                            'Log in',
                            style: TextStyle(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
