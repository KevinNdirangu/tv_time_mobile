import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'reminder', 'airing', 'news'
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
  });
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  NotificationsNotifier(this.ref) : super([]) {
    _loadNotifications();
  }

  final Ref ref;
  List<String> _dismissedIds = [];

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedIds = prefs.getStringList('dismissed_notifications') ?? [];

    _generateNotifications();
  }

  void _generateNotifications() {
    final libraryAsync = ref.read(libraryProvider);
    final calendarAsync = ref.read(calendarProvider);
    
    final List<AppNotification> newNotifs = [];
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);

    libraryAsync.whenData((library) {
      for (var item in library) {
        // 1. Reminders for Movies (Watchlist)
        if (item.show.type == 'movie' && item.watchedEpisodes == 0) {
          final id = 'reminder_movie_${item.show.id}';
          if (!_dismissedIds.contains(id)) {
            newNotifs.add(AppNotification(
              id: id,
              title: 'Movie Reminder',
              body: '${item.show.title} is on your watchlist. Time for a movie night?',
              type: 'reminder',
              timestamp: now,
            ));
          }
        }
        
        // 2. Reminders for TV Shows (Unwatched aired episodes)
        if (item.show.type == 'tv' && item.airedEpisodes > item.watchedEpisodes && item.show.isStopped == 0) {
          final id = 'reminder_tv_${item.show.id}_${item.airedEpisodes}';
          if (!_dismissedIds.contains(id)) {
            newNotifs.add(AppNotification(
              id: id,
              title: 'New Episodes Awaiting',
              body: 'You have unwatched episodes for ${item.show.title}.',
              type: 'reminder',
              timestamp: now,
            ));
          }
        }

        // 3. Status Updates / News
        if (item.show.type == 'tv' && (item.show.status == 'Ended' || item.show.status == 'Canceled')) {
          final id = 'news_status_${item.show.id}_${item.show.status}';
          if (!_dismissedIds.contains(id)) {
            newNotifs.add(AppNotification(
              id: id,
              title: 'Status Update',
              body: '${item.show.title} has officially been marked as ${item.show.status}.',
              type: 'news',
              timestamp: now,
            ));
          }
        }
      }
    });

    // 4. Airing Today / Tomorrow
    calendarAsync.whenData((calendar) {
      for (var ep in calendar) {
        if (ep.airDate == todayStr || ep.airDate == tomorrowStr) {
          final id = 'airing_${ep.showId}_${ep.seasonNumber}_${ep.episodeNumber}';
          if (!_dismissedIds.contains(id)) {
            final day = ep.airDate == todayStr ? 'Today' : 'Tomorrow';
            newNotifs.add(AppNotification(
              id: id,
              title: 'Airing $day',
              body: '${ep.showTitle} S${ep.seasonNumber}E${ep.episodeNumber} airs $day!',
              type: 'airing',
              timestamp: now,
            ));
          }
        }
      }
    });

    state = newNotifs;
  }

  Future<void> dismiss(String id) async {
    _dismissedIds.add(id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_notifications', _dismissedIds);
    state = state.where((n) => n.id != id).toList();
  }

  Future<void> clearAll() async {
    for (var n in state) {
      _dismissedIds.add(n.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dismissed_notifications', _dismissedIds);
    state = [];
  }
  
  void refresh() {
    _generateNotifications();
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  // Listen to library and calendar changes to trigger re-generation
  ref.watch(libraryProvider);
  ref.watch(calendarProvider);
  
  return NotificationsNotifier(ref);
});
