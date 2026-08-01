import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/navigation_provider.dart';

class GlobalNavigationDrawer extends ConsumerWidget {
  const GlobalNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);

    Widget buildItem(IconData icon, String title, int index) {
      final isSelected = currentIndex == index;
      return ListTile(
        leading: Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted),
        title: Text(title, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textMain, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedTileColor: AppTheme.primary.withValues(alpha: 0.1),
        onTap: () {
          ref.read(currentTabProvider.notifier).state = index;
          Navigator.pop(context);
        },
      );
    }

    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24.0),
              alignment: Alignment.centerLeft,
              child: Text('TV Time', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            ),
            const Divider(color: AppTheme.surfaceLight, height: 1),
            buildItem(Icons.dashboard_rounded, 'Dashboard', 0),
            buildItem(Icons.explore_rounded, 'Discover', 1),
            buildItem(Icons.video_library_rounded, 'Library', 2),
            const Divider(color: AppTheme.surfaceLight, height: 1),
            buildItem(Icons.bar_chart_rounded, 'Statistics', 3),
            buildItem(Icons.settings_rounded, 'Settings', 4),
            const Divider(color: AppTheme.surfaceLight, height: 1),
            ListTile(
              leading: const Icon(Icons.notifications_rounded, color: AppTheme.textMuted),
              title: const Text('Notifications', style: TextStyle(color: AppTheme.textMain)),
              onTap: () {
                Navigator.pop(context); // Close left drawer
                Scaffold.of(context).openEndDrawer(); // Open right drawer
              },
            ),
          ],
        ),
      ),
    );
  }
}
