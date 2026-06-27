import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _loadUserData() async {
    final user = widget.farmer!;

    setState(() {
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
    });
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

      // Only update UI or pop if still mounted
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User updated.')));

      Navigator.pop(context, true);

      print('Update result:');
      print(data['userRecord']['email_address']);
      print('Type result:');
      print(data['userRecord']['email_address'].runtimeType);

      Map<String, dynamic> userRecord = {
        'first_name': data['userRecord']['first_name'],
        'last_name': data['userRecord']['last_name'],
        'email_address': data['userRecord']['email_address'],
        'contact_number': data['userRecord']['contactNumber'],
        'address': data['userRecord']['address'],
      };

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => UserDetailsPage(farmer: userRecord),
        ),
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
      // Only set state if still in widget tree
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = widget.farmer?['first_name'];
    final String lastName = widget.farmer?['last_name'];
    final String address = widget.farmer?['address'];
    final String contactNumber = widget.farmer?['contact_number'];
    final String email = widget.farmer?['email_address'];
    final Color avatarColor = Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        backgroundColor: Colors.green.shade600,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero-animated Avatar and Name
                  Center(
                    child: Hero(
                      tag: 'user_avatar_${widget.farmer?['name'] ?? 'user'}',
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: avatarColor,
                        child: Text(
                          firstName[0].toUpperCase() +
                              lastName[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'User Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.green.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              Icons.person,
                              'First Name',
                              firstName,
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              Icons.person_outline,
                              'Last Name',
                              lastName,
                            ),
                            _buildDivider(),
                            _buildDetailRow(Icons.home, 'Address', address),
                            _buildDivider(),
                            _buildDetailRow(
                              Icons.phone,
                              'Contact Number',
                              contactNumber,
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              Icons.email,
                              'Email Address',
                              email,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _showEditProfileDialog,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Edit Profile'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _showDeleteConfirmationDialog(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.green, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Divider(
      thickness: 1,
      color: Colors.grey,
      indent: 10,
      endIndent: 10,
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header row with title and close button
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Edit Profile',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // First Row: First + Last name
                      Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: TextFormField(
                                controller: _firstNameController,
                                keyboardType: TextInputType.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  labelText: 'First name',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
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
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black,
                                ),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                  labelText: 'Last name',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
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

                      const SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelText: 'Email',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
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

                      const SizedBox(height: 12),

                      // Contact + Address row
                      TextFormField(
                        controller: _contactController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelText: 'Contact number',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
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

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _addressController,
                        keyboardType: TextInputType.streetAddress,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelText: 'Address',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
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

                      const SizedBox(height: 12),

                      // Password with helper tip
                      TextFormField(
                        controller: _passwordController,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelText: 'Password',
                          helperText: 'Leave empty to keep current password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 12,
                          ),
                        ),
                        validator: (v) {
                          // if user leaves password blank we allow it (means no change)
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

                      const SizedBox(height: 18),

                      // Actions
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
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
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
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
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Account'),
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

                          // ✅ Then close the UserDetailsPage
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
                          SnackBar(
                            content: Text('Delete failed: ${e.message}'),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Delete failed: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _isDeleting = false);
                      }
                    },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
