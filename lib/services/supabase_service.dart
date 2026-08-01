import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/show.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final showsProvider = FutureProvider<List<Show>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  
  // Wait for the query to complete
  final response = await client.from('shows').select('*').order('id', ascending: false);
  
  // Map the JSON objects to Show model
  return (response as List<dynamic>).map((e) => Show.fromJson(e)).toList();
});

class CalendarEpisode {
  final int showId;
  final String showTitle;
  final String? posterUrl;
  final int seasonNumber;
  final int episodeNumber;
  final String title;
  final String airDate;
  final int tmdbId;

  CalendarEpisode({
    required this.showId,
    required this.showTitle,
    this.posterUrl,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.airDate,
    required this.tmdbId,
  });
}

final calendarProvider = FutureProvider<List<CalendarEpisode>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final shows = await ref.watch(showsProvider.future);
  
  final now = DateTime.now();
  final fromDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  final response = await client.from('episodes')
      .select('show_id, season_number, episode_number, title, air_date')
      .gte('air_date', fromDate)
      .order('air_date', ascending: true)
      .limit(300);

  final List<CalendarEpisode> calendar = [];
  for (var ep in response as List<dynamic>) {
    final showId = ep['show_id'];
    try {
      final show = shows.firstWhere((s) => s.id == showId && s.isStopped == 0);
      calendar.add(CalendarEpisode(
        showId: showId,
        showTitle: show.title,
        posterUrl: show.posterUrl,
        seasonNumber: ep['season_number'],
        episodeNumber: ep['episode_number'],
        title: ep['title'] ?? 'TBA',
        airDate: ep['air_date'],
        tmdbId: show.apiId,
      ));
    } catch (e) {
      // Show not found or is stopped, ignore
    }
  }
  
  return calendar;
});

class SupabaseShowDetails {
  final Show show;
  final List<Map<String, dynamic>> episodes;
  final List<int> watchedEpisodeIds;

  SupabaseShowDetails({
    required this.show,
    required this.episodes,
    required this.watchedEpisodeIds,
  });
}

class SupabaseActions {
  static Future<SupabaseShowDetails?> getShowDetails(int tmdbId) async {
    final client = Supabase.instance.client;
    
    // Check if show exists
    final showRes = await client.from('shows').select('*').eq('api_id', tmdbId).maybeSingle();
    if (showRes == null) return null;
    
    final show = Show.fromJson(showRes);
    
    // Get episodes
    final epRes = await client.from('episodes').select('id, season_number, episode_number').eq('show_id', show.id);
    final episodes = List<Map<String, dynamic>>.from(epRes as List);
    
    // Get watch history
    final epIds = episodes.map((e) => e['id']).toList();
    if (epIds.isEmpty) {
      return SupabaseShowDetails(show: show, episodes: episodes, watchedEpisodeIds: []);
    }
    
    // Chunking might be needed for very large arrays, but in in operator 200-300 is fine
    final watchRes = await client.from('watch_history').select('episode_id').filter('episode_id', 'in', epIds);
    final watchedIds = (watchRes as List).map((e) => e['episode_id'] as int).toList();
    
    return SupabaseShowDetails(show: show, episodes: episodes, watchedEpisodeIds: watchedIds);
  }

  static Future<void> toggleWatched(int episodeId, bool isWatched) async {
    final client = Supabase.instance.client;
    if (isWatched) {
      // Find next ID
      final maxIdRes = await client.from('watch_history').select('id').order('id', ascending: false).limit(1).maybeSingle();
      int nextId = (maxIdRes != null ? maxIdRes['id'] as int : 0) + 1;
      await client.from('watch_history').insert({'id': nextId, 'episode_id': episodeId});
    } else {
      await client.from('watch_history').delete().eq('episode_id', episodeId);
    }
  }
}
