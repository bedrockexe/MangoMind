import 'package:flutter/material.dart';
import 'dart:math';
import 'package:sweet_insights_admin/Admin/Homepage/detailed.dart';
import 'package:sweet_insights_admin/service/listuser.dart';
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
  List<Color> colorList = [];
  final TextEditingController _searchController = TextEditingController();
  // ignore: unused_field
  String? _error;
  bool isLoading = false;

  Future<void> listUsers() async {
    try {
      isLoading = true;
      final users = await listService.listUsers();
      setState(() {
        _filteredFarmers = users;
        _fullFarmers = users;
      });
      for (var i = 0; i < _filteredFarmers.length; i++) {
        colorList.add(generateRandomColor());
      }
      isLoading = false;
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Color generateRandomColor() {
    final Random _random = Random();
    return Color.fromARGB(
      255,
      _random.nextInt(256),
      _random.nextInt(256),
      _random.nextInt(256),
    );
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
    String query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredFarmers = _fullFarmers;
      } else {
        _filteredFarmers = _filteredFarmers.where((farmer) {
          return farmer['first_name'].toLowerCase().contains(query) ||
              farmer['last_name'].toLowerCase().contains(query) ||
              farmer['email_address'].toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Widget _buildFarmerItem(Map<String, dynamic> farmer, int index) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: colorList[index],
        child: Text(
          farmer['first_name'][0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        "${farmer['first_name']} ${farmer['last_name']}",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(farmer['email_address'])],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.chevron_right, color: Colors.green),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(farmer: farmer),
            ),
          );
          listUsers();
        },
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserDetailsPage(farmer: farmer),
          ),
        );
        listUsers();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Farmers Accounts',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade600,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name or email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.green),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: listUsers,
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text("Fetching users. Please wait..."),
                        ],
                      ),
                    )
                  : (_filteredFarmers.isEmpty
                        ? const Center(child: Text('No farmers found'))
                        : ListView.separated(
                            itemCount: _filteredFarmers.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Colors.grey,
                              thickness: 0.5,
                            ),
                            itemBuilder: (context, index) {
                              final farmer = _filteredFarmers[index];
                              return _buildFarmerItem(farmer, index);
                            },
                          )),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 40, right: 10),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddAccount()),
            );
            await listUsers();
          },
          label: const Text('Add User'),
          icon: const Icon(Icons.person_add_alt_1),
          backgroundColor: Colors.white,
          foregroundColor: Colors.green,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tooltip: 'Add a new user',
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
