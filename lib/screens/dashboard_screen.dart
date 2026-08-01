import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';
import '../theme/app_theme.dart';
import 'show_details_screen.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final calendarAsync = ref.watch(calendarProvider);
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: libraryAsync.when(
          data: (libraryData) {
            // Stats
            int totalEpisodesLogged = 0;
            int totalRuntime = 0;
            for (var item in libraryData) {
              totalEpisodesLogged += item.watchedEpisodes;
              totalRuntime += item.runtime;
            }

            String timeWatched = '0h';
            if (totalRuntime > 0) {
              final mo = totalRuntime ~/ 43200;
              var rem = totalRuntime % 43200;
              final d = rem ~/ 1440;
              rem %= 1440;
              final h = rem ~/ 60;
              
              timeWatched = '';
              if (mo > 0) timeWatched += '${mo}mo ';
              if (d > 0) timeWatched += '${d}d ';
              timeWatched += '${h}h';
            }
            
            // Filters
            final watching = libraryData.where((s) => s.show.type == 'tv' && s.watchedEpisodes > 0 && s.watchedEpisodes < s.show.totalEpisodes && s.show.isStopped == 0).toList();
            watching.sort((a, b) => b.show.id.compareTo(a.show.id));
            
            final upNext = libraryData.where((s) => s.show.type == 'tv' && s.watchedEpisodes == 0 && s.show.isStopped == 0).toList();
            upNext.sort((a, b) => b.show.id.compareTo(a.show.id));

            final recentMovies = libraryData.where((s) => s.show.type == 'movie' && s.watchedEpisodes == 0).toList();
            recentMovies.sort((a, b) => b.show.id.compareTo(a.show.id));

            return CustomScrollView(
              slivers: [
                // Premium Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu_rounded, color: AppTheme.textMain, size: 28),
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Dashboard',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textMain,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Builder(
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Badge(
                              isLabelVisible: notifications.isNotEmpty,
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: Icon(Icons.notifications_rounded, color: AppTheme.primary, size: 22),
                                onPressed: () => Scaffold.of(context).openEndDrawer(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 40),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      
                      // Hero Stats Section
                      if (totalEpisodesLogged > 0 || totalRuntime > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _StatHeroCard(
                                  icon: Icons.timer_rounded,
                                  title: 'Time Watched',
                                  value: timeWatched,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatHeroCard(
                                  icon: Icons.layers_rounded,
                                  title: 'Episodes',
                                  value: totalEpisodesLogged.toString(),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (watching.isNotEmpty) ...[
                        _SectionTitle('Continue Watching', icon: Icons.play_circle_fill_rounded),
                        _LibraryCarousel(shows: watching, showProgress: true),
                      ],

                      if (upNext.isNotEmpty) ...[
                        _SectionTitle('Up Next', icon: Icons.queue_play_next_rounded),
                        _LibraryCarousel(shows: upNext, showProgress: false),
                      ],

                      // Calendar Data
                      calendarAsync.when(
                        data: (calendarData) {
                          final now = DateTime.now();
                          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                          final nextWeek = now.add(const Duration(days: 7));
                          final nextWeekStr = "${nextWeek.year}-${nextWeek.month.toString().padLeft(2, '0')}-${nextWeek.day.toString().padLeft(2, '0')}";

                          final airingToday = calendarData.where((e) => e.airDate == todayStr).toList();
                          final airingThisWeek = calendarData.where((e) => e.airDate.compareTo(todayStr) > 0 && e.airDate.compareTo(nextWeekStr) <= 0).toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (airingToday.isNotEmpty) ...[
                                _SectionTitle('Airing Today', icon: Icons.today_rounded, highlight: true),
                                _CalendarCarousel(episodes: airingToday),
                              ],
                              if (airingThisWeek.isNotEmpty) ...[
                                _SectionTitle('New This Week', icon: Icons.date_range_rounded),
                                _CalendarCarousel(episodes: airingThisWeek),
                              ],
                            ],
                          );
                        },
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      if (recentMovies.isNotEmpty) ...[
                        _SectionTitle('Movie Watchlist', icon: Icons.movie_filter_rounded),
                        _LibraryCarousel(shows: recentMovies, showProgress: false),
                      ],
                    ]),
                  ),
                ),
              ],
            );
          },
          loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool highlight;

  const _SectionTitle(this.title, {required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 32, bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: highlight ? AppTheme.primary : AppTheme.textMuted, size: 20),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: highlight ? AppTheme.textMain : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatHeroCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatHeroCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceLight,
            AppTheme.surfaceLight.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primary, size: 16),
              const SizedBox(width: 6),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryCarousel extends StatelessWidget {
  final List<LibraryShow> shows;
  final bool showProgress;

  const _LibraryCarousel({required this.shows, required this.showProgress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200, // Slightly taller for better proportions
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: shows.length > 15 ? 15 : shows.length,
        itemBuilder: (context, index) {
          final item = shows[index];
          final pct = item.show.totalEpisodes > 0 ? (item.watchedEpisodes / item.show.totalEpisodes) : 0.0;
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                tmdbId: item.show.apiId,
                type: item.show.type,
              )));
            },
            child: Container(
              width: 125,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.show.posterUrl != null
                            ? Image.network(item.show.posterUrl!, fit: BoxFit.cover, width: double.infinity)
                            : Container(color: AppTheme.surfaceLight, child: const Icon(Icons.tv_rounded, color: Colors.white24)),
                      ),
                    ),
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: pct.clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.watchedEpisodes}/${item.show.totalEpisodes}',
                          style: TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarCarousel extends StatelessWidget {
  final List<CalendarEpisode> episodes;

  const _CalendarCarousel({required this.episodes});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 185,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: episodes.length > 15 ? 15 : episodes.length,
        itemBuilder: (context, index) {
          final ep = episodes[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                tmdbId: ep.tmdbId,
                type: 'tv',
              )));
            },
            child: Container(
              width: 125,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ep.posterUrl != null
                      ? Image.network(ep.posterUrl!, fit: BoxFit.cover, width: double.infinity)
                      : Container(color: AppTheme.surfaceLight, child: const Icon(Icons.calendar_today_rounded, color: Colors.white24)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
