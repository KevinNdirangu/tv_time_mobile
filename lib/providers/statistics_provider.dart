import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';

class AdvancedStats {
  final int bingeCount;
  final int maxStreak;
  final String topWeekday;
  final String peakTimeSlot;
  final bool isMarathoner;
  final bool isSerialBinger;
  final bool isNightOwl;
  final bool isEarlyBird;

  AdvancedStats({
    required this.bingeCount,
    required this.maxStreak,
    required this.topWeekday,
    required this.peakTimeSlot,
    required this.isMarathoner,
    required this.isSerialBinger,
    required this.isNightOwl,
    required this.isEarlyBird,
  });
}

final advancedStatsProvider = FutureProvider<AdvancedStats>((ref) async {
  final watchHistory = await ref.watch(watchHistoryProvider.future);
  final allEpisodes = await ref.watch(allEpisodesProvider.future);

  return await compute(_computeAdvancedStats, {
    'watchHistory': watchHistory,
    'allEpisodes': allEpisodes,
  });
});

AdvancedStats _computeAdvancedStats(Map<String, dynamic> data) {
  final List<Map<String, dynamic>> watchHistory = data['watchHistory'];
  final List<Map<String, dynamic>> allEpisodes = data['allEpisodes'];

  // Map episode_id -> show_id
  final Map<int, int> episodeToShow = {};
  for (var ep in allEpisodes) {
    episodeToShow[ep['id'] as int] = ep['show_id'] as int;
  }

  int bingeCount = 0;
  int maxStreak = 0;
  
  Map<int, int> weekdayCounts = {};
  Map<String, int> timeSlotCounts = {};

  final timeSlots = [
    {'name': 'Night Owl', 'start': 0, 'end': 5},
    {'name': 'Early Bird', 'start': 6, 'end': 11},
    {'name': 'Afternoon Lounger', 'start': 12, 'end': 17},
    {'name': 'Prime Time Watcher', 'start': 18, 'end': 23},
  ];

  // Map date (YYYY-MM-DD) -> Set of shows watched that day
  final Map<String, Map<int, int>> dailyShowWatchCounts = {};
  final Set<String> activeDays = {};

  for (var record in watchHistory) {
    final epId = record['episode_id'] as int;
    final watchedAtStr = record['watched_at'] as String?;
    if (watchedAtStr == null) continue;

    final date = DateTime.tryParse(watchedAtStr);
    if (date == null) continue;

    final localDate = date.toLocal();
    final dayStr = DateFormat('yyyy-MM-dd').format(localDate);
    activeDays.add(dayStr);

    final showId = episodeToShow[epId];
    if (showId != null) {
      if (!dailyShowWatchCounts.containsKey(dayStr)) {
        dailyShowWatchCounts[dayStr] = {};
      }
      dailyShowWatchCounts[dayStr]![showId] = (dailyShowWatchCounts[dayStr]![showId] ?? 0) + 1;
    }

    weekdayCounts[localDate.weekday] = (weekdayCounts[localDate.weekday] ?? 0) + 1;

    for (var slot in timeSlots) {
      if (localDate.hour >= (slot['start'] as int) && localDate.hour <= (slot['end'] as int)) {
        final slotName = slot['name'] as String;
        timeSlotCounts[slotName] = (timeSlotCounts[slotName] ?? 0) + 1;
        break;
      }
    }
  }

  // Calculate Binge Count
  for (var showsWatched in dailyShowWatchCounts.values) {
    for (var count in showsWatched.values) {
      if (count >= 4) {
        bingeCount++;
      }
    }
  }

  // Calculate Max Streak
  final sortedDays = activeDays.toList()..sort();
  int currentStreak = 0;
  for (int i = 0; i < sortedDays.length; i++) {
    if (i == 0) {
      currentStreak = 1;
      maxStreak = 1;
      continue;
    }
    final prev = DateTime.parse(sortedDays[i - 1]);
    final curr = DateTime.parse(sortedDays[i]);
    if (curr.difference(prev).inDays == 1) {
      currentStreak++;
      if (currentStreak > maxStreak) {
        maxStreak = currentStreak;
      }
    } else {
      currentStreak = 1;
    }
  }

  // Peak Time and Day
  String topWeekday = 'Unknown';
  if (weekdayCounts.isNotEmpty) {
    final top = weekdayCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    switch (top.key) {
      case 1: topWeekday = 'Monday'; break;
      case 2: topWeekday = 'Tuesday'; break;
      case 3: topWeekday = 'Wednesday'; break;
      case 4: topWeekday = 'Thursday'; break;
      case 5: topWeekday = 'Friday'; break;
      case 6: topWeekday = 'Saturday'; break;
      case 7: topWeekday = 'Sunday'; break;
    }
  }

  String peakTimeSlot = 'Unknown';
  if (timeSlotCounts.isNotEmpty) {
    final topSlot = timeSlotCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    peakTimeSlot = topSlot.key;
  }

  return AdvancedStats(
    bingeCount: bingeCount,
    maxStreak: maxStreak,
    topWeekday: topWeekday,
    peakTimeSlot: peakTimeSlot,
    isMarathoner: maxStreak >= 14,
    isSerialBinger: bingeCount >= 10,
    isNightOwl: peakTimeSlot == 'Night Owl',
    isEarlyBird: peakTimeSlot == 'Early Bird',
  );
}
