import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/notifications_provider.dart';
import 'package:intl/intl.dart';

class NotificationsDrawer extends ConsumerWidget {
  const NotificationsDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

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
                        ref.read(notificationsProvider.notifier).clearAll();
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
                        return Dismissible(
                          key: Key(notif.id),
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            ref.read(notificationsProvider.notifier).dismiss(notif.id);
                          },
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.surfaceLight,
                              child: Icon(
                                notif.type == 'airing' ? Icons.calendar_today
                                  : notif.type == 'news' ? Icons.campaign
                                  : Icons.notifications,
                                color: AppTheme.primary,
                                size: 18,
                              ),
                            ),
                            title: Text(notif.title, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(notif.body, style: const TextStyle(color: AppTheme.textMuted)),
                                const SizedBox(height: 4),
                                Text(DateFormat('MMM d, h:mm a').format(notif.timestamp), style: const TextStyle(color: AppTheme.primary, fontSize: 10)),
                              ],
                            ),
                            isThreeLine: true,
                          ),
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
