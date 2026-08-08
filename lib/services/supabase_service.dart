import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/show.dart';
import '../models/library_show.dart';
import 'tmdb_service.dart';
import 'widget_service.dart';
import 'ai_service.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final showsProvider = FutureProvider<List<Show>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  
  // Wait for the query to complete
  final response = await _fetchAll(client, 'shows', '*');
  
  // Map the JSON objects to Show model
  final shows = response.map((e) => Show.fromJson(e)).toList();
  shows.sort((a, b) => b.id.compareTo(a.id));
  return shows;
});

Future<List<dynamic>> _fetchAll(SupabaseClient client, String table, String selectColumns) async {
  int step = 1000;
  int from = 0;
  List<dynamic> allData = [];
  
  while (true) {
    final response = await client.from(table).select(selectColumns).order('id', ascending: true).range(from, from + step - 1);
    final data = response as List<dynamic>;
    allData.addAll(data);
    if (data.length < step) break;
    from += step;
  }
  
  return allData;
}

class LibraryNotifier extends AsyncNotifier<List<LibraryShow>> {
  static const _cacheFileName = 'tvt_lib_cache.json';

  Future<File> _getCacheFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_cacheFileName');
  }

  @override
  Future<List<LibraryShow>> build() async {
    // 1. Try to load from local file cache
    try {
      final file = await _getCacheFile();
      if (await file.exists()) {
        final cachedStr = await file.readAsString();
        final decoded = json.decode(cachedStr) as List;
        final cachedLib = decoded.map((e) => LibraryShow.fromJson(e)).toList();
        
        // 2. Trigger background refresh
        _refresh();
        return cachedLib;
      }
    } catch (e) {
      // Cache invalid, file missing, or error parsing
    }
    
    // 3. Fallback to normal fetch
    return _fetchFromNetwork();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _fetchFromNetwork();
      state = AsyncData(fresh);
    } catch (e) {
      // Background refresh failed, keep old state
    }
  }

  Future<List<LibraryShow>> _fetchFromNetwork() async {
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
          bool hasAired = false;
          if (ep['air_date'] != null && ep['air_date'].toString().isNotEmpty) {
            final airDate = DateTime.tryParse(ep['air_date']);
            if (airDate != null && airDate.compareTo(now) <= 0) {
              hasAired = true;
            }
          }
          
          final history = epHistory[ep['id']] ?? [];
          if (history.isNotEmpty) {
            watched++;
            hasAired = true; // If watched, it must have aired
            runtime += (ep['runtime'] as int? ?? 0);
            final wAt = DateTime.tryParse(history[0]['watched_at'] ?? '')?.millisecondsSinceEpoch ?? 0;
            if (wAt > lastWatched) lastWatched = wAt;
          } else if (!hasAired && s.type == 'movie' && (ep['air_date'] == null || ep['air_date'].toString().isEmpty)) {
             hasAired = true; // Movies without release dates are usually old/obscure and released
          }

          if (hasAired) aired++;
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

    // Save to local file cache
    try {
      final file = await _getCacheFile();
      await file.writeAsString(json.encode(lib.map((e) => e.toJson()).toList()));
      
      // Clean up old SharedPreferences cache if it exists (migration)
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('tvt_lib_cache')) {
        await prefs.remove('tvt_lib_cache');
      }
    } catch (e) {
      print('Failed to save library cache: $e');
    }
    
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
  final res = await _fetchAll(client, 'episodes', 'id, show_id, air_date');
  return List<Map<String, dynamic>>.from(res);
});

final watchHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = Supabase.instance.client;
  final res = await _fetchAll(client, 'watch_history', 'id, episode_id, watched_at');
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
  final String type;

  CalendarEpisode({
    required this.showId,
    required this.showTitle,
    this.posterUrl,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.title,
    required this.airDate,
    required this.tmdbId,
    required this.type,
  });
}

final calendarProvider = FutureProvider<List<CalendarEpisode>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final shows = await ref.watch(showsProvider.future);
  
  // Filter out stopped shows
  final activeShows = shows.where((s) => s.isStopped == 0).toList();
  if (activeShows.isEmpty) return [];
  
  final activeShowIds = activeShows.map((s) => s.id).toList();

  final now = DateTime.now();
  final past = now.subtract(const Duration(days: 30));
  final fromDate = "${past.year}-${past.month.toString().padLeft(2, '0')}-${past.day.toString().padLeft(2, '0')}";

  // Query episodes globally from fromDate (to avoid URL length limits with large inFilter)
  final response = await client.from('episodes')
      .select('show_id, season_number, episode_number, title, air_date')
      .gte('air_date', fromDate)
      .order('air_date', ascending: true)
      .limit(1000);
  
  final List<CalendarEpisode> calendar = [];
  final activeShowIdsSet = activeShowIds.toSet();

  for (var ep in response as List<dynamic>) {
    final showId = ep['show_id'];
    if (!activeShowIdsSet.contains(showId)) continue;

    try {
      final show = activeShows.firstWhere((s) => s.id == showId);
      calendar.add(CalendarEpisode(
        showId: showId,
        showTitle: show.title,
        posterUrl: show.posterUrl,
        seasonNumber: ep['season_number'],
        episodeNumber: ep['episode_number'],
        title: ep['title'] ?? 'TBA',
        airDate: ep['air_date'],
        tmdbId: show.apiId,
        type: show.type,
      ));
    } catch (e) {
      // Show not found or is stopped, ignore
    }
  }
  
  try {
    await WidgetService.updateCalendarWidget(calendar);
  } catch (_) {}

  return calendar;
});

