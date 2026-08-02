import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';

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
  List<String> _pushedIds = [];
  bool _isFirstRunForPush = false;

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    _dismissedIds = prefs.getStringList('dismissed_notifications') ?? [];
    
    _pushedIds = prefs.getStringList('pushed_notifications') ?? [];
    if (!prefs.containsKey('pushed_notifications')) {
      _isFirstRunForPush = true;
    }

    await _generateNotifications();
  }

  Future<void> _generateNotifications() async {
    final libraryAsync = ref.read(libraryProvider);
    final calendarAsync = ref.read(calendarProvider);
    
    final List<AppNotification> newNotifs = [];
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowStr = DateFormat('yyyy-MM-dd').format(tomorrow);
    
    bool pushListChanged = false;

    void processNotification(String id, String title, String body, String type, [String? payload]) {
      if (!_dismissedIds.contains(id)) {
        newNotifs.add(AppNotification(
          id: id,
          title: title,
          body: body,
          type: type,
          timestamp: now,
        ));
        
        if (!_pushedIds.contains(id)) {
          _pushedIds.add(id);
          pushListChanged = true;
          
          if (!_isFirstRunForPush) {
            // Push OS Notification
            NotificationService.showNotification(
              id: id.hashCode,
              title: title,
              body: body,
              payload: payload,
            );
          }
        }
      }
    }

    libraryAsync.whenData((library) {
      for (var item in library) {
        // 1. Reminders for Movies (Watchlist)
        if (item.show.type == 'movie' && item.watchedEpisodes == 0) {
          processNotification(
            'reminder_movie_${item.show.id}',
            'Movie Reminder',
            '${item.show.title} is on your watchlist. Time for a movie night?',
            'reminder',
            'tvtime://show/${item.show.apiId}/${item.show.type}',
          );
        }
        
        // 2. Reminders for TV Shows (Unwatched aired episodes)
        if (item.show.type == 'tv' && item.airedEpisodes > item.watchedEpisodes && item.show.isStopped == 0) {
          processNotification(
            'reminder_tv_${item.show.id}_${item.airedEpisodes}',
            'New Episodes Awaiting',
            'You have unwatched episodes for ${item.show.title}.',
            'reminder',
            'tvtime://show/${item.show.apiId}/${item.show.type}',
          );
        }

        // 3. Status Updates / News
        if (item.show.type == 'tv' && (item.show.status == 'Ended' || item.show.status == 'Canceled')) {
          processNotification(
            'news_status_${item.show.id}_${item.show.status}',
            'Status Update',
            '${item.show.title} has officially been marked as ${item.show.status}.',
            'news',
            'tvtime://show/${item.show.apiId}/${item.show.type}',
          );
        }
      }
    });

    // 4. Airing Today / Tomorrow
    calendarAsync.whenData((calendar) {
      for (var ep in calendar) {
        if (ep.airDate == todayStr || ep.airDate == tomorrowStr) {
          final day = ep.airDate == todayStr ? 'Today' : 'Tomorrow';
          processNotification(
            'airing_${ep.showId}_${ep.seasonNumber}_${ep.episodeNumber}',
            'Airing $day',
            '${ep.showTitle} S${ep.seasonNumber}E${ep.episodeNumber} airs $day!',
            'airing',
            'tvtime://show/${ep.tmdbId}/${ep.type}',
          );
        }
      }
    });

    state = newNotifs;
    
    if (pushListChanged) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pushed_notifications', _pushedIds);
    }
    
    if (_isFirstRunForPush) {
      _isFirstRunForPush = false;
    }
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
