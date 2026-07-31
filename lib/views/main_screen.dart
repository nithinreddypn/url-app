import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/deep_link_service.dart';
import '../pages/app/scan/scan_page.dart';
import 'home_screen.dart';
import 'alerts_screen.dart';
import 'settings_screen.dart';
import 'widgets/custom_bottom_nav_bar.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int currentIndex = 0;
  String? _pendingUrlForScan;

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(tabIndexProvider);
    final deepLinkUrl = ref.watch(deepLinkUrlProvider);

    if (tabIndex != currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          currentIndex = tabIndex;
        });
      });
    }

    if (deepLinkUrl != null) {
      _pendingUrlForScan = deepLinkUrl;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(deepLinkUrlProvider.notifier).state = null;
        // Auto-switch to Scan tab when a deep link URL arrives
        if (currentIndex != 1) {
          setState(() => currentIndex = 1);
          ref.read(tabIndexProvider.notifier).state = 1;
        }
      });
    }

    return Scaffold(
      extendBody: true, // Content flows behind the floating nav bar
      body: _buildCurrentScreen(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
            // Clear pending URL when user manually changes tabs
            _pendingUrlForScan = null;
          });
          ref.read(tabIndexProvider.notifier).state = index;
        },
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (currentIndex) {
      case 0:
        return HomeScreen(
          onNavigateToScan: () {
            setState(() {
              currentIndex = 1;
              _pendingUrlForScan = null;
            });
            ref.read(tabIndexProvider.notifier).state = 1;
          },
          onNavigateToAlerts: () {
            setState(() {
              currentIndex = 2;
              _pendingUrlForScan = null;
            });
            ref.read(tabIndexProvider.notifier).state = 2;
          },
          onNavigateToSettings: () {
            setState(() {
              currentIndex = 3;
              _pendingUrlForScan = null;
            });
            ref.read(tabIndexProvider.notifier).state = 3;
          },
        );
      case 1:
        final url = _pendingUrlForScan;
        _pendingUrlForScan = null;
        return ScanPage(initialUrl: url);
      case 2:
        return const AlertsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
