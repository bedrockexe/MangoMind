import 'package:flutter/material.dart';
import 'package:sweet_insights_admin/Admin_mainpage/Dashboard.dart';
import 'package:sweet_insights_admin/Admin/Homepage/assess.dart';
import 'package:sweet_insights_admin/Admin/Farmlist/farmlist.dart';
import '../Admin/Trainings/trainings.dart';

/// App shell: hosts the four admin sections behind an M3 [NavigationBar].
///
/// The shell deliberately has **no** AppBar of its own — each section page owns
/// its own Scaffold + AppBar so it can carry page-specific actions (refresh,
/// PDF export, search). Global actions (theme toggle, logout) live on the
/// Dashboard's AppBar.
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    FarmsPage(),
    Assessment(),
    AdminTrainingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(
          key: ValueKey<int>(_currentIndex),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon: Icon(Icons.agriculture),
            label: 'Farms',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Assessments',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Trainings',
          ),
        ],
      ),
    );
  }
}
