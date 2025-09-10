// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:insights/pages/services/session.dart';
import 'package:insights/pages/homepage/Settings/change.dart';
import 'package:insights/pages/homepage/Settings/editprofile.dart';
import 'package:insights/theme_controller.dart';

// Class for settings page
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _signOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      // If user log outs clear everything
      await FirebaseAuth.instance.signOut();

      await SessionService.clearSession();

      // Redirect to Login Page
      if (context.mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final curruser = FirebaseAuth.instance.currentUser;

    if (curruser == null) {
      return const Center(child: Text('No user logged in.'));
    }

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(curruser.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Failed to load: ${snap.error}'));
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('Profile not found.'));
        }

        final data = snap.data!.data()!;
        final photoUrl = (data['photo_url'] ?? data['profilePath'])?.toString();
        final firstName = data['first_name'] ?? '—';
        final lastName = data['last_name'] ?? '—';

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile with border
                    Container(
                      padding: const EdgeInsets.all(4), // border thickness
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue, // border color
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundImage:
                            (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 48,
                                color: Colors.white70,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // Email
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Text('Account'),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Edit profile'),
                      subtitle: const Text('Name, username, photo'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AccountEditPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.lock),
                      title: const Text('Change password'),
                      subtitle: const Text('Update your password'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChangePassword()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ——— App section (UI examples) ———
              Text('App', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: true,
                      onChanged: (_) {
                        // TODO: toggle notifications in your app
                      },
                      secondary: const Icon(Icons.notifications),
                      title: const Text('Notifications'),
                      subtitle: const Text('Receive alerts and updates'),
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Toggle Dark Mode'),
                      trailing: Switch(
                        value: ThemeController.instance.mode == ThemeMode.dark,
                        onChanged: (bool value) {
                          ThemeController.instance.setMode(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ——— Logout ———
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.08),
                  foregroundColor: Colors.red,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text(
                        'You will be returned to the login screen.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _signOut(context);
                  }
                },
                child: const Text('Log out'),
              ),
            ],
          ),
        );
      },
    );
  }
}
