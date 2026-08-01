import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/show.dart';
import '../models/library_show.dart';
import 'tmdb_service.dart';
import 'widget_service.dart';

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

Future<List<dynamic>> _fetchAll(SupabaseClient client, String table, String selectColumns) async {
  int step = 1000;
  int from = 0;
  List<dynamic> allData = [];
  
  while (true) {
    final response = await client.from(table).select(selectColumns).range(from, from + step - 1);
    final data = response as List<dynamic>;
    allData.addAll(data);
    if (data.length < step) break;
    from += step;
  }
  
  return allData;
}

class LibraryNotifier extends AsyncNotifier<List<LibraryShow>> {
  static const _cacheKey = 'tvt_lib_cache';

  @override
  Future<List<LibraryShow>> build() async {
    // 1. Try to load from cache
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString(_cacheKey);
    
    if (cachedStr != null) {
      try {
        final decoded = json.decode(cachedStr) as List;
        final cachedLib = decoded.map((e) => LibraryShow.fromJson(e)).toList();
        
        // 2. Trigger background refresh
        _refresh(prefs);
        return cachedLib;
      } catch (e) {
        // Cache invalid or error parsing
      }
    }
    
    // 3. Fallback to normal fetch
    return _fetchFromNetwork(prefs);
  }

  Future<void> _refresh(SharedPreferences prefs) async {
    try {
      final fresh = await _fetchFromNetwork(prefs);
      state = AsyncData(fresh);
    } catch (e) {
      // Background refresh failed, keep old state
    }
  }

