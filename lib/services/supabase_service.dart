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
