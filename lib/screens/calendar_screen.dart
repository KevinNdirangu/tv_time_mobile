import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'show_details_screen.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: calendarAsync.when(
        data: (episodes) {
          if (episodes.isEmpty) {
            return const Center(child: Text('No upcoming episodes.', style: TextStyle(color: AppTheme.textMuted)));
          }

          // Group by date
          final Map<String, List<CalendarEpisode>> grouped = {};
          for (var ep in episodes) {
            grouped.putIfAbsent(ep.airDate, () => []).add(ep);
          }

          final sortedDates = grouped.keys.toList()..sort();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateString = sortedDates[index];
              final epsForDate = grouped[dateString]!;
              final date = DateTime.parse(dateString);
              
              final isToday = date.difference(DateTime.now()).inDays == 0 && date.day == DateTime.now().day;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      isToday ? 'Today' : DateFormat('EEEE, MMMM d').format(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isToday ? AppTheme.primary : AppTheme.textMain,
                      ),
                    ),
                  ),
                  ...epsForDate.map((ep) => _buildEpisodeCard(context, ep)),
                  const SizedBox(height: 16),
                ],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, _) => Center(child: Text('Error loading calendar: $err')),
      ),
    );
  }

  Widget _buildEpisodeCard(BuildContext context, CalendarEpisode ep) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
          tmdbId: ep.tmdbId,
          type: 'tv',
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: ep.posterUrl != null
                  ? Image.network(
                      ep.posterUrl!,
                      width: 80,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholderImage(),
                    )
                  : _placeholderImage(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ep.showTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textMain),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'S${ep.seasonNumber} E${ep.episodeNumber}',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ep.title,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 80,
      height: 120,
      color: AppTheme.surface,
      child: const Center(child: Icon(Icons.tv, color: AppTheme.textMuted)),
    );
  }
}
