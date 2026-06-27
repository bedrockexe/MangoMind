import 'package:flutter/material.dart';
import 'package:sweet_insights_admin/Admin/Homepage/fullAccountList.dart';
import 'package:sweet_insights_admin/Admin/Homepage/detailed.dart';
import 'dart:math';

class FarmersListCard extends StatefulWidget {
  final List<Map<String, dynamic>> farmers;
  const FarmersListCard({super.key, required this.farmers});

  @override
  State<FarmersListCard> createState() => _FarmersListCardState();
}

class _FarmersListCardState extends State<FarmersListCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Map<String, dynamic>> get _farmers => widget.farmers;

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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shadowColor: Colors.green.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.people, color: Colors.green.shade600, size: 28),
                const SizedBox(width: 8),
                const Text(
                  'User Accounts',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage user profiles below. Tap edit for actions.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            SizedBox(
              height: 320,
              child: _farmers.isNotEmpty
                  ? AnimatedBuilder(
                      animation: _fadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fadeAnimation.value,
                          child: ListView.separated(
                            physics: const ClampingScrollPhysics(),
                            itemCount: _farmers.length < 5
                                ? _farmers.length
                                : 5,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: Colors.grey,
                              thickness: 0.5,
                            ),
                            itemBuilder: (context, index) {
                              final farmer = _farmers[index];
                              return _buildFarmerItem(farmer, index);
                            },
                          ),
                        );
                      },
                    )
                  : Center(child: Text("No Users Found")),
            ),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FarmersListPage()),
                  );
                },
                child: const Text(
                  'See All',
                  style: TextStyle(color: Colors.green),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFarmerItem(Map<String, dynamic> farmer, int index) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: generateRandomColor(),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailsPage(farmer: farmer),
            ),
          );
        },
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserDetailsPage(farmer: farmer),
          ),
        );
      },
    );
  }
}
