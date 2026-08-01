import 'dart:convert';
import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../models/library_show.dart';
import 'supabase_service.dart';

class WidgetService {
  static const String _appGroupId = 'com.example.tv_time_mobile'; // iOS App Group if needed later
  static const String _upNextWidgetName = 'UpNextWidgetProvider';
  static const String _calendarWidgetName = 'CalendarWidgetProvider';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  static Future<String?> _downloadAndCacheImage(String? url, String showId) async {
    if (url == null || url.isEmpty) return null;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final File file = File('${directory.path}/widget_poster_$showId.jpg');
      
      // If we already have it, just return the path to save time/bandwidth
      if (await file.exists()) {
        return file.path;
      }
      
      final fullUrl = "https://image.tmdb.org/t/p/w200$url";
      final response = await http.get(Uri.parse(fullUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      print("Failed to cache image: $e");
    }
    return null;
  }

  static Future<void> updateUpNextWidget(List<LibraryShow> libraryData) async {
    try {
      final watching = libraryData
          .where((s) => s.show.type == 'tv' && s.watchedEpisodes > 0 && s.watchedEpisodes < s.show.totalEpisodes && s.show.isStopped == 0)
          .toList();
      watching.sort((a, b) => b.show.id.compareTo(a.show.id));

      final List<Map<String, String>> upNextList = [];
      
      // Get up to 10 shows for the list
      for (var s in watching.take(10)) {
        final localPath = await _downloadAndCacheImage(s.show.posterUrl, s.show.id.toString());
        final unwatched = s.show.totalEpisodes - s.watchedEpisodes;
        upNextList.add({
          "title": s.show.title,
          "subtitle": "Next: Ep ${s.watchedEpisodes + 1}",
          "image_path": localPath ?? "",
          "id": s.show.id.toString(),
          "tmdb_id": s.show.apiId.toString(),
          "type": s.show.type,
          "unwatched_count": unwatched > 0 ? "+$unwatched" : ""
        });
      }
      
      if (upNextList.isEmpty) {
         upNextList.add({
          "title": "All caught up!",
          "subtitle": "Find a new show",
          "image_path": "",
          "id": ""
        });
      }

      await HomeWidget.saveWidgetData<String>('up_next_list_data', jsonEncode(upNextList));
      await HomeWidget.updateWidget(name: _upNextWidgetName);
    } catch (e) {
      print('Widget update failed: $e');
    }
  }

  static Future<void> updateCalendarWidget(List<CalendarEpisode> calendarData) async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      final upcoming = calendarData.where((e) => e.airDate.compareTo(todayStr) >= 0).toList();
      upcoming.sort((a, b) => a.airDate.compareTo(b.airDate));

      final List<Map<String, String>> calendarList = [];
      
      // Get up to 15 episodes for the list
      for (var ep in upcoming.take(15)) {
        final localPath = await _downloadAndCacheImage(ep.posterUrl, ep.showId.toString());
        
        // Format date "YYYY-MM-DD" to "MON DD"
        String formattedDate = ep.airDate;
        try {
           final parsed = DateTime.parse(ep.airDate);
           final diff = parsed.difference(DateTime(now.year, now.month, now.day)).inDays;
           if (diff == 0) {
              formattedDate = "TODAY";
           } else if (diff == 1) {
              formattedDate = "TOMORROW";
           } else {
              final months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
              formattedDate = "${months[parsed.month - 1]} ${parsed.day}";
           }
        } catch (_) {}

        calendarList.add({
          "title": ep.showTitle,
          "subtitle": "S${ep.seasonNumber.toString().padLeft(2, '0')} | E${ep.episodeNumber.toString().padLeft(2, '0')}",
          "image_path": localPath ?? "",
          "id": ep.showId.toString(),
          "tmdb_id": ep.tmdbId.toString(),
          "type": ep.type,
          "air_date": formattedDate,
          "air_time": "TBA"
        });
      }
      
      if (calendarList.isEmpty) {
         calendarList.add({
          "title": "No upcoming shows",
          "subtitle": "",
          "image_path": "",
          "id": ""
        });
      }

      await HomeWidget.saveWidgetData<String>('calendar_list_data', jsonEncode(calendarList));
      await HomeWidget.updateWidget(name: _calendarWidgetName);
    } catch (e) {
      print('Widget update failed: $e');
    }
  }
}
