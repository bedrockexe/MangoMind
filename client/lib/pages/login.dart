// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:insights/pages/services/session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:insights/pages/landing.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late AnimationController _ctrl;
  late Animation<double> _avatarScale;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;
  bool _obscure = true;
  bool _loading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _avatarScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
    );

    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 1.0, curve: Curves.easeIn),
    );

    // start animations
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'invalid-credential':
        return 'Email or Password is incorrect.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Error. Please wait and try again later.';
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      // Admin accounts (custom claim) must use the admin app, not this one.
      final token = await cred.user?.getIdTokenResult(true);
      if (token?.claims?['admin'] == true) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _errorText = 'Admin login is not allowed here.');
        return;
      }

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

  Widget _buildTextField({
    required String label,
    required bool obscure,
    required TextEditingController controller,
    required TextInputType type,
    Widget? suffix,
  }) {
    return FadeTransition(
      opacity: _cardFade,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
            border: OutlineInputBorder(),
            suffixIcon: (label == "Password")
                ? IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: (label == "Email")
              ? (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final email = v.trim();
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                    return 'Enter a valid email';
                  }
                  if (!(_errorText == null)) {
                    return _errorText;
                  }
                  return null;
                }
              : (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (!(_errorText == null)) {
                    return _errorText;
                  }
                  return null;
                },
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF07A824),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 12,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Landing()),
                  );
                },
              ),
            ),

            Center(
              child: SingleChildScrollView(
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        // The white card
                        Container(
                          width: screen.width * 0.85,
                          margin: EdgeInsets.only(top: screen.height * 0.08),
                          padding: const EdgeInsets.fromLTRB(22, 80, 22, 26),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                offset: Offset(6, 12),
                                blurRadius: 18,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Sweet Insights',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Text(
                                'Account Login',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email field
                                    _buildTextField(
                                      label: 'Email',
                                      obscure: false,
                                      controller: _email,
                                      type: TextInputType.emailAddress,
                                    ),
                                    // Password field with eye icon
                                    _buildTextField(
                                      label: 'Password',
                                      obscure: _obscure,
                                      suffix: GestureDetector(
                                        onTap: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          child: Icon(
                                            _obscure
                                                ? Icons.visibility
                                                : Icons.visibility_off,
                                            size: 22,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ),
                                      controller: _password,
                                      type: TextInputType.text,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/forgot');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 0),
                                  ),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Big gradient button
                              LoginButton(
                                onLogin: () async {
                                  await _signIn();
                                },
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),

                        // avatar circle overlapping top of card
                        Positioned(
                          top: 0,
                          child: ScaleTransition(
                            scale: _avatarScale,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.green.shade800,
                                  width: 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x25000000),
                                    blurRadius: 12,
                                    offset: Offset(4, 8),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(8),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.white,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => const Icon(
                                      Icons.local_grocery_store,
                                      size: 48,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // subtle bottom rounded green overlay to mimic phone frame in mock
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF07A824), Color(0xFF07A824)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginButton extends StatefulWidget {
  /// Provide the async login function that returns when login completes.
  final Future<void> Function() onLogin;
  const LoginButton({super.key, required this.onLogin});

  @override
  State<LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<LoginButton> {
  bool isLoading = false;
  bool isPressed = false;

  Future<void> _handleTap() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      await widget.onLogin();
    } catch (e) {
      // handle error (snackbars, setState etc.)
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double scale = isPressed ? 0.98 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: (_) {
          if (!isLoading) setState(() => isPressed = true);
        },
        onTapUp: (_) {
          if (!isLoading) setState(() => isPressed = false);
        },
        onTapCancel: () {
          if (!isLoading) setState(() => isPressed = false);
        },
        onTap: _handleTap,
        child: Opacity(
          // subtle disabled look while loading
          opacity: isLoading ? 0.95 : 1.0,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2CB934), Color(0xFF8FD66D)],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(0, 8),
                  blurRadius: 20,
                ),
              ],
            ),
            // AnimatedSwitcher swaps text <-> loader smoothly
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: isLoading
                    ? Row(
                        key: const ValueKey('loading'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Logging in...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        'Login',
                        key: ValueKey('label'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
