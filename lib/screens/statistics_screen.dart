import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';
import '../providers/statistics_provider.dart';
import '../services/ai_service.dart';

final statsYearFilterProvider = StateProvider<String>((ref) => 'All Time');

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  String? _aiRecap;
  bool _isGeneratingRecap = false;
  
  Future<void> _generateRecap(Map<String, dynamic> stats) async {
    final hasKey = await AiService.hasKey();
    if (!hasKey && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your Groq API key in Settings first.')),
      );
      return;
    }

    setState(() {
      _isGeneratingRecap = true;
      _aiRecap = null;
    });

    final recap = await AiService.generateUserRecap(stats);

    if (mounted) {
      setState(() {
        _isGeneratingRecap = false;
        _aiRecap = recap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final libraryAsync = ref.watch(libraryProvider);
    final allEpisodesAsync = ref.watch(allEpisodesProvider);
    final advancedStatsAsync = ref.watch(advancedStatsProvider);
    final selectedYear = ref.watch(statsYearFilterProvider);

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        centerTitle: false,
        title: const Text('Statistics', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        actions: [
          Builder(
            builder: (context) => Badge(
              isLabelVisible: notifications.isNotEmpty,
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: AppTheme.primary),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ),
          ),
        ],
      ),
      body: libraryAsync.when(
        data: (library) {
          return allEpisodesAsync.when(
            data: (allEpisodes) {
              int totalMins = 0;
              int tvSeen = 0, tvWatching = 0, tvNotStarted = 0;
              int moviesSeen = 0, moviesNotStarted = 0;
              Map<String, int> genreCounts = {};
              Map<String, int> releaseYearCounts = {};
              List<Map<String, dynamic>> topShows = [];
              Set<String> allYears = {};

              // Build mapping of show_id to first air_date year
              Map<int, String> showReleaseYears = {};
              for (var ep in allEpisodes) {
                final showId = ep['show_id'] as int;
                final airDate = ep['air_date'] as String?;
                if (airDate != null && airDate.isNotEmpty) {
                  final year = airDate.split('-').first;
                  if (year.length == 4 && int.tryParse(year) != null) {
                    if (!showReleaseYears.containsKey(showId)) {
                      showReleaseYears[showId] = year;
                    } else {
                      if (year.compareTo(showReleaseYears[showId]!) < 0) {
                        showReleaseYears[showId] = year;
                      }
                    }
                  }
                }
              }

              for (var item in library) {
                final rYear = showReleaseYears[item.show.id] ?? '';
                if (rYear.isNotEmpty && item.watchedEpisodes > 0) {
                  allYears.add(rYear);
                }

                if (selectedYear != 'All Time' && rYear != selectedYear) {
                  continue;
                }

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

                if (item.watchedEpisodes > 0) {
                  if (item.show.genre.isNotEmpty) {
                    final genres = item.show.genre.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty);
                    for (var g in genres) {
                      genreCounts[g] = (genreCounts[g] ?? 0) + 1;
                    }
                  }
                  if (rYear.isNotEmpty) {
                    releaseYearCounts[rYear] = (releaseYearCounts[rYear] ?? 0) + 1;
                  }
                }
              }

              topShows.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
              topShows = topShows.take(10).toList();

              final sortedGenres = genreCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top10Genres = sortedGenres.take(10).toList();
              final maxGenreVal = top10Genres.isNotEmpty ? top10Genres.first.value : 1;

              final sortedYears = releaseYearCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top5Years = sortedYears.take(5).toList();
              final maxYearVal = top5Years.isNotEmpty ? top5Years.first.value : 1;

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

              List<String> yearOptions = ['All Time', ...allYears.toList()..sort((a, b) => b.compareTo(a))];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI Recap Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF2A2A3E), AppTheme.background],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '✨ AI TV Time Recap',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.accent),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Generate a fun, personalized summary of your watching habits!',
                            style: TextStyle(color: AppTheme.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (_isGeneratingRecap)
                            const CircularProgressIndicator(color: AppTheme.accent)
                          else if (_aiRecap != null)
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Text(_aiRecap!, style: const TextStyle(color: Colors.white, height: 1.5)),
                            )
                          else
                            ElevatedButton(
                              onPressed: () {
                                _generateRecap({
                                  'timeWatched': '\$mo months, \$d days, \$h hours',
                                  'episodesLogged': '\$tvSeen',
                                  'moviesWatched': '\$moviesSeen',
                                  'topShows': topShows.take(5).map((s) => s['title']).toList(),
                                  'topGenres': top10Genres.take(3).map((g) => g.key).toList(),
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Generate My Recap', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your TV Story', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: yearOptions.contains(selectedYear) ? selectedYear : 'All Time',
                              dropdownColor: AppTheme.surfaceLight,
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              items: yearOptions.map((y) {
                                return DropdownMenuItem(value: y, child: Text(y));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(statsYearFilterProvider.notifier).state = val;
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    _SectionLabel(label: 'Total Time Watched'),
                    _SettingsGroup(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Row(
                            children: [
                              _SettingIcon(icon: Icons.timer_rounded, color: AppTheme.primary),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  '${mo > 0 ? '$mo mo ' : ''}${d > 0 ? '$d d ' : ''}${h > 0 ? '$h h ' : ''}$m m',
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    advancedStatsAsync.when(
                      data: (stats) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Viewing Habits & Velocity'),
                          _SettingsGroup(
                            children: [
                              _StatRow(icon: Icons.local_fire_department, color: Colors.deepOrange, title: 'Binge Sessions (4+ eps/day)', value: '${stats.bingeCount}'),
                              _Divider(),
                              _StatRow(icon: Icons.calendar_today_rounded, color: Colors.blue, title: 'Active Viewing Streak', value: '${stats.maxStreak} Days'),
                              _Divider(),
                              _StatRow(icon: Icons.event_note_rounded, color: Colors.purple, title: 'Peak Watch Day', value: stats.topWeekday),
                              _Divider(),
                              _StatRow(icon: Icons.nights_stay_rounded, color: Colors.indigo, title: 'Peak Time', value: stats.peakTimeSlot),
                            ],
                          ),
                          _SectionLabel(label: 'Achievement Badges'),
                          SizedBox(
                            height: 100,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                _BadgeItem(
                                  icon: Icons.directions_run_rounded,
                                  title: 'Marathoner',
                                  isUnlocked: stats.isMarathoner,
                                  color: Colors.green,
                                ),
                                _BadgeItem(
                                  icon: Icons.fast_forward_rounded,
                                  title: 'Serial Binger',
                                  isUnlocked: stats.isSerialBinger,
                                  color: Colors.deepOrange,
                                ),
                                _BadgeItem(
                                  icon: Icons.dark_mode_rounded,
                                  title: 'Night Owl',
                                  isUnlocked: stats.isNightOwl,
                                  color: Colors.indigo,
                                ),
                                _BadgeItem(
                                  icon: Icons.wb_sunny_rounded,
                                  title: 'Early Bird',
                                  isUnlocked: stats.isEarlyBird,
                                  color: Colors.amber,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, stack) => Text('Failed to load advanced stats: $err'),
                    ),

                    _SectionLabel(label: 'TV Shows'),
                    _SettingsGroup(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    if (tvSeenPct > 0) Expanded(flex: (tvSeenPct * 100).toInt(), child: Container(height: 8, color: AppTheme.primary)),
                                    if (tvWatchPct > 0) Expanded(flex: (tvWatchPct * 100).toInt(), child: Container(height: 8, color: Colors.amber)),
                                    if (tvNotPct > 0) Expanded(flex: (tvNotPct * 100).toInt(), child: Container(height: 8, color: Colors.grey)),
                                    if (totalTv == 0) Expanded(child: Container(height: 8, color: Colors.white10)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatLegend(color: AppTheme.primary, label: 'Seen', value: '$tvSeen'),
                                  _StatLegend(color: Colors.amber, label: 'Watching', value: '$tvWatching'),
                                  _StatLegend(color: Colors.grey, label: 'Not Started', value: '$tvNotStarted'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    _SectionLabel(label: 'Movies'),
                    _SettingsGroup(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    if (movSeenPct > 0) Expanded(flex: (movSeenPct * 100).toInt(), child: Container(height: 8, color: AppTheme.primary)),
                                    if (movNotPct > 0) Expanded(flex: (movNotPct * 100).toInt(), child: Container(height: 8, color: Colors.grey)),
                                    if (totalMovies == 0) Expanded(child: Container(height: 8, color: Colors.white10)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatLegend(color: AppTheme.primary, label: 'Seen', value: '$moviesSeen'),
                                  _StatLegend(color: Colors.grey, label: 'Watchlist', value: '$moviesNotStarted'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (top10Genres.isNotEmpty) ...[
                      _SectionLabel(label: 'Top Genres'),
                      _SettingsGroup(
                        children: top10Genres.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final g = entry.value;
                          final pct = g.value / maxGenreVal;
                          return Column(
                            children: [
                              _BarRow(
                                rank: idx + 1,
                                title: g.key,
                                value: '${g.value}',
                                pct: pct,
                                color: const Color(0xFFaf52de),
                              ),
                              if (idx != top10Genres.length - 1) _Divider(),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                    
                    if (top5Years.isNotEmpty) ...[
                      _SectionLabel(label: 'Favorite Release Years'),
                      _SettingsGroup(
                        children: top5Years.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final y = entry.value;
                          final pct = y.value / maxYearVal;
                          return Column(
                            children: [
                              _BarRow(
                                rank: idx + 1,
                                title: y.key,
                                value: '${y.value}',
                                pct: pct,
                                color: const Color(0xFF34c759),
                              ),
                              if (idx != top5Years.length - 1) _Divider(),
                            ],
                          );
                        }).toList(),
                      ),
                    ],

                    if (topShows.isNotEmpty) ...[
                      _SectionLabel(label: 'Top Shows'),
                      _SettingsGroup(
                        children: topShows.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final s = entry.value;
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      child: Text('${idx + 1}.', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                                    ),
                                    Expanded(
                                      child: Text(s['title'], style: const TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                    ),
                                    Text('${s['count']} eps', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              if (idx != topShows.length - 1) _Divider(),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

// ── SHARED WIDGETS ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 24, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.only(left: 16),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

class _SettingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _SettingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _StatLegend extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _StatLegend({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  final int rank;
  final String title;
  final String value;
  final double pct;
  final Color color;

  const _BarRow({required this.rank, required this.title, required this.value, required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('$rank.', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(color: AppTheme.textMain, fontSize: 14, fontWeight: FontWeight.w500)),
                    Text(value, style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    color: color,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  const _StatRow({required this.icon, required this.color, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _SettingIcon(icon: icon, color: color),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(color: AppTheme.textMain, fontSize: 15, fontWeight: FontWeight.w500))),
          Text(value, style: const TextStyle(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isUnlocked;
  final Color color;

  const _BadgeItem({required this.icon, required this.title, required this.isUnlocked, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: isUnlocked ? color.withValues(alpha: 0.15) : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUnlocked ? color.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isUnlocked ? color : Colors.white24, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? Colors.white : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
