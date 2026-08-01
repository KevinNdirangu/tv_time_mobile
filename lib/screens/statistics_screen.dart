import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';
import '../theme/app_theme.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      appBar: AppBar(
        title: const Text('Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Builder(
            builder: (context) => Badge(
              isLabelVisible: notifications.isNotEmpty,
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
      body: libraryAsync.when(
        data: (library) {
          int totalMins = 0;
          int tvSeen = 0, tvWatching = 0, tvNotStarted = 0;
          int moviesSeen = 0, moviesNotStarted = 0;
          Map<String, int> genreCounts = {};
          List<Map<String, dynamic>> topShows = [];

          for (var item in library) {
            totalMins += item.runtime;

            if (item.show.type == 'tv') {
              if (item.watchedEpisodes > 0) {
                if (item.watchedEpisodes >= item.show.totalEpisodes && item.show.totalEpisodes > 0 && item.show.status == 'Ended') {
                  tvSeen++;
                } else {
                  tvWatching++;
                }
                topShows.add({'title': item.show.title, 'count': item.watchedEpisodes});
              } else {
                tvNotStarted++;
              }
            } else {
              if (item.watchedEpisodes > 0) {
                moviesSeen++;
              } else {
                moviesNotStarted++;
              }
            }

            if (item.watchedEpisodes > 0 && item.show.genre.isNotEmpty) {
              final genres = item.show.genre.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty);
              for (var g in genres) {
                genreCounts[g] = (genreCounts[g] ?? 0) + 1;
              }
            }
          }

          topShows.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
          topShows = topShows.take(10).toList();

          final sortedGenres = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final top10Genres = sortedGenres.take(10).toList();
          final maxGenreVal = top10Genres.isNotEmpty ? top10Genres.first.value : 1;

          final mo = totalMins ~/ 43200;
          final d = (totalMins % 43200) ~/ 1440;
          final h = (totalMins % 1440) ~/ 60;
          final m = totalMins % 60;

          final totalTv = tvSeen + tvWatching + tvNotStarted;
          final tvSeenPct = totalTv > 0 ? (tvSeen / totalTv) : 0.0;
          final tvWatchPct = totalTv > 0 ? (tvWatching / totalTv) : 0.0;
          final tvNotPct = totalTv > 0 ? (tvNotStarted / totalTv) : 0.0;

          final totalMovies = moviesSeen + moviesNotStarted;
          final movSeenPct = totalMovies > 0 ? (moviesSeen / totalMovies) : 0.0;
          final movNotPct = totalMovies > 0 ? (moviesNotStarted / totalMovies) : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your TV Story', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text('All Time', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Total Time Watched
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.timer_rounded, color: AppTheme.primary, size: 40),
                      const SizedBox(height: 10),
                      const Text('Total Time Watched', style: TextStyle(color: AppTheme.textMuted)),
                      const SizedBox(height: 5),
                      Text(
                        '${mo > 0 ? '$mo mo ' : ''}${d > 0 ? '$d d ' : ''}${h > 0 ? '$h h ' : ''}$m m',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TV Shows Completion
                const Text('TV Shows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      if (tvSeenPct > 0) Expanded(flex: (tvSeenPct * 100).toInt(), child: Container(height: 12, color: AppTheme.primary)),
                      if (tvWatchPct > 0) Expanded(flex: (tvWatchPct * 100).toInt(), child: Container(height: 12, color: Colors.amber)),
                      if (tvNotPct > 0) Expanded(flex: (tvNotPct * 100).toInt(), child: Container(height: 12, color: Colors.grey)),
                      if (totalTv == 0) Expanded(child: Container(height: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Seen: $tvSeen', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                    Text('Watching: $tvWatching', style: const TextStyle(color: Colors.amber, fontSize: 12)),
                    Text('Not Started: $tvNotStarted', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 24),

                // Movies Completion
                const Text('Movies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    children: [
                      if (movSeenPct > 0) Expanded(flex: (movSeenPct * 100).toInt(), child: Container(height: 12, color: AppTheme.primary)),
                      if (movNotPct > 0) Expanded(flex: (movNotPct * 100).toInt(), child: Container(height: 12, color: Colors.grey)),
                      if (totalMovies == 0) Expanded(child: Container(height: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Seen: $moviesSeen', style: const TextStyle(color: AppTheme.primary, fontSize: 12)),
                    Text('Watchlist: $moviesNotStarted', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 24),

                // Top Genres
                if (top10Genres.isNotEmpty) ...[
                  const Text('Top Genres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 10),
                  ...top10Genres.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final g = entry.value;
                    final pct = g.value / maxGenreVal;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          SizedBox(width: 24, child: Text('${idx + 1}.', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(g.key, style: const TextStyle(color: AppTheme.textMain, fontSize: 14)),
                                    Text('${g.value} entries', style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    backgroundColor: Colors.white10,
                                    color: AppTheme.primary,
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // Top Shows
                if (topShows.isNotEmpty) ...[
                  const Text('Top Shows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 10),
                  ...topShows.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final s = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white10))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                SizedBox(width: 24, child: Text('${idx + 1}.', style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold))),
                                Expanded(child: Text(s['title'], style: const TextStyle(color: AppTheme.textMain), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                          Text('${s['count']} eps', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 40),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
