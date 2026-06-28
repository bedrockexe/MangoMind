// packages
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
// pages
import 'package:insights/pages/homepage/HomeNavigator.dart';
import 'package:insights/pages/homepage/Settings/settings.dart';
import 'package:insights/pages/homepage/Farm/farm_management.dart';
import 'package:insights/pages/homepage/Records/records.dart';
import 'package:insights/pages/homepage/Home/irrigation_check.dart';

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
    _initIrrigation();
    _getData();
  }

  Future<void> _initIrrigation() async {
    await IrrigationCheck.runOnceAndNotifyForLocation(
      13.936169851018244,
      120.95014935479112,
    );
    await IrrigationCheck.scheduleDailyForLocation(
      13.936169851018244,
      120.95014935479112,
    );
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
            onPressed: () => SystemNavigator.pop(),
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
              Icon(Icons.eco, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                "MangoMind",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(navigatorKey: _navkeys[0], root: const Home()),
            _TabNavigator(navigatorKey: _navkeys[1], root: const FarmList()),
            _TabNavigator(navigatorKey: _navkeys[2], root: const ReportsPage()),
            _TabNavigator(
              navigatorKey: _navkeys[3],
              root: const SettingsPage(),
            ),
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
