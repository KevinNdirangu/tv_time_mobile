import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    Widget buildSectionTitle(String title) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
        ),
      );
    }

    Widget buildCard({required Widget child}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: child,
      );
    }

    Widget buildButton(String text, Color color, VoidCallback onTap) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: color == AppTheme.primary || color == Colors.white ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onTap,
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Builder(
            builder: (context) => Badge(
              isLabelVisible: notifications.isNotEmpty,
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings & Integrations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            
            // Appearance
            buildSectionTitle('Appearance'),
            buildCard(
              child: Row(
                children: [
                  const Text('Accent Color:', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  _ColorDot(color: const Color(0xFFFFD600), isSelected: true, onTap: () {}),
                  _ColorDot(color: const Color(0xFFff3b30), isSelected: false, onTap: () {}),
                  _ColorDot(color: const Color(0xFF34c759), isSelected: false, onTap: () {}),
                  _ColorDot(color: const Color(0xFF0a84ff), isSelected: false, onTap: () {}),
                  _ColorDot(color: const Color(0xFFaf52de), isSelected: false, onTap: () {}),
                ],
              ),
            ),

            // Timezone
            buildSectionTitle('Global Timezone Shift'),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Automatically adds +1 day to air dates of shows originating in the Americas to match local timezones.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: true,
                        onChanged: (val) {},
                        activeColor: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Enable Auto-Timezone Shift', style: TextStyle(color: AppTheme.textMain)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildButton('Run Timezone Fix on Existing Library', const Color(0xFF333333), () {}),
                ],
              ),
            ),

            // Notifications
            buildSectionTitle('Notifications'),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Get native push notifications on your phone when an episode from your Watchlist airs today.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  buildButton('Enable Push Notifications', const Color(0xFF333333), () {}),
                ],
              ),
            ),

            // Data Management
            buildSectionTitle('Data Management'),
            Row(
              children: [
                Expanded(
                  child: buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Import CSV History', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Supports TV Time exports and Letterboxd logs.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        buildButton('Upload .CSV File', const Color(0xFF333333), () {}),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Export Database', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Download a backup of your library and history.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: buildButton('JSON', const Color(0xFF0a84ff), () {})),
                            const SizedBox(width: 8),
                            Expanded(child: buildButton('CSV', const Color(0xFF34c759), () {})),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.cloud_sync_rounded, color: AppTheme.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Cloud Calendar Subscription', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copy this URL into Google Calendar or Apple Calendar using the "Add from URL" option.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Text('https://tvtime.local/api/calendar', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: buildButton('Copy URL', const Color(0xFF333333), () {})),
                      const SizedBox(width: 8),
                      Expanded(child: buildButton('Subscribe', const Color(0xFF34c759), () {})),
                      const SizedBox(width: 8),
                      Expanded(child: buildButton('Download', const Color(0xFF0a84ff), () {})),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
        ),
      ),
    );
  }
}
