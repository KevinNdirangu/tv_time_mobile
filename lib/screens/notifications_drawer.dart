import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsDrawer extends StatefulWidget {
  const NotificationsDrawer({super.key});

  @override
  State<NotificationsDrawer> createState() => _NotificationsDrawerState();
}

class _NotificationsDrawerState extends State<NotificationsDrawer> {
  // Dummy notifications for now
  List<Map<String, String>> notifications = [
    {
      'title': 'Welcome to TV Time!',
      'body': 'Track your favorite shows and movies.',
      'time': 'Just now',
    },
    {
      'title': 'New Episode Aired',
      'body': 'The Boys S04E01 is now available.',
      'time': '2 hours ago',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMain,
                    ),
                  ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          notifications.clear();
                        });
                      },
                      child: const Text('Clear All', style: TextStyle(color: AppTheme.primary)),
                    ),
                ],
              ),
            ),
            const Divider(color: AppTheme.surfaceLight, height: 1),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'No new notifications',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.surfaceLight,
                            child: Icon(Icons.notifications, color: AppTheme.primary),
                          ),
                          title: Text(notif['title']!, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(notif['body']!, style: const TextStyle(color: AppTheme.textMuted)),
                              const SizedBox(height: 4),
                              Text(notif['time']!, style: const TextStyle(color: AppTheme.primary, fontSize: 10)),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
