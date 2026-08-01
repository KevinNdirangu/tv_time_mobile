import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dashboard_screen.dart';
import 'library_screen.dart';
import 'calendar_screen.dart';
import 'discover_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/navigation_provider.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  final List<Widget> _screens = const [
    DashboardScreen(),
    DiscoverScreen(),
    CalendarScreen(),
    LibraryScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      body: _screens[currentIndex],
      bottomNavigationBar: currentIndex < 4 ? BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_rounded),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library_rounded),
            label: 'Library',
          ),
        ],
      ) : null,
    );
  }
}
