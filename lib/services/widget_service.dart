import 'package:home_widget/home_widget.dart';
import '../models/library_show.dart';
import 'supabase_service.dart';

class WidgetService {
  static const String _appGroupId = 'com.example.tv_time_mobile'; // iOS App Group if needed later
  static const String _upNextWidgetName = 'UpNextWidgetProvider';
  static const String _calendarWidgetName = 'CalendarWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<void> updateUpNextWidget(List<LibraryShow> libraryData) async {
    try {
      // Find the most recent 'Up Next' show
      final watching = libraryData
          .where((s) => s.show.type == 'tv' && s.watchedEpisodes > 0 && s.watchedEpisodes < s.show.totalEpisodes && s.show.isStopped == 0)
          .toList();
      watching.sort((a, b) => b.show.id.compareTo(a.show.id));

      if (watching.isNotEmpty) {
        final nextShow = watching.first;
        final nextEpisodeNum = nextShow.watchedEpisodes + 1;
        
        await HomeWidget.saveWidgetData<String>('widget_show_title', nextShow.show.title);
        await HomeWidget.saveWidgetData<String>('widget_episode_title', 'Next: Episode $nextEpisodeNum');
      } else {
        await HomeWidget.saveWidgetData<String>('widget_show_title', 'All caught up!');
        await HomeWidget.saveWidgetData<String>('widget_episode_title', 'Find a new show');
      }

      await HomeWidget.updateWidget(name: _upNextWidgetName);
    } catch (e) {
      // Ignore errors if widget isn't supported or fails to update
    }
  }

  static Future<void> updateCalendarWidget(List<CalendarEpisode> calendarData) async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      // Filter for upcoming in the next 30 days
      final upcoming = calendarData.where((e) => e.airDate.compareTo(todayStr) >= 0).toList();
      
      // Ensure they are sorted by air date
      upcoming.sort((a, b) => a.airDate.compareTo(b.airDate));

      for (int i = 1; i <= 3; i++) {
        final key = 'widget_cal_item_$i';
        if (i - 1 < upcoming.length) {
          final ep = upcoming[i - 1];
          final text = "${ep.showTitle}\nS${ep.seasonNumber.toString().padLeft(2, '0')}E${ep.episodeNumber.toString().padLeft(2, '0')} - Airs: ${ep.airDate}";
          await HomeWidget.saveWidgetData<String>(key, text);
        } else {
          // Clear if less than 3
          await HomeWidget.saveWidgetData<String>(key, "");
        }
      }

      await HomeWidget.updateWidget(name: _calendarWidgetName);
    } catch (e) {
      // Ignore errors
    }
  }
}