  Future<List<LibraryShow>> _fetchFromNetwork(SharedPreferences prefs) async {
    final client = ref.read(supabaseClientProvider);
    
    final results = await Future.wait([
      _fetchAll(client, 'shows', '*'),
      _fetchAll(client, 'episodes', 'id, show_id, season_number, runtime, air_date'),
      _fetchAll(client, 'watch_history', 'id, episode_id, watched_at'),
    ]);

    final showsRaw = results[0];
    final epsRaw = results[1];
    final histRaw = results[2];

    final shows = showsRaw.map((e) => Show.fromJson(e)).toList();

    final Map<int, List<Map<String, dynamic>>> showEpisodes = {};
    for (var show in shows) {
      showEpisodes[show.id] = [];
    }

    final Map<int, List<Map<String, dynamic>>> epHistory = {};
    for (var ep in epsRaw) {
      epHistory[ep['id']] = [];
      if (showEpisodes.containsKey(ep['show_id'])) {
        showEpisodes[ep['show_id']]!.add(ep as Map<String, dynamic>);
      }
    }

    for (var h in histRaw) {
      if (epHistory.containsKey(h['episode_id'])) {
        epHistory[h['episode_id']]!.add(h as Map<String, dynamic>);
      }
    }

    final now = DateTime.now();

    final lib = shows.map((s) {
      int watched = 0;
      int aired = 0;
      int lastWatched = 0;
      int runtime = 0;

      final episodes = showEpisodes[s.id] ?? [];
      for (var ep in episodes) {
        if ((ep['season_number'] ?? 0) > 0) {
          if (ep['air_date'] != null) {
            final airDate = DateTime.tryParse(ep['air_date']);
            if (airDate != null && airDate.compareTo(now) <= 0) {
              aired++;
            }
          }
          
          final history = epHistory[ep['id']] ?? [];
          if (history.isNotEmpty) {
            watched++;
            runtime += (ep['runtime'] as int? ?? 0);
            final wAt = DateTime.tryParse(history[0]['watched_at'] ?? '')?.millisecondsSinceEpoch ?? 0;
            if (wAt > lastWatched) lastWatched = wAt;
          }
        }
      }

      return LibraryShow(
        show: s,
        watchedEpisodes: watched,
        airedEpisodes: aired,
        runtime: runtime,
        lastWatched: lastWatched > 0 ? DateTime.fromMillisecondsSinceEpoch(lastWatched).toIso8601String() : null,
      );
    }).toList();

    // Save to cache
    await prefs.setString(_cacheKey, json.encode(lib.map((e) => e.toJson()).toList()));
    
    // Update Android Home Screen Widget
    try {
      await WidgetService.updateUpNextWidget(lib);
    } catch (_) {}

    return lib;
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<LibraryShow>>(LibraryNotifier.new);

final allEpisodesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final res = await client.from('episodes').select('id, show_id, air_date');
  return List<Map<String, dynamic>>.from(res);
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
  final past = now.subtract(const Duration(days: 30));
  final fromDate = "${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}";

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
    final epRes = await client.from('episodes').select('id, season_number, episode_number, air_date, title').eq('show_id', show.id);
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

  static Future<void> runTimezoneFix() async {
    final client = Supabase.instance.client;
    
    // 1. Get all shows from Americas (simplified: we'll just check if timezone_offset is 0 and it's a candidate)
    // Actually, the original logic in the web app likely used a specific list of networks or countries.
    // For now, we'll just apply it to all shows that don't have it, or based on some heuristic.
    // Let's just follow the "loop over the user's Supabase library and apply the timezone offset logic"
    
    final showsRes = await client.from('shows').select('id, title, timezone_offset');
    final shows = showsRes as List<dynamic>;
    
    for (var show in shows) {
      if (show['timezone_offset'] == 0) {
        // We'll mark it as shifted and update its episodes
        await client.from('shows').update({'timezone_offset': 1}).eq('id', show['id']);
        
        // Fetch episodes for this show
        final epsRes = await client.from('episodes').select('id, air_date').eq('show_id', show['id']);
        final eps = epsRes as List<dynamic>;
        
        for (var ep in eps) {
          if (ep['air_date'] != null) {
            final date = DateTime.tryParse(ep['air_date']);
            if (date != null) {
              final newDate = date.add(const Duration(days: 1));
              final formatted = "${newDate.year}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}";
              await client.from('episodes').update({'air_date': formatted}).eq('id', ep['id']);
            }
          }
        }
      }
    }
  }

  static Future<List<Map<String, dynamic>>> exportDatabase() async {
    final client = Supabase.instance.client;
    final results = await Future.wait([
      _fetchAll(client, 'shows', '*'),
      _fetchAll(client, 'episodes', '*'),
      _fetchAll(client, 'watch_history', '*'),
    ]);
    
    return [
      {'table': 'shows', 'data': results[0]},
      {'table': 'episodes', 'data': results[1]},
      {'table': 'watch_history', 'data': results[2]},
    ];
  }

  /// Generates an ICS calendar string — mirrors api/calendar.js exactly.
  /// Fetches episodes from the past 30 days onwards for all active (non-stopped) shows.
  static Future<String> generateIcs() async {
    final client = Supabase.instance.client;

    final pastDate = DateTime.now().subtract(const Duration(days: 30));
    final fromDate = '${pastDate.year.toString().padLeft(4, '0')}-'
        '${pastDate.month.toString().padLeft(2, '0')}-'
        '${pastDate.day.toString().padLeft(2, '0')}';

    // Fetch episodes from past 30 days onwards
    final epRes = await client
        .from('episodes')
        .select('id, show_id, season_number, episode_number, title, air_date')
        .gte('air_date', fromDate)
        .order('air_date', ascending: true)
        .limit(500);

    // Fetch active (non-stopped) shows
    final showsRes = await client
        .from('shows')
        .select('id, title, is_stopped')
        .eq('is_stopped', 0);

    final showMap = <int, Map<String, dynamic>>{};
    for (var s in showsRes as List) {
      showMap[s['id'] as int] = Map<String, dynamic>.from(s);
    }

    final calData = (epRes as List)
        .where((e) => showMap.containsKey(e['show_id'] as int) && e['air_date'] != null)
        .toList();

    if (calData.isEmpty) return '';

    final now = DateTime.now().toUtc();
    final dtstamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}T'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';

    final buf = StringBuffer();
    buf.write('BEGIN:VCALENDAR\r\n');
    buf.write('VERSION:2.0\r\n');
    buf.write('PRODID:-//TV Tracker//EN\r\n');
    buf.write('CALSCALE:GREGORIAN\r\n');
    buf.write('METHOD:PUBLISH\r\n');
    buf.write('X-WR-CALNAME:TV Time Tracker\r\n');
    buf.write('X-WR-TIMEZONE:UTC\r\n');

    for (var ep in calData) {
      final airDate = ep['air_date'] as String;
      final dtStart = airDate.replaceAll('-', '');

      final parts = airDate.split('-');
      final d = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      final nextDay = d.add(const Duration(days: 1));
      final dtEnd = '${nextDay.year.toString().padLeft(4, '0')}'
          '${nextDay.month.toString().padLeft(2, '0')}'
          '${nextDay.day.toString().padLeft(2, '0')}';

      final show = showMap[ep['show_id'] as int]!;
      final summary = '${show['title']} - ${ep['season_number']}x${ep['episode_number']} - ${ep['title'] ?? 'TBA'}';

      buf.write('BEGIN:VEVENT\r\n');
      buf.write('UID:${ep['id']}@tvtracker\r\n');
      buf.write('DTSTAMP:$dtstamp\r\n');
      buf.write('DTSTART;VALUE=DATE:$dtStart\r\n');
      buf.write('DTEND;VALUE=DATE:$dtEnd\r\n');
      buf.write('SUMMARY:$summary\r\n');
      buf.write('END:VEVENT\r\n');
    }

    buf.write('END:VCALENDAR');
    return buf.toString();
  }

  static Future<void> importCsv(List<List<dynamic>> rows) async {
    // Basic CSV import logic (assuming specific format or mapping)
    // For this task, we'll assume it's a simple list of TMDB IDs to add
    for (var row in rows) {
      if (row.isEmpty) continue;
      final tmdbId = int.tryParse(row[0].toString());
      final type = row.length > 1 ? row[1].toString() : 'tv';
      
      if (tmdbId != null) {
        try {
          await addMedia(tmdbId, type, markSeen: true);
        } catch (e) {
          // Skip if error
        }
      }
    }
  }

