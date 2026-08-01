import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(calendarProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Export .ics',
            onPressed: () async {
              try {
                final icsData = await SupabaseActions.generateIcs();
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/tvtracker.ics');
                await file.writeAsString(icsData);
                await Share.shareXFiles([XFile(file.path)], text: 'My TV Time Tracker Calendar');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to export calendar: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: calendarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
        data: (calendarData) {
          if (calendarData.isEmpty) {
            return const Center(
              child: Text('No upcoming media scheduled.', style: TextStyle(color: AppTheme.textMuted)),
            );
          }

          // Group by Date
          final Map<String, List<CalendarEpisode>> grouped = {};
          for (var ep in calendarData) {
            grouped.putIfAbsent(ep.airDate, () => []).add(ep);
          }

          final sortedDates = grouped.keys.toList()..sort();
          final now = DateTime.now();
          final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateStr = sortedDates[index];
                      final episodes = grouped[dateStr]!;
                      
                      final isToday = dateStr == todayStr;
                      
                      String displayDate = '';
                      try {
                        final parsed = DateTime.parse(dateStr);
                        if (isToday) {
                          displayDate = 'TODAY';
                        } else {
                          displayDate = DateFormat('EEEE, MMM d').format(parsed);
                        }
                      } catch (_) {
                        displayDate = dateStr;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
                            child: Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppTheme.surfaceLight, width: 1)),
                              ),
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                displayDate,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppTheme.primary : AppTheme.textMain,
                                ),
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 12.0,
                            runSpacing: 16.0,
                            children: episodes.map((ep) {
                              return _buildEpisodeCard(context, ep, now, dateStr, isToday);
                            }).toList(),
                          ),
                        ],
                      );
                    },
                    childCount: sortedDates.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEpisodeCard(BuildContext context, CalendarEpisode ep, DateTime now, String airDate, bool isToday) {
    // Calculate difference for badge
    String diffText = '';
    try {
      final parsed = DateTime.parse(airDate);
      final diff = parsed.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diff == 0) {
        diffText = 'TODAY';
      } else if (diff < 0) {
        diffText = '${diff.abs()} D AGO';
      } else {
        diffText = '$diff DAYS';
      }
    } catch (_) {}

    final titleText = ep.type == 'movie' 
        ? ep.showTitle 
        : '${ep.showTitle}\nS${ep.seasonNumber}E${ep.episodeNumber}';
    final subtitle = ep.type == 'movie' ? 'Movie Release' : ep.title;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 32 - 24) / 3; // 3 columns
    final itemHeight = itemWidth * 1.5;

    return SizedBox(
      width: itemWidth,
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(context, '/show', arguments: {'id': ep.tmdbId, 'type': ep.type});
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: ep.posterUrl != null 
                        ? Image.network(
                            ep.posterUrl!, 
                            width: itemWidth, 
                            height: itemHeight, 
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildPlaceholder(ep.showTitle),
                          )
                        : _buildPlaceholder(ep.showTitle),
                  ),
                ),
                // Days Badge
                if (diffText.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primary, width: 1),
                      ),
                      child: Text(
                        diffText,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                // Google Calendar Button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _addToGoogleCalendar(ep, titleText, subtitle),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_rounded, color: Colors.black, size: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titleText,
              style: const TextStyle(
                color: AppTheme.textMain,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToGoogleCalendar(CalendarEpisode ep, String title, String subtitle) async {
    try {
      final encTitle = Uri.encodeComponent(title.replaceAll('\n', ' - '));
      final encDetails = Uri.encodeComponent(subtitle);
      
      final d = DateTime.parse(ep.airDate);
      final startStr = '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
      final dNext = d.add(const Duration(days: 1));
      final endStr = '${dNext.year}${dNext.month.toString().padLeft(2, '0')}${dNext.day.toString().padLeft(2, '0')}';
      
      final url = 'https://www.google.com/calendar/render?action=TEMPLATE&text=$encTitle&dates=$startStr/$endStr&details=$encDetails';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch calendar URL: $e');
    }
  }

  Widget _buildPlaceholder(String title) {
    return Container(
      color: AppTheme.surfaceLight,
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_rounded, color: Colors.white.withValues(alpha: 0.1), size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