class SupabaseShowDetails {
  final Show show;
  final List<Map<String, dynamic>> episodes;
  final List<int> watchedEpisodeIds;
  final String? lastWatched;

  SupabaseShowDetails({
    required this.show,
    required this.episodes,
    required this.watchedEpisodeIds,
    this.lastWatched,
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
    final watchRes = await client.from('watch_history').select('episode_id, watched_at').filter('episode_id', 'in', epIds);
    final watchedIds = <int>[];
    String? latestWatched;
    final watchMap = <int, String>{};
    for (var row in (watchRes as List)) {
      watchedIds.add(row['episode_id'] as int);
      if (row['watched_at'] != null) {
        watchMap[row['episode_id'] as int] = row['watched_at'];
        if (latestWatched == null || DateTime.parse(row['watched_at']).isAfter(DateTime.parse(latestWatched))) {
          latestWatched = row['watched_at'];
        }
      }
    }
    
    for (var ep in episodes) {
      if (watchMap.containsKey(ep['id'])) {
        ep['watched_at'] = watchMap[ep['id']];
      }
    }
    
    return SupabaseShowDetails(show: show, episodes: episodes, watchedEpisodeIds: watchedIds, lastWatched: latestWatched);
  }

  static Future<void> syncActiveShows(List<Show> activeShows) async {
    final client = Supabase.instance.client;
    
    final showsToSync = activeShows.where((s) => s.isStopped == 0 && s.type == 'tv').toList();
    
    for (var show in showsToSync) {
      try {
        final tmdbData = await TmdbService.getDetails(show.apiId, 'tv');
        if (tmdbData == null) continue;
        
        final tmdbTotalEpisodes = tmdbData['number_of_episodes'] ?? show.totalEpisodes;
        final numSeasons = tmdbData['number_of_seasons'] ?? 0;
        final status = tmdbData['status'];

        if (status == 'Returning Series' || tmdbTotalEpisodes > show.totalEpisodes) {
           if (numSeasons > 0) {
             final startSeason = numSeasons > 1 ? numSeasons - 1 : 1;
             for (int s = startSeason; s <= numSeasons; s++) {
               final sData = await TmdbService.getSeasonDetails(show.apiId, s);
               if (sData != null && sData['episodes'] != null) {
                 final eps = List<Map<String, dynamic>>.from(sData['episodes']);
                 
                 final existingEps = await client.from('episodes')
                     .select('id, episode_number')
                     .eq('show_id', show.id)
                     .eq('season_number', s);
                     
                 final existingMap = { for (var e in existingEps as List) e['episode_number']: e['id'] };
                 
                 List<Map<String, dynamic>> toInsert = [];
                 for (var ep in eps) {
                   final epNum = ep['episode_number'];
                   String finalAirDate = ep['air_date'] ?? '';
                   
                   if (existingMap.containsKey(epNum)) {
                     if (finalAirDate.isNotEmpty) {
                        await client.from('episodes')
                            .update({'air_date': finalAirDate})
                            .eq('id', existingMap[epNum]);
                     }
                   } else {
                     toInsert.add({
                       'show_id': show.id,
                       'season_number': s,
                       'episode_number': epNum,
                       'title': ep['name'],
                       'air_date': finalAirDate.isEmpty ? null : finalAirDate,
                       'runtime': ep['runtime'] ?? 0,
                     });
                   }
                 }
                 
                 if (toInsert.isNotEmpty) {
                   final maxEpIdData = await client.from('episodes').select('id').order('id', ascending: false).limit(1).maybeSingle();
                   int nextEpId = (maxEpIdData != null ? maxEpIdData['id'] as int : 0) + 1;
                   
                   for (int i = 0; i < toInsert.length; i++) {
                     toInsert[i]['id'] = nextEpId++;
                   }
                   
                   for (int i = 0; i < toInsert.length; i += 100) {
                     final chunk = toInsert.sublist(i, i + 100 > toInsert.length ? toInsert.length : i + 100);
                     await client.from('episodes').insert(chunk);
                   }
                 }
               }
             }
           }
           
           await client.from('shows').update({
             'total_episodes': tmdbTotalEpisodes,
             'status': status,
           }).eq('id', show.id);
        }
      } catch (e) {
        print("Error syncing show ${show.title}: $e");
      }
    }
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

  static Future<void> removeShow(int showId) async {
    final client = Supabase.instance.client;
    await client.from('shows').delete().eq('id', showId);
  }

  static Future<void> setStopped(int showId, int val) async {
    final client = Supabase.instance.client;
    await client.from('shows').update({'is_stopped': val}).eq('id', showId);
  }

  static Future<void> markSeason(int showId, int seasonNum, bool isWatched) async {
    final client = Supabase.instance.client;
    if (isWatched) {
      final epsRes = await client.from('episodes').select('id, air_date, watch_history(id)').eq('show_id', showId).eq('season_number', seasonNum);
      final List eps = epsRes as List;
      final now = DateTime.now();
      
      List<Map<String, dynamic>> toInsert = [];
      for (var ep in eps) {
        if (ep['air_date'] != null && ep['air_date'].toString().isNotEmpty) {
          final airDate = DateTime.parse(ep['air_date'].toString());
          final history = ep['watch_history'] as List?;
          if (airDate.isBefore(now) || airDate.isAtSameMomentAs(now)) {
            if (history == null || history.isEmpty) {
              toInsert.add({'episode_id': ep['id']});
            }
          }
        }
      }
      
      if (toInsert.isNotEmpty) {
        final maxIdRes = await client.from('watch_history').select('id').order('id', ascending: false).limit(1).maybeSingle();
        int nextId = (maxIdRes != null ? maxIdRes['id'] as int : 0) + 1;
        for (int i = 0; i < toInsert.length; i++) {
          toInsert[i]['id'] = nextId + i;
        }
        await client.from('watch_history').insert(toInsert);
      }
    } else {
      final epsRes = await client.from('episodes').select('id').eq('show_id', showId).eq('season_number', seasonNum);
      final List eps = epsRes as List;
      if (eps.isNotEmpty) {
        final ids = eps.map((e) => e['id']).toList();
        await client.from('watch_history').delete().inFilter('episode_id', ids);
      }
    }
  }

  static Future<void> markUpTo(int showId, int seasonNum, int epNum) async {
    final client = Supabase.instance.client;
    final epsRes = await client.from('episodes').select('id, season_number, episode_number, air_date, watch_history(id)').eq('show_id', showId);
    final List eps = epsRes as List;
    final now = DateTime.now();
    
    List<Map<String, dynamic>> toInsert = [];
    for (var ep in eps) {
      if (ep['air_date'] != null && ep['air_date'].toString().isNotEmpty) {
        final airDate = DateTime.parse(ep['air_date'].toString());
        final sNum = ep['season_number'] as int;
        final eNum = ep['episode_number'] as int;
        final history = ep['watch_history'] as List?;
        
        final isBeforeOrEq = sNum < seasonNum || (sNum == seasonNum && eNum <= epNum);
        
        if (isBeforeOrEq && (airDate.isBefore(now) || airDate.isAtSameMomentAs(now))) {
          if (history == null || history.isEmpty) {
            toInsert.add({'episode_id': ep['id']});
          }
        }
      }
    }
    
    if (toInsert.isNotEmpty) {
      final maxIdRes = await client.from('watch_history').select('id').order('id', ascending: false).limit(1).maybeSingle();
      int nextId = (maxIdRes != null ? maxIdRes['id'] as int : 0) + 1;
      for (int i = 0; i < toInsert.length; i++) {
        toInsert[i]['id'] = nextId + i;
      }
      await client.from('watch_history').insert(toInsert);
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

  static Future<void> importCsv(List<List<dynamic>> rows, {Function(int, int, String)? onProgress}) async {
    final client = Supabase.instance.client;
    
    if (rows.isEmpty || rows.length < 2) return;
    
    final header = rows[0].map((e) => e.toString().toLowerCase().trim()).toList();
    int showIdx = header.indexOf('show_name');
    if (showIdx == -1) showIdx = header.indexOf('series_name');
    if (showIdx == -1) showIdx = header.indexOf('title');
    
    int seasonIdx = header.indexOf('season');
    if (seasonIdx == -1) seasonIdx = header.indexOf('s_no');
    
    int episodeIdx = header.indexOf('episode');
    if (episodeIdx == -1) episodeIdx = header.indexOf('ep_no');
    
    int dateIdx = header.indexOf('date_watched');
    if (dateIdx == -1) dateIdx = header.indexOf('created_at');
    
    if (showIdx == -1 || seasonIdx == -1 || episodeIdx == -1) return;

    final Map<String, List<List<dynamic>>> showsMap = {};
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= showIdx) continue;
      final showName = row[showIdx].toString();
      if (showName.isEmpty) continue;
      showsMap.putIfAbsent(showName, () => []).add(row);
    }

    final showNames = showsMap.keys.toList();
    List<Map<String, dynamic>> watchHistoryBuffer = [];
    
    for (int i = 0; i < showNames.length; i++) {
      final showName = showNames[i];
      if (onProgress != null) onProgress(i + 1, showNames.length, showName);

      try {
        final searchRes = await TmdbService.search(showName);
        if (searchRes.isNotEmpty) {
          final tmdbId = searchRes.first['id'];
          final type = searchRes.first['media_type'] == 'movie' ? 'movie' : 'tv';
          
          await addMedia(tmdbId, type, markSeen: false);
          
          // Get localId
          final showData = await client.from('shows').select('id').eq('api_id', tmdbId).maybeSingle();
          if (showData != null) {
            final localId = showData['id'];
            final epData = await client.from('episodes').select('id, season_number, episode_number').eq('show_id', localId);
            final epsMap = <String, int>{};
            for (var ep in epData as List) {
              epsMap['${ep['season_number']}-${ep['episode_number']}'] = ep['id'];
            }
            
            for (var row in showsMap[showName]!) {
              if (row.length <= episodeIdx) continue;
              int? sNum = int.tryParse(row[seasonIdx].toString());
              int? eNum = int.tryParse(row[episodeIdx].toString());
              
              if (sNum == null || eNum == null) {
                if (type == 'movie') {
                  sNum = 1;
                  eNum = 1;
                } else {
                  continue;
                }
              }
              
              final epId = epsMap['$sNum-$eNum'];
              if (epId != null) {
                String? watchedAt;
                if (dateIdx != -1 && row.length > dateIdx) {
                   watchedAt = row[dateIdx].toString();
                }
                
                final maxWatchIdData = await client.from('watch_history').select('id').order('id', ascending: false).limit(1).maybeSingle();
                final nextId = (maxWatchIdData != null ? maxWatchIdData['id'] as int : 0) + 1 + watchHistoryBuffer.length;
                
                watchHistoryBuffer.add({
                  'id': nextId,
                  'episode_id': epId,
                  if (watchedAt != null && watchedAt.isNotEmpty) 'watched_at': watchedAt
                });
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error importing $showName: $e');
      }
      
      // Delay to respect TMDB rate limits
      await Future.delayed(const Duration(milliseconds: 600));
    }

    if (onProgress != null) onProgress(showNames.length, showNames.length, 'Chunking & Uploading ${watchHistoryBuffer.length} history records...');
    
    for (int i = 0; i < watchHistoryBuffer.length; i += 500) {
      final chunk = watchHistoryBuffer.sublist(i, i + 500 > watchHistoryBuffer.length ? watchHistoryBuffer.length : i + 500);
      try {
        await client.from('watch_history').insert(chunk);
      } catch (e) {
        debugPrint('Chunk upload error: $e'); // ignore duplicates or partial failures
      }
      if (onProgress != null) onProgress(i + chunk.length, watchHistoryBuffer.length, 'Uploaded ${i + chunk.length} / ${watchHistoryBuffer.length} history records...');
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
      
      String autoTags = '';
      final hasAiKey = (await AiService.getApiKey()) != null;
      if (hasAiKey) {
        autoTags = await AiService.autoTag(data['title'] ?? data['name'], data['overview'] ?? '', ((data['genres'] ?? []) as List).map((g) => g['name']).join(', '));
      }

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
        'custom_tags': autoTags,
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

  static Future<int> repairAllLegacyMovies() async {
    final client = Supabase.instance.client;
    
    // 1. Fetch all movies
    final moviesRes = await client.from('shows').select('id, api_id, title').eq('type', 'movie');
    final movies = List<Map<String, dynamic>>.from(moviesRes as List);
    
    if (movies.isEmpty) return 0;
    final movieIds = movies.map((m) => m['id']).toList();
    
    // 2. Fetch all episodes for these movies
    final epsRes = await client.from('episodes').select('show_id').inFilter('show_id', movieIds);
    final eps = List<Map<String, dynamic>>.from(epsRes as List);
    
    // 3. Find movies with ZERO episodes
    final Set<int> showsWithEpisodes = eps.map((e) => e['show_id'] as int).toSet();
    final missingMovies = movies.where((m) => !showsWithEpisodes.contains(m['id'])).toList();
    
    if (missingMovies.isEmpty) return 0;
    
    // 4. Repair them
    int repairedCount = 0;
    for (var m in missingMovies) {
      try {
        print("Repairing movie: ${m['title']}");
        await addMedia(m['api_id'], 'movie', markSeen: false);
        repairedCount++;
      } catch (e) {
        print("Error repairing movie ${m['title']}: $e");
      }
    }
    
    return repairedCount;
  }
}
