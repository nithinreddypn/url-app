import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'scan_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';
import 'widgets/custom_bottom_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  String? _pendingUrlForScan;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Content flows behind the floating nav bar
      body: IndexedStack(
        index: currentIndex,
        children: [
          HomeScreen(
            onNavigateToScan: () {
              setState(() {
                currentIndex = 1;
                _pendingUrlForScan = null;
              });
            },
            onNavigateToAlerts: () {
              setState(() {
                currentIndex = 2;
                _pendingUrlForScan = null;
              });
            },
            onNavigateToSettings: () {
              setState(() {
                currentIndex = 3;
                _pendingUrlForScan = null;
              });
            },
          ),
          ScanScreen(initialUrl: _pendingUrlForScan),
          const AlertsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
            // Clear pending URL when user manually changes tabs
            _pendingUrlForScan = null;
          });
        },
      ),
    );
  }
}