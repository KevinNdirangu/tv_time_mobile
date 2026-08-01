import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import 'show_details_screen.dart';
import '../providers/notifications_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _dateKeys = {};

  void _scrollToToday() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Find the exact today key, or the first key after today
    String? targetKey;
    if (_dateKeys.containsKey(todayStr)) {
      targetKey = todayStr;
    } else {
      final sortedKeys = _dateKeys.keys.toList()..sort();
      for (var k in sortedKeys) {
        if (k.compareTo(todayStr) >= 0) {
          targetKey = k;
          break;
        }
      }
    }

    if (targetKey != null && _dateKeys.containsKey(targetKey)) {
      final context = _dateKeys[targetKey]!.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1, // Slight offset from top
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarProvider);
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppTheme.textMain, size: 28),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Calendar',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textMain,
                        letterSpacing: -0.5,
                      ),
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
            
            // Calendar Body
            Expanded(
              child: calendarAsync.when(
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
                  final today = DateTime.now();
                  final todayStr = DateFormat('yyyy-MM-dd').format(today);

                  final pastDates = sortedDates.where((d) => d.compareTo(todayStr) < 0).toList();
                  final futureDates = sortedDates.where((d) => d.compareTo(todayStr) >= 0).toList();

                  return Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(calendarProvider);
                          await ref.read(calendarProvider.future);
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          controller: _scrollController,
                          slivers: [
                            if (pastDates.isNotEmpty)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceLight,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                        ],
                                      ),
                                      child: ExpansionTile(
                                        iconColor: AppTheme.textMuted,
                                        collapsedIconColor: AppTheme.textMuted,
                                        title: Text(
                                          'Show Past 30 Days (${pastDates.fold<int>(0, (sum, d) => sum + grouped[d]!.length)} Items)',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted, fontSize: 15),
                                        ),
                                        children: pastDates.map((dateStr) {
                                          final eps = grouped[dateStr]!;
                                          final date = DateTime.parse(dateStr);
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                                child: Text(
                                                  DateFormat('EEEE, MMMM d').format(date),
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                                                ),
                                              ),
                                              GridView.builder(
                                                shrinkWrap: true,
                                                physics: const NeverScrollableScrollPhysics(),
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  childAspectRatio: 0.65,
                                                  crossAxisSpacing: 12,
                                                  mainAxisSpacing: 16,
                                                ),
                                                itemCount: eps.length,
                                                itemBuilder: (context, index) => _buildEpisodeCard(context, eps[index], date, false),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            
                            if (futureDates.isEmpty)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: Text('All caught up! No upcoming media scheduled.', style: TextStyle(color: AppTheme.textMuted))),
                                ),
                              ),
                            
                            for (var dateStr in futureDates)
                              ..._buildDateSection(dateStr, grouped[dateStr]!, todayStr),
                              
                            // Bottom padding for scroll
                            const SliverToBoxAdapter(child: SizedBox(height: 80)),
                          ],
                        ),
                      ),
                      
                      // Floating TODAY Button
                      Positioned(
                        bottom: 24,
                        right: 24,
                        child: FloatingActionButton.extended(
                          onPressed: _scrollToToday,
                          backgroundColor: AppTheme.primary,
                          icon: const Icon(Icons.calendar_today_rounded, color: Colors.black),
                          label: const Text(
                            'TODAY',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                error: (err, _) => Center(child: Text('Error loading calendar: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDateSection(String dateStr, List<CalendarEpisode> eps, String todayStr) {
    final date = DateTime.parse(dateStr);
    final isToday = dateStr == todayStr;
    
    // Register GlobalKey for scrolling
    if (!_dateKeys.containsKey(dateStr)) {
      _dateKeys[dateStr] = GlobalKey();
    }

    return [
      SliverToBoxAdapter(
        key: _dateKeys[dateStr],
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isToday ? 'TODAY' : DateFormat('EEEE, MMMM d').format(date).toUpperCase(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isToday ? AppTheme.primary : AppTheme.textMain,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildEpisodeCard(context, eps[index], date, isToday),
            childCount: eps.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildEpisodeCard(BuildContext context, CalendarEpisode ep, DateTime epDate, bool isToday) {
    final diff = epDate.difference(DateTime.now()).inDays;
    // Difference is based on midnight-to-midnight roughly
    final diffText = isToday ? 'TODAY' : (diff < 0 ? '${diff.abs()} D AGO' : '$diff DAYS');
    
    final titleText = ep.showTitle;
    final subtitleText = 'S${ep.seasonNumber}E${ep.episodeNumber}';

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
          tmdbId: ep.tmdbId,
          type: 'tv',
        )));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Poster
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ep.posterUrl != null
                    ? Image.network(
                        ep.posterUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderImage(),
                      )
                    : _placeholderImage(),
              ),
            ),

            // Top Left Tag (DAYS AGO / DAYS)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  border: Border.all(color: AppTheme.primary, width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diffText,
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Top Right Tag (GCal)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () async {
                  final d = DateTime.parse(ep.airDate);
                  final startStr = DateFormat('yyyyMMdd').format(d);
                  final nextD = d.add(const Duration(days: 1));
                  final endStr = DateFormat('yyyyMMdd').format(nextD);
                  
                  final encTitle = Uri.encodeComponent('$titleText $subtitleText');
                  final encDetails = Uri.encodeComponent(ep.title);
                  
                  final url = Uri.parse('https://www.google.com/calendar/render?action=TEMPLATE&text=$encTitle&dates=$startStr/$endStr&details=$encDetails');
                  
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.event_rounded, size: 14, color: Colors.black),
                ),
              ),
            ),

            // Bottom Title Overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
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
      color: AppTheme.surfaceLight,
      child: const Center(child: Icon(Icons.tv_rounded, color: AppTheme.textMuted, size: 32)),
    );
  }
}
