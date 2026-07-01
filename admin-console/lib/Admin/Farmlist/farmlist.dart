import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sweet_insights_admin/Admin/Farmlist/Userfarmlist/userfarms.dart';
import 'package:sweet_insights_admin/theme/app_theme.dart';
import 'package:sweet_insights_admin/theme/components.dart';
import 'package:sweet_insights_admin/theme/transitions.dart';
import 'package:sweet_insights_admin/theme/skeletons.dart';

class FarmsPage extends StatefulWidget {
  const FarmsPage({super.key});

  @override
  State<FarmsPage> createState() => _FarmsPageState();
}

class _FarmsPageState extends State<FarmsPage> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _users = []; // each: {uid, email}
  Map<String, int> _farmCountByUid = {}; // uid -> number of farms
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) call the callable function to get users from Auth
      final HttpsCallable callable = _functions.httpsCallable('listUsers');
      final result = await callable.call();
      final dynamic raw = result.data;
      final List<dynamic> rawUsers = (raw is Map && raw['users'] is List)
          ? List.from(raw['users'])
          : (raw is List ? raw : []);
      final users = rawUsers.map<Map<String, dynamic>>((u) {
        final map = Map<String, dynamic>.from(u as Map);
        return {
          'uid': map['uid']?.toString() ?? '',
          'email': map['email_address']?.toString() ?? '',
          'firstname': map['first_name']?.toString() ?? '',
          'lastname': map['last_name']?.toString() ?? '',
        };
      }).toList();

      // 2) fetch all farms (one read) and build owner uid set and counts
      final farmsSnapshot = await _firestore.collection('farms').get();
      final Map<String, int> farmCount = {};
      for (final doc in farmsSnapshot.docs) {
        final data = doc.data();
        String? ownerUid = data['ownerUid']?.toString();
        if (ownerUid != null && ownerUid.isNotEmpty) {
          farmCount[ownerUid] = (farmCount[ownerUid] ?? 0) + 1;
        }
      }

      // 3) filter users to only those with farms
      final Set<String> ownersWithFarms = farmCount.keys.toSet();
      final usersWithFarms = users
          .where((u) => ownersWithFarms.contains(u['uid'] as String))
          .toList();

      if (!mounted) return;
      setState(() {
        _users = usersWithFarms;
        _farmCountByUid = farmCount;
        _loading = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load users or farms: $e';
        _loading = false;
      });
      debugPrint(st.toString());
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_search.trim().isEmpty) return _users;
    final q = _search.toLowerCase();
    return _users.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final name =
          '${u['firstname'] ?? ''} ${u['lastname'] ?? ''}'.toLowerCase();
      final uid = (u['uid'] ?? '').toString().toLowerCase();
      return email.contains(q) || name.contains(q) || uid.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: AppTheme.space1),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.space4,
              AppTheme.space4,
              AppTheme.space4,
              AppTheme.space2,
            ),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by name, email or UID',
              ),
              onChanged: (s) => setState(() => _search = s),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildBody(scheme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_loading) return const ListSkeleton();
    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: 'Something went wrong',
        message: _error,
        action: FilledButton.tonal(
          onPressed: _loadData,
          child: const Text('Retry'),
        ),
      );
    }
    final users = _filteredUsers;
    if (users.isEmpty) {
      return EmptyState(
        icon: Icons.agriculture_outlined,
        title: _search.isEmpty ? 'No farms yet' : 'No matches',
        message: _search.isEmpty
            ? 'Farmers who have registered a farm will appear here.'
            : 'Try a different name, email or UID.',
      );
    }
    return RefreshIndicator.adaptive(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space4,
          AppTheme.space2,
          AppTheme.space4,
          AppTheme.space4,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.space2),
        itemBuilder: (context, index) {
          final u = users[index];
          final uid = u['uid']?.toString() ?? '';
          return _FarmerCard(
            firstName: (u['firstname'] ?? '').toString(),
            lastName: (u['lastname'] ?? '').toString(),
            email: (u['email'] ?? '').toString(),
            farms: _farmCountByUid[uid] ?? 0,
            userId: uid,
          );
        },
      ),
    );
  }
}

class _FarmerCard extends StatelessWidget {
  const _FarmerCard({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.farms,
    required this.userId,
  });

  final String firstName;
  final String lastName;
  final String email;
  final int farms;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fullName = '$firstName $lastName'.trim();
    final initial = firstName.trim().isNotEmpty
        ? firstName.trim()[0].toUpperCase()
        : '?';

    return AppCard(
      onTap: () => Navigator.push(
        context,
        appRoute(FarmListPage(userId: userId)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Unnamed farmer' : fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppTheme.space2),
                AppStatusChip(
                  '$farms farm${farms == 1 ? '' : 's'}',
                  tone: StatusTone.success,
                  icon: Icons.agriculture,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
