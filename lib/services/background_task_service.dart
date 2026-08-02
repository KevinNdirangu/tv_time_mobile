import 'package:workmanager/workmanager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    
    // Initialize required services in the background isolate
    await NotificationService.initialize();
    final prefs = await SharedPreferences.getInstance();
    
    await Supabase.initialize(
      url: 'https://gnwzertrmjerymlzzfuh.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdud3plcnRybWplcnltbHp6ZnVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUwODU5MTIsImV4cCI6MjEwMDY2MTkxMn0.4Y8p6Um7qH8OUS6pAVpQDPxJ9d_wguqVKjnDiWESEZs',
    );

    final client = Supabase.instance.client;

    try {
      // 1. Fetch active shows
      final showsRes = await client.from('shows').select('id, api_id, title, is_stopped, type, total_episodes').eq('is_stopped', 0);
      final activeShows = List<Map<String, dynamic>>.from(showsRes as List);
      
      if (activeShows.isEmpty) return Future.value(true);
      final activeShowIds = activeShows.map((s) => s['id']).toList();

      // 2. Fetch episodes airing today
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final epsRes = await client.from('episodes')
          .select('id, show_id, season_number, episode_number, title, air_date')
          .eq('air_date', todayStr);
          
      final epsToday = List<Map<String, dynamic>>.from(epsRes as List);
      
      final activeShowIdsSet = activeShowIds.toSet();
      final pushedIds = prefs.getStringList('pushed_notifications') ?? [];
      bool pushListChanged = false;
      
      for (var ep in epsToday) {
        final showId = ep['show_id'];
        if (activeShowIdsSet.contains(showId)) {
          final show = activeShows.firstWhere((s) => s['id'] == showId);
          final notifIdStr = 'airing_${showId}_${ep['season_number']}_${ep['episode_number']}';
          
          if (!pushedIds.contains(notifIdStr)) {
            final title = "${show['title']} is airing today!";
            final body = "Season ${ep['season_number']} Episode ${ep['episode_number']} - ${ep['title'] ?? 'TBA'}";
            final payload = "tvtime://show/${show['api_id']}/${show['type']}";
            
            await NotificationService.showNotification(
              id: notifIdStr.hashCode,
              title: title,
              body: body,
              payload: payload,
            );
            
            pushedIds.add(notifIdStr);
            pushListChanged = true;
          }
        }
      }
      
      if (pushListChanged) {
        await prefs.setStringList('pushed_notifications', pushedIds);
      }
    } catch (e) {
      print("Background task error: $e");
    }

    return Future.value(true);
  });
}

class BackgroundTaskService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to true to see notifications when task is scheduled
    );
  }

  static Future<void> registerDailyCheck() async {
    await Workmanager().registerPeriodicTask(
      "tv_time_daily_check",
      "check_episodes_task",
      frequency: const Duration(hours: 6),
      initialDelay: const Duration(minutes: 15), 
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
