import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Admin_mainpage/navigator.dart';
import '../theme/app_theme.dart';
import '../theme/transitions.dart';
import '../pages/auth_header.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Could not sign in. Please try again.';
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = userCredential.user;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final result = await user.getIdTokenResult(true);
      final isAdmin = result.claims?['admin'] == true;
      if (!mounted) return;
      if (isAdmin) {
        Navigator.pushReplacement(context, appRoute(const MainPage()));
      } else {
        await _auth.signOut();
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Access denied: admin privileges required.';
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error = _mapAuthError(e);
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Could not sign in. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          const AuthHeader(
            title: 'Admin Console',
            subtitle: 'Sign in to manage MangoMind',
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'admin@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: AppTheme.space4),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: scheme.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppTheme.space5),
                    FilledButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: AppTheme.space5),
                    Center(
                      child: Text(
                        '© ${DateTime.now().year} MangoMind',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
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
