// packages
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// pages
import 'package:insights/pages/homepage/settings.dart';
import 'package:insights/pages/homepage/Home/weather.dart';
import 'package:insights/pages/homepage/Home/widget.dart';
import 'package:insights/pages/homepage/Farm/farm.dart';
import 'package:insights/pages/homepage/Farm/test.dart';

// Main Class
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _Home();
}

// Sub Class
class _Home extends State<HomePage> {
  Map<String, dynamic>? userData;
  String? error;

  int _index = 0;

  // Individual navigators
  final List<GlobalKey<NavigatorState>> _navkeys = List.generate(
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

      // Get the user data
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

  Future<bool> _poppingHandler() async {
    final nav = _navkeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }

    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _poppingHandler();
          if (shouldPop) {
            Navigator.of(context).pop(result);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.green,
          title: Row(
            children: [
              Icon(Icons.eco, color: Colors.white), // leaf-like eco icon
              const SizedBox(width: 8), // space between icon and text
              Text(
                "Sweet Insights",
                style: const TextStyle(
                  color: Colors.white, // text color
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(navigatorKey: _navkeys[0], root: _HomeRoot()),
            _TabNavigator(
              navigatorKey: _navkeys[1],
              root: const FarmListPage(),
            ),
            _TabNavigator(navigatorKey: _navkeys[2], root: const ReportRoot()),
            _TabNavigator(navigatorKey: _navkeys[3], root: SettingsPage()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _index,
          onTap: (i) {
            if (i == _index) {
              _navkeys[i].currentState?.popUntil((r) => r.isFirst);
            } else {
              _navkeys[_index].currentState?.popUntil((r) => r.isFirst);
              setState(() => _index = i);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.agriculture),
              label: 'Farms',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.description),
              label: 'Reports',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

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
        return null;
      },
    );
  }
}

class _HomeRoot extends StatelessWidget {
  const _HomeRoot();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        WeatherPanel(),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: MangoDetectorTile(),
        ),
      ],
    );
  }
}

class ReportRoot extends StatelessWidget {
  const ReportRoot({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => Navigator.of(
          context,
        ).pushNamed('/details', arguments: 'Placeholder Data'),
        child: const Text('Placeholder Button'),
      ),
    );
  }
}
