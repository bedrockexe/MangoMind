import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage1 extends StatefulWidget {
  const HomePage1({super.key});

  @override
  State<HomePage1> createState() => _Home();
}

class _Home extends State<HomePage1> {
  Map<String, dynamic>? userData;
  String? error;

  int _index = 0;
  final _labels = const ['Home', 'Insights', 'Alerts', 'Profile'];

  // one Navigator per tab (independent back stacks)
  final List<GlobalKey<NavigatorState>> _navKeys = List.generate(
    4,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _getData();
  }

  Future<void> _getData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => error = 'No user logged in.');
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snap.exists) {
        setState(() => error = 'Profile not found for uid: ${user.uid}');
        return;
      }

      setState(() => userData = snap.data());
    } catch (e) {
      setState(() => error = 'Failed to load: $e');
    }
  }

  // Handle Android back button: pop inner stack if possible, else switch to Home tab, else exit.
  Future<bool> _onWillPop() async {
    final currentNav = _navKeys[_index].currentState!;
    if (await currentNav.maybePop()) return false;
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true; // allow app to close
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: Text(_labels[_index])),
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(
              navigatorKey: _navKeys[0],
              root: _HomeRoot(userData: userData, error: error),
            ),
            _TabNavigator(
              navigatorKey: _navKeys[1],
              root: const InsightsRoot(),
            ),
            _TabNavigator(navigatorKey: _navKeys[2], root: const AlertsRoot()),
            _TabNavigator(navigatorKey: _navKeys[3], root: const ProfileRoot()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart),
              label: 'Insights',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications),
              label: 'Alerts',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// A tiny wrapper that gives each tab its own Navigator.
class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;
  const _TabNavigator({required this.navigatorKey, required this.root});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => root);
        }
        if (settings.name == '/details') {
          final title = settings.arguments as String? ?? 'Details';
          return MaterialPageRoute(builder: (_) => DetailsPage(title: title));
        }
        return null;
      },
    );
  }
}

/* ---------- Root pages per tab ---------- */

class _HomeRoot extends StatelessWidget {
  final Map<String, dynamic>? userData;
  final String? error;
  const _HomeRoot({required this.userData, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error != null) return Center(child: Text(error!));
    if (userData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final firstName = userData!['first_name'] ?? '—';
    final address = userData!['address'] ?? '—';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'User Details',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text('Welcome: $firstName'),
        Text('You Live at: $address'),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamed('/details', arguments: 'Home Details');
          },
          child: const Text('Open Home Details (push)'),
        ),
      ],
    );
  }
}

class InsightsRoot extends StatelessWidget {
  const InsightsRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamed('/details', arguments: 'Insights Details'),
        child: const Text('Go to Insights Details'),
      ),
    );
  }
}

class AlertsRoot extends StatelessWidget {
  const AlertsRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamed('/details', arguments: 'Alert Info'),
        child: const Text('Open Alert Info'),
      ),
    );
  }
}

class ProfileRoot extends StatelessWidget {
  const ProfileRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamed('/details', arguments: 'Edit Profile'),
        child: const Text('Open Profile Details'),
      ),
    );
  }
}

/* ---------- Shared example details page ---------- */
class DetailsPage extends StatelessWidget {
  final String title;
  const DetailsPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Details go here')),
    );
  }
}
