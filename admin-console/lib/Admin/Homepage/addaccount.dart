import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add User Account'),
        backgroundColor: Colors.green.shade600,
      ),
      body: ListView(
        children: [
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
                                    ? Colors.red
                                    : Colors.green,
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
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
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
