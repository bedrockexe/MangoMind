import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';

class UserDetailsPage extends StatefulWidget {
  final Map<String, dynamic>? farmer;

  const UserDetailsPage({super.key, this.farmer});

  @override
  State<UserDetailsPage> createState() => _UserDetailsPageState();
}

class _UserDetailsPageState extends State<UserDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  late TextEditingController _contactController;
  late TextEditingController _addressController;
  final TextEditingController _passwordController = TextEditingController();
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;

  HttpsCallable get _updateUserCallable =>
      FirebaseFunctions.instance.httpsCallable('updateUser');
  HttpsCallable get _deleteUserCallable =>
      FirebaseFunctions.instance.httpsCallable('deleteUser');

  void _loadUserData() {
    final user = widget.farmer ?? const {};
    _firstNameController = TextEditingController(
      text: user['first_name']?.toString() ?? '',
    );
    _lastNameController = TextEditingController(
      text: user['last_name']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: user['email_address']?.toString() ?? '',
    );
    _contactController = TextEditingController(
      text:
          user['contactNumber']?.toString() ??
          user['contact_number']?.toString() ??
          '',
    );
    _addressController = TextEditingController(
      text: user['address']?.toString() ?? '',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _initials() {
    final f = (widget.farmer?['first_name'] ?? '').toString().trim();
    final l = (widget.farmer?['last_name'] ?? '').toString().trim();
    final s = ((f.isNotEmpty ? f[0] : '') + (l.isNotEmpty ? l[0] : ''))
        .toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  Future<void> _updateUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    if (widget.farmer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User data is missing.')),
      );
      return;
    }

    final payload = {
      'uid': widget.farmer!['uid'],
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'emailAddress': _emailController.text.trim(),
      'contactNumber': _contactController.text.trim(),
      'address': _addressController.text.trim(),
      'password': _passwordController.text.trim(),
    };

    try {
      final result = await _updateUserCallable.call(payload);
      final data = result.data;

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User updated.')));

      Navigator.pop(context, true);

      Map<String, dynamic> userRecord = {
        'first_name': data['userRecord']['first_name'],
        'last_name': data['userRecord']['last_name'],
        'email_address': data['userRecord']['email_address'],
        'contact_number': data['userRecord']['contactNumber'],
        'address': data['userRecord']['address'],
      };

      Navigator.pushReplacement(
        context,
        appRoute(UserDetailsPage(farmer: userRecord)),
      );
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: ${e.message}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final firstName = (widget.farmer?['first_name'] ?? '').toString();
    final lastName = (widget.farmer?['last_name'] ?? '').toString();
    final address = (widget.farmer?['address'] ?? '—').toString();
    final contactNumber = (widget.farmer?['contact_number'] ?? '—').toString();
    final email = (widget.farmer?['email_address'] ?? '—').toString();
    final fullName = '$firstName $lastName'.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('User details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Hero(
                  tag: 'user_avatar_${widget.farmer?['name'] ?? 'user'}',
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      _initials(),
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space4),
              Center(
                child: Text(
                  fullName.isEmpty ? 'Unnamed user' : fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              const SectionHeader('User information'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.person, 'First name', firstName),
                    _buildDivider(),
                    _buildDetailRow(
                      Icons.person_outline,
                      'Last name',
                      lastName,
                    ),
                    _buildDivider(),
                    _buildDetailRow(Icons.home, 'Address', address),
                    _buildDivider(),
                    _buildDetailRow(Icons.phone, 'Contact number', contactNumber),
                    _buildDivider(),
                    _buildDetailRow(Icons.email, 'Email address', email),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showDeleteConfirmationDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.5),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space1),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary, size: 24),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() =>
      Divider(height: 20, color: Theme.of(context).colorScheme.outlineVariant);

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space2),
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextFormField(
                                controller: _firstNameController,
                                keyboardType: TextInputType.name,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'First name is required';
                                  }
                                  if (!RegExp(
                                    r'^[a-zA-Z\s]+$',
                                  ).hasMatch(v.trim())) {
                                    return 'Only letters allowed';
                                  }
                                  if (_error != null) return _error;
                                  return null;
                                },
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: TextFormField(
                                controller: _lastNameController,
                                keyboardType: TextInputType.name,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: const InputDecoration(
                                  labelText: 'Last name',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Last name is required';
                                  }
                                  if (!RegExp(
                                    r'^[a-zA-Z\s]+$',
                                  ).hasMatch(v.trim())) {
                                    return 'Only letters allowed';
                                  }
                                  if (_error != null) return _error;
                                  return null;
                                },
                                onChanged: (_) {
                                  if (_error != null) {
                                    setState(() => _error = null);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Email is required';
                          }
                          if (!RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v.trim())) {
                            return 'Enter a valid email';
                          }
                          if (_error != null) return _error;
                          return null;
                        },
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Contact number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Contact is required';
                          }
                          if (!RegExp(r'^\+?\d{10,15}$').hasMatch(v.trim())) {
                            return 'Enter a valid contact number';
                          }
                          if (_error != null) return _error;
                          return null;
                        },
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _addressController,
                        keyboardType: TextInputType.streetAddress,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Address',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Address is required';
                          }
                          if (_error != null) return _error;
                          return null;
                        },
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppTheme.space3),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          helperText: 'Leave empty to keep current password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (v.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          if (_error != null) return _error;
                          return null;
                        },
                        onChanged: (_) {
                          if (_error != null) setState(() => _error = null);
                        },
                      ),
                      const SizedBox(height: AppTheme.space4),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space2),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _updateUser,
                              icon: _isSaving
                                  ? const SizedBox.shrink()
                                  : const Icon(Icons.save),
                              label: _isSaving
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Update'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account'),
          content: const Text(
            'Are you sure you want to delete this account? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: _isDeleting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      if (mounted) setState(() => _isDeleting = true);

                      try {
                        if (widget.farmer != null) {
                          await _deleteUserCallable.call({
                            'uid': widget.farmer!['uid'],
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Account deleted successfully.'),
                            ),
                          );
                          navigator.pop();

                          if (Navigator.of(
                            context,
                            rootNavigator: true,
                          ).mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Error: User data is missing.'),
                            ),
                          );
                        }
                      } on FirebaseFunctionsException catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Delete failed: ${e.message}')),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Delete failed: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _isDeleting = false);
                      }
                    },
              child: Text('Delete', style: TextStyle(color: scheme.error)),
            ),
          ],
        );
      },
    );
  }
}
