import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';

class AddAccount extends StatefulWidget {
  const AddAccount({super.key});

  @override
  State<AddAccount> createState() => _RegisterForm();
}

class _RegisterForm extends State<AddAccount> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _lastname = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  final _password = TextEditingController();
  final _confirmpass = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

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
      // Create the account via the Cloud Function so the admin stays signed
      // in (the client SDK would replace the current session).
      final callable = FirebaseFunctions.instance.httpsCallable('createUser');
      await callable.call(<String, dynamic>{
        'email': _email.text.trim(),
        'password': _password.text,
        'firstName': _firstname.text.trim(),
        'lastName': _lastname.text.trim(),
        'contact': _contact.text.trim(),
        'address': _address.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Account created!')));

      Navigator.pop(context);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('FUNCTION code=${e.code} message=${e.message}');
      final msg = e.code == 'permission-denied'
          ? 'You are not authorized to add accounts.'
          : (e.message ?? 'Registration failed.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      debugPrint('OTHER error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Something went wrong.')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passOk = RegExp(r'^.{6,}$').hasMatch(_password.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Add user account')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.space4),
        children: [
          const SectionHeader('Account details'),
          AppCard(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _firstname,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'First name',
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
                      labelText: 'Last name',
                      prefixIcon: Icon(Icons.person),
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
                      labelText: 'Contact number',
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
                      labelText: 'Home address',
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
                      labelText: 'Email address',
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
                      labelText: 'Password',
                      hintText: 'Enter strong password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_password.text.isNotEmpty)
                            Icon(
                              passOk ? Icons.check_circle : Icons.error,
                              color: passOk ? AppTheme.brandGreen : scheme.error,
                            ),
                          IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
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
                ],
              ),
            ),
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create account'),
            ),
          ),
        ],
      ),
    );
  }
}
