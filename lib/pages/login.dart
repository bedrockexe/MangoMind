// lib/pages/login.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:insights/pages/services/session.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Possible errors
  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found with that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        // return 'Sign in failed. (${e.code})';
        return 'Wrong email or password.';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      await SessionService.startSession();

      if (!mounted) return;

      Navigator.pushNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() => _errorText = _mapAuthError(e));
    } catch (_) {
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Back Button
                Row(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.green,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),

                // Header
                Padding(
                  padding: EdgeInsets.all(15),
                  child: Center(
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/logo.png',
                          width: 120, // optional: resize
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        Text(
                          'Sweet Insights',
                          style: GoogleFonts.poppins(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        Text("Account Login", style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),

                // Email
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    border: OutlineInputBorder(),
                    errorText: (_errorText == null) ? null : '',
                    errorStyle: const TextStyle(height: 1, fontSize: 12),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    final email = v.trim();
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(email)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),

                // Divider
                const SizedBox(height: 12),

                // Password
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                    border: const OutlineInputBorder(),
                    errorText: (_errorText == null) ? null : '',
                    errorStyle: const TextStyle(height: 1, fontSize: 12),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    return null;
                  },
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),

                // Error text
                if (_errorText != null) ...[
                  Text(_errorText!, style: const TextStyle(color: Colors.red)),
                ],

                // Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, '/forgot'),
                      child: const Text('Forgot password?'),
                    ),
                  ],
                ),

                // Divider
                const SizedBox(height: 16),

                // Login button
                SizedBox(
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
                    onPressed: _loading ? null : _signIn,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
