import 'package:flutter/material.dart';
import 'package:sweet_insights_admin/Admin/Homepage/detailed.dart';
import 'package:sweet_insights_admin/service/listuser.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';
import 'addaccount.dart';

class FarmersListPage extends StatefulWidget {
  const FarmersListPage({super.key});

  @override
  State<FarmersListPage> createState() => _FarmersListPageState();
}

class _FarmersListPageState extends State<FarmersListPage> {
  final ListUserService listService = ListUserService();
  List<Map<String, dynamic>> _filteredFarmers = [];
  List<Map<String, dynamic>> _fullFarmers = [];
  final TextEditingController _searchController = TextEditingController();
  String? _error;
  bool isLoading = false;

  Future<void> listUsers() async {
    setState(() {
      isLoading = true;
      _error = null;
    });
    try {
      final users = await listService.listUsers();
      if (!mounted) return;
      setState(() {
        _fullFarmers = users;
        isLoading = false;
      });
      _filterFarmers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        isLoading = false;
      });
    }
  }

  /// Deterministic accent for an avatar, derived from the name so it stays
  /// stable across rebuilds and refreshes.
  Color _avatarColor(String seed) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      const Color(0xFF18A0C1),
      const Color(0xFF8E6DF5),
    ];
    return palette[seed.hashCode.abs() % palette.length];
  }

  @override
  void initState() {
    super.initState();
    listUsers();
    _searchController.addListener(_filterFarmers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFarmers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFarmers = _fullFarmers;
      } else {
        _filteredFarmers = _fullFarmers.where((farmer) {
          final first = (farmer['first_name'] ?? '').toString().toLowerCase();
          final last = (farmer['last_name'] ?? '').toString().toLowerCase();
          final email = (farmer['email_address'] ?? '')
              .toString()
              .toLowerCase();
          return first.contains(query) ||
              last.contains(query) ||
              email.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openDetails(Map<String, dynamic> farmer) async {
    await Navigator.push(context, appRoute(UserDetailsPage(farmer: farmer)));
    await listUsers();
  }

  Widget _buildFarmerItem(Map<String, dynamic> farmer) {
    final first = (farmer['first_name'] ?? '').toString();
    final last = (farmer['last_name'] ?? '').toString();
    final email = (farmer['email_address'] ?? '').toString();
    final initial = first.trim().isNotEmpty ? first[0].toUpperCase() : '?';
    final color = _avatarColor('$first$email');

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(
          initial,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        '$first $last'.trim().isEmpty ? 'Unnamed user' : '$first $last',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: email.isEmpty ? null : Text(email),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openDetails(farmer),
    );
  }

  Widget _buildBody() {
    if (isLoading) return const ListSkeleton();
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Could not load users',
        message: _error,
        action: FilledButton.icon(
          onPressed: listUsers,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
    }
    if (_filteredFarmers.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'No users found',
        message: 'Registered farmer accounts will appear here.',
      );
    }
    return ListView.separated(
      itemCount: _filteredFarmers.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) => _buildFarmerItem(_filteredFarmers[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer accounts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or email',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: listUsers,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, appRoute(const AddAccount()));
          await listUsers();
        },
        label: const Text('Add user'),
        icon: const Icon(Icons.person_add_alt_1),
        tooltip: 'Add a new user',
      ),
    );
  }
}
