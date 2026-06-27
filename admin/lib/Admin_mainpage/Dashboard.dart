import 'package:flutter/material.dart';
import 'package:sweet_insights_admin/Admin/Homepage/overview.dart';
import 'package:sweet_insights_admin/Admin/Homepage/farmersAccounts.dart';
import 'package:sweet_insights_admin/service/listuser.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ListUserService listService = ListUserService();
  List<Map<String, dynamic>> _farmers = [];
  Future<void> listUsers() async {
    try {
      final users = await listService.listUsers();
      setState(() {
        _farmers = users;
      });
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.all(16.0),
      child: RefreshIndicator(
        onRefresh: listUsers,
        child: ListView(
          children: [
            const MangoYieldCard(),
            FarmersListCard(farmers: _farmers),
          ],
        ),
      ),
    );
  }
}
