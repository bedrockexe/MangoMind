// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:insights/theme/app_theme.dart';
import 'package:insights/theme/components.dart';
import 'package:insights/theme/transitions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:insights/pages/homepage/Settings/forgotpass.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({super.key});

  @override
  State<ChangePassword> createState() => _PasswordForm();
}

class _PasswordForm extends State<ChangePassword> {
  final _formKey = GlobalKey<FormState>();

  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  String? _currentError;
  String? _newError;
  String? _confirmError;
  String? _globalError;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  String? _validateCurrent(String? v) {
    if ((v ?? '').isEmpty) return 'Enter your current password';
    // If an async reauth error set this:
    if (_currentError != null) return _currentError;
    return null;
  }

  String? _validateNew(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'Enter a new password';

    final hasMinLen = val.length >= 6;
    // final hasLetter = RegExp(r'[A-Za-z]').hasMatch(val);
    // final hasNumber = RegExp(r'\d').hasMatch(val);
    if (!hasMinLen) {
      return 'Password must be 6+ characters long';
    }
    if (_newError != null) return _newError;
    return null;
  }

  String? _validateConfirm(String? v) {
    final val = (v ?? '').trim();
    if (val.isEmpty) return 'Re-enter the new password';
    if (val != _newCtrl.text.trim()) return 'Passwords do not match';
    if (_confirmError != null) return _confirmError;
    return null;
  }

  Future<void> _handleChange() async {
    // Clear async error placeholders so validators re-run cleanly
    setState(() {
      _currentError = null;
      _newError = null;
      _confirmError = null;
      _globalError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _globalError = 'No user is signed in.';
        });
        return;
      }

      final email = user.email;
      if (email == null) {
        setState(() {
          _globalError = 'Password change is not available for this account.';
        });
        return;
      }

      // 1) Reauthenticate using current password
      final cred = EmailAuthProvider.credential(
        email: email,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);

      // 2) Update to the new password
      await user.updatePassword(_newCtrl.text.trim());

      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully')),
      );
      Navigator.of(context).pop(); // optional: close page after success
    } on FirebaseAuthException catch (e) {
      // Map Firebase errors to field/global errors + revalidate to show red borders
      setState(() {
        switch (e.code) {
          case 'invalid-credential':
            _currentError = 'Incorrect current password';
            _currentFocus.requestFocus();
            break;
          case 'weak-password':
            _newError = 'That password is too weak';
            _newFocus.requestFocus();
            break;
          case 'requires-recent-login':
            _globalError =
                'For security, please sign in again and try changing your password.';
            break;
          case 'network-request-failed':
            _globalError =
                'Network error. Check your connection and try again.';
            break;
          default:
            _globalError =
                'Something went wrong (${e.code}). Please try again.';
        }
      });
      _formKey.currentState!.validate(); // show errors inline
    } catch (_) {
      setState(() {
        _globalError = 'Unexpected error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration({
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      errorText: errorText, // forces red border + message
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
        tooltip: obscure ? 'Show' : 'Hide',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Change password'), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_globalError != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppTheme.space4),
                    padding: const EdgeInsets.all(AppTheme.space3),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: AppTheme.cardRadius,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: scheme.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.space2),
                        Expanded(
                          child: Text(
                            _globalError!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SectionHeader('Verify it\'s you'),
                AppCard(
                  child: TextFormField(
                    controller: _currentCtrl,
                    focusNode: _currentFocus,
                    obscureText: !_showCurrent,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(
                      label: 'Current password',
                      obscure: !_showCurrent,
                      onToggle: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      errorText: _currentError,
                    ),
                    validator: _validateCurrent,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        appRoute(const PasswordResetPage()),
                      );
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),

                const SizedBox(height: AppTheme.space3),
                const SectionHeader('New password'),
                AppCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _newCtrl,
                        focusNode: _newFocus,
                        obscureText: !_showNew,
                        textInputAction: TextInputAction.next,
                        decoration:
                            _decoration(
                              label: 'New password',
                              obscure: !_showNew,
                              onToggle: () =>
                                  setState(() => _showNew = !_showNew),
                              errorText: _newError,
                            ).copyWith(
                              helperText:
                                  'Password should be 6+ characters long',
                            ),
                        validator: _validateNew,
                      ),
                      const SizedBox(height: AppTheme.space4),
                      TextFormField(
                        controller: _confirmCtrl,
                        focusNode: _confirmFocus,
                        obscureText: !_showConfirm,
                        textInputAction: TextInputAction.done,
                        decoration: _decoration(
                          label: 'Confirm new password',
                          obscure: !_showConfirm,
                          onToggle: () =>
                              setState(() => _showConfirm = !_showConfirm),
                          errorText: _confirmError,
                        ),
                        validator: _validateConfirm,
                        onFieldSubmitted: (_) => _handleChange(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.space5),
                FilledButton.icon(
                  onPressed: _loading ? null : _handleChange,
                  icon: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_loading ? 'Updating...' : 'Update password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