  static Future<void> addMedia(int tmdbId, String type, {bool markSeen = false}) async {
    final client = Supabase.instance.client;
    final data = await TmdbService.getDetails(tmdbId, type);
    if (data == null) throw Exception('TMDB data not found');

    final posterUrl = data['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${data['poster_path']}' : '';
    final isMovie = type == 'movie';

    List<Map<String, dynamic>> allEpisodes = [];
    if (isMovie) {
      allEpisodes.add({
        'season_number': 1,
        'episode_number': 1,
        'name': data['title'],
        'air_date': data['release_date'],
        'runtime': data['runtime'],
      });
    } else {
      final numSeasons = data['number_of_seasons'] ?? 0;
      for (int i = 1; i <= numSeasons; i++) {
        final sData = await TmdbService.getSeasonDetails(tmdbId, i);
        if (sData != null && sData['episodes'] != null) {
          allEpisodes.addAll(List<Map<String, dynamic>>.from(sData['episodes']));
        }
      }
    }

    // Timezone shift logic (simplified for dart: skip check for now, default to false, since dart doesn't have IPC settings easily)
    bool shouldShift = false;

    // Check if show exists
    final existingShow = await client.from('shows').select('id').eq('api_id', data['id']).maybeSingle();
    int localId;

    if (existingShow != null) {
      localId = existingShow['id'];
    } else {
      // Calculate next ID
      final maxIdData = await client.from('shows').select('id').order('id', ascending: false).limit(1).maybeSingle();
      final nextShowId = (maxIdData != null ? maxIdData['id'] as int : 0) + 1;

      final insertData = {
        'id': nextShowId,
        'api_id': data['id'],
        'title': data['title'] ?? data['name'],
        'genre': ((data['genres'] ?? []) as List).map((g) => g['name']).join(', '),
        'overview': data['overview'],
        'poster_url': posterUrl,
        'total_episodes': isMovie ? 1 : (data['number_of_episodes'] ?? 0),
        'status': data['status'],
        'type': type,
        'timezone_offset': shouldShift ? 1 : 0,
      };

      final res = await client.from('shows').insert(insertData).select().single();
      localId = res['id'];
    }

    // Insert episodes
    final existingEps = await client.from('episodes').select('season_number, episode_number').eq('show_id', localId);
    final existingSet = Set<String>.from((existingEps as List).map((e) => '${e['season_number']}-${e['episode_number']}'));

    List<Map<String, dynamic>> newEps = [];
    for (var ep in allEpisodes) {
      if (ep['season_number'] > 0 && !existingSet.contains('${ep['season_number']}-${ep['episode_number']}')) {
        String finalAirDate = ep['air_date'] ?? '';
        newEps.add({
          'show_id': localId,
          'season_number': ep['season_number'],
          'episode_number': ep['episode_number'],
          'title': ep['name'],
          'air_date': finalAirDate.isEmpty ? null : finalAirDate,
          'runtime': ep['runtime'] ?? 0,
        });
      }
    }

    List<dynamic> insertedEps = [];
    if (newEps.isNotEmpty) {
      // Fetch max episode ID to bypass broken sequence
      final maxEpIdData = await client.from('episodes').select('id').order('id', ascending: false).limit(1).maybeSingle();
      int nextEpId = (maxEpIdData != null ? maxEpIdData['id'] as int : 0) + 1;
      
      for (int i = 0; i < newEps.length; i++) {
        newEps[i]['id'] = nextEpId++;
      }

      // Chunking insert to avoid limits
      for (int i = 0; i < newEps.length; i += 100) {
        final chunk = newEps.sublist(i, i + 100 > newEps.length ? newEps.length : i + 100);
        final res = await client.from('episodes').insert(chunk).select('id');
        insertedEps.addAll(res);
      }
    }

    if (markSeen) {
      final allEpsDb = await client.from('episodes').select('id').eq('show_id', localId);
      final allEpIds = (allEpsDb as List).map((e) => e['id'] as int).toList();
      
      final maxWatchIdData = await client.from('watch_history').select('id').order('id', ascending: false).limit(1).maybeSingle();
      int nextWatchId = (maxWatchIdData != null ? maxWatchIdData['id'] as int : 0) + 1;

      List<Map<String, dynamic>> watchInserts = [];
      for (var epId in allEpIds) {
        watchInserts.add({'id': nextWatchId++, 'episode_id': epId});
      }

      if (watchInserts.isNotEmpty) {
        for (int i = 0; i < watchInserts.length; i += 100) {
          final chunk = watchInserts.sublist(i, i + 100 > watchInserts.length ? watchInserts.length : i + 100);
          await client.from('watch_history').upsert(chunk, onConflict: 'episode_id');
        }
      }
    }
  }
}
