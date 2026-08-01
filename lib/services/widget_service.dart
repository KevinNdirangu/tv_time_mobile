import 'package:home_widget/home_widget.dart';
import '../models/library_show.dart';

class WidgetService {
  static const String _appGroupId = 'com.example.tv_time_mobile'; // iOS App Group if needed later
  static const String _androidWidgetName = 'UpNextWidgetProvider';

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
        // We could also save an image path here in the future.
      } else {
        await HomeWidget.saveWidgetData<String>('widget_show_title', 'All caught up!');
        await HomeWidget.saveWidgetData<String>('widget_episode_title', 'Find a new show');
      }

      await HomeWidget.updateWidget(name: _androidWidgetName);
    } catch (e) {
      // Ignore errors if widget isn't supported or fails to update
      print('Widget update failed: $e');
    }
  }
}
