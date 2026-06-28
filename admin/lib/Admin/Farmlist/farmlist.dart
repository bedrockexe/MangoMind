import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sweet_insights_admin/Admin/Farmlist/Userfarmlist/userfarms.dart';

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
      print(result.data);
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

      setState(() {
        _users = usersWithFarms;
        _farmCountByUid = farmCount;
        _loading = false;
      });
    } catch (e, st) {
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
      final uid = (u['uid'] ?? '').toString().toLowerCase();
      return email.contains(q) || uid.contains(q);
    }).toList();
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  Widget _buildFarmerItem({
    required firstName,
    required lastName,
    required email,
    required farms,
    required userId,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: InkWell(
          onTap: () {
            // Navigate to user's farms page
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FarmListPage(userId: userId)),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green,
                child: Text(
                  firstName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$firstName $lastName',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.agriculture,
                          size: 16,
                          color: Colors.green.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$farms Farm(s)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ],
                ),
              ),
              // Edit Placeholder
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Navigate to user's farms page
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FarmListPage(userId: userId),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmlist', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: _loading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
        backgroundColor: Colors.green,
        elevation: 4,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar with modern styling
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  hintText: 'Search by email or uid',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      30,
                    ), // Rounded for modernity
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100], // Soft background
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onChanged: (s) {
                  setState(() => _search = s);
                  // Filter logic here (e.g., update _filteredUsers)
                },
              ),
            ),

            // Body with AnimatedSwitcher for smooth transitions
            Expanded(
              child: AnimatedSwitcher(
                duration: Duration(
                  milliseconds: 300,
                ), // Fade transition duration
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          'No users with farms found.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final u = _filteredUsers[index];
                            final uid = u['uid']?.toString() ?? '';
                            print(uid);
                            final email =
                                u['email']?.toString() ?? '(no email)';
                            final count = _farmCountByUid[uid] ?? 0;
                            return _buildFarmerItem(
                              firstName: u['firstname'] ?? 'N/A',
                              lastName: u['lastname'] ?? '',
                              email: email,
                              farms: count,
                              userId: uid,
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
