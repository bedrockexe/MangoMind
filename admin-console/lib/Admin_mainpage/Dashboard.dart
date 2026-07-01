import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sweet_insights_admin/Admin/Homepage/overview.dart';
import 'package:sweet_insights_admin/Admin/Homepage/farmersAccounts.dart';
import 'package:sweet_insights_admin/Login/login_page.dart';
import 'package:sweet_insights_admin/service/listuser.dart';
import 'package:sweet_insights_admin/ThemeController.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ListUserService listService = ListUserService();
  List<Map<String, dynamic>> _farmers = [];
  bool _loading = true;

  Future<void> listUsers() async {
    try {
      final users = await listService.listUsers();
      if (!mounted) return;
      setState(() {
        _farmers = users;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    listUsers();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(context, appRoute(LoginPage()));
  }

  void _toggleTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ThemeController.instance.setMode(
      isDark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: _toggleTheme,
            tooltip: isDark ? 'Light mode' : 'Dark mode',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
          const SizedBox(width: AppTheme.space1),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: listUsers,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.space2),
          children: [
            const MangoYieldCard(),
            FarmersListCard(farmers: _farmers, loading: _loading),
          ],
        ),
      ),
    );
  }
}
