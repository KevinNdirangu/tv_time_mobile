import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';
import '../theme/app_theme.dart';
import 'show_details_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryProvider);
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
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
            // Carousels
            final watching = libraryData.where((s) => s.show.type == 'tv' && s.watchedEpisodes > 0 && s.watchedEpisodes < s.show.totalEpisodes && s.show.isStopped == 0).toList();
            watching.sort((a, b) => b.show.id.compareTo(a.show.id));
            
            final upNext = libraryData.where((s) => s.show.type == 'tv' && s.watchedEpisodes == 0 && s.show.isStopped == 0).toList();
            upNext.sort((a, b) => b.show.id.compareTo(a.show.id));

            final recentMovies = libraryData.where((s) => s.show.type == 'movie' && s.watchedEpisodes == 0).toList();
            recentMovies.sort((a, b) => b.show.id.compareTo(a.show.id));

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting & Clock
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Expanded(
                          child: Text(
                            'Welcome Back!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textMain,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                DateFormat('MMM d, yyyy').format(DateTime.now()),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                DateFormat('h:mm a').format(DateTime.now()),
                                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Continue Watching
                  if (watching.isNotEmpty) ...[
                    _buildSectionTitle('Continue Watching'),
                    _buildLibraryCarousel(watching, true),
                  ],

                  // Up Next to Start
                  if (upNext.isNotEmpty) ...[
                    _buildSectionTitle('Up Next to Start'),
                    _buildLibraryCarousel(upNext, false),
                  ],

                  // Calendar Carousels
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
                            _buildSectionTitle('Airing Today'),
                            _buildCalendarCarousel(airingToday),
                          ],
                          if (airingThisWeek.isNotEmpty) ...[
                            _buildSectionTitle('New Episodes This Week'),
                            _buildCalendarCarousel(airingThisWeek),
                          ],
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // Recent Movies
                  if (recentMovies.isNotEmpty) ...[
                    _buildSectionTitle('Recently Released Movies'),
                    _buildLibraryCarousel(recentMovies, false),
                  ],

                  // Stats Cards
                  const SizedBox(height: 10),
                  _buildSectionTitle('Your Stats'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            title: 'TIME WATCHED',
                            value: timeWatched,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            title: 'EPISODES LOGGED',
                            value: totalEpisodesLogged.toString(),
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
          error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12, top: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMain,
        ),
      ),
    );
  }

  Widget _buildLibraryCarousel(List<LibraryShow> shows, bool showProgress) {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
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
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.show.posterUrl != null
                          ? Image.network(item.show.posterUrl!, fit: BoxFit.cover, width: double.infinity)
                          : Container(color: AppTheme.surfaceLight),
                    ),
                  ),
                  if (showProgress) ...[
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.watchedEpisodes}/${item.show.totalEpisodes}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.primary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
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

  Widget _buildCalendarCarousel(List<CalendarEpisode> episodes) {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
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
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ep.posterUrl != null
                    ? Image.network(ep.posterUrl!, fit: BoxFit.cover, width: double.infinity)
                    : Container(color: AppTheme.surfaceLight),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
