import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _emailError;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    // Pre-fill with signed-in user's email if available
    final currentEmail = FirebaseAuth.instance.currentUser?.email;
    if (currentEmail != null) {
      _emailCtrl.text = currentEmail;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'Enter your email';
    // Simple format check
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(val);
    if (!ok) return 'Enter a valid email';
    if (_emailError != null) return _emailError;
    return null;
  }

  Future<void> _sendReset() async {
    setState(() {
      _emailError = null;
      _globalError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset email sent. Check your inbox.')),
      );
      Navigator.of(context).pop(); // optional: close page after success
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _emailError = 'No account found with this email';
            break;
          case 'invalid-email':
            _emailError = 'This email address is invalid';
            break;
          case 'missing-email':
            _emailError = 'Please enter your email';
            break;
          case 'network-request-failed':
            _globalError = 'Network error. Try again.';
            break;
          default:
            _globalError = 'Something went wrong (${e.code}). Try again.';
        }
      });
      _formKey.currentState!.validate(); // show red border + errorText
    } catch (_) {
      setState(() => _globalError = 'Unexpected error. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_globalError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _globalError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                    helperText:
                        'We’ll send a password reset link to this email',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _sendReset,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset email'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
