import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';
import '../theme/app_theme.dart';
import 'show_details_screen.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _topFilter = 'all'; // all, tv, movie
  String _tvFilter = 'watching'; // watching, uptodate, finished, stopped, notstarted
  String _movieFilter = 'watchlist'; // watchlist, seen
  String _sort = 'lastWatchedDesc';
  String _genre = 'all';
  String _search = '';
  
  String _formatDate(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      final dd = date.day.toString().padLeft(2, '0');
      final mm = date.month.toString().padLeft(2, '0');
      return '$dd/$mm/${date.year}';
    } catch (e) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);
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
                      'Library',
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
            
            libraryAsync.when(
              data: (library) {
                final filtered = _filterAndSort(library);
                final genres = _extractGenres(library);

                return Expanded(
                  child: Column(
                    children: [
                      // Search and Filters Section
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
                        ),
                        child: Column(
                          children: [
                            // Search Bar
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _search = val.toLowerCase()),
                                style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Search your library...',
                                  hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7)),
                                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),

                            // Top Filters & Sort
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildChip('All', 'all', _topFilter, (v) => setState(() => _topFilter = v)),
                                  _buildChip('TV Shows', 'tv', _topFilter, (v) => setState(() => _topFilter = v)),
                                  _buildChip('Movies', 'movie', _topFilter, (v) => setState(() => _topFilter = v)),
                                  
                                  const SizedBox(width: 8),
                                  
                                  _buildDropdown(
                                    value: _sort,
                                    items: const [
                                      DropdownMenuItem(value: 'lastWatchedDesc', child: Text('Last Watched')),
                                      DropdownMenuItem(value: 'lastWatchedAsc', child: Text('Oldest Watched')),
                                      DropdownMenuItem(value: 'titleAsc', child: Text('Title (A-Z)')),
                                      DropdownMenuItem(value: 'addedDesc', child: Text('Recently Added')),
                                      DropdownMenuItem(value: 'episodesDesc', child: Text('Most Watched')),
                                      DropdownMenuItem(value: 'notWatchedAsc', child: Text('Most Unwatched Episodes')),
                                      DropdownMenuItem(value: 'progressAsc', child: Text('Progress (0% -> 100%)')),
                                      DropdownMenuItem(value: 'progressDesc', child: Text('Progress (100% -> 0%)')),
                                      DropdownMenuItem(value: 'missingData', child: Text('Missing Data First (0/0)')),
                                    ],
                                    onChanged: (v) => setState(() => _sort = v!),
                                  ),
                                  
                                  const SizedBox(width: 8),
                                  
                                  _buildDropdown(
                                    value: _genre,
                                    items: [
                                      const DropdownMenuItem(value: 'all', child: Text('All Genres')),
                                      ...genres.map((g) => DropdownMenuItem(value: g, child: Text(g))),
                                    ],
                                    onChanged: (v) => setState(() => _genre = v!),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Secondary Filters
                            if (_topFilter == 'tv' || _topFilter == 'movie')
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: _topFilter == 'tv' 
                                      ? [
                                          _buildChip('Watching', 'watching', _tvFilter, (v) => setState(() => _tvFilter = v), true),
                                          _buildChip('Up to Date', 'uptodate', _tvFilter, (v) => setState(() => _tvFilter = v), true),
                                          _buildChip('Not Started', 'notstarted', _tvFilter, (v) => setState(() => _tvFilter = v), true),
                                          _buildChip('Finished', 'finished', _tvFilter, (v) => setState(() => _tvFilter = v), true),
                                          _buildChip('Stopped', 'stopped', _tvFilter, (v) => setState(() => _tvFilter = v), true),
                                        ]
                                      : [
                                          _buildChip('Watchlist', 'watchlist', _movieFilter, (v) => setState(() => _movieFilter = v), true),
                                          _buildChip('Seen', 'seen', _movieFilter, (v) => setState(() => _movieFilter = v), true),
                                        ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Grid
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.video_library_rounded, size: 64, color: AppTheme.surfaceLight),
                                    const SizedBox(height: 16),
                                    const Text('No items match your filters.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                color: AppTheme.primary,
                                onRefresh: () async {
                                  ref.invalidate(libraryProvider);
                                  await ref.read(libraryProvider.future);
                                },
                                child: GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 0.62,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 16,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildLibraryCard(filtered[index]);
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => Expanded(child: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
              error: (err, stack) => Expanded(child: Center(child: Text('Error: $err'))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value, String groupValue, Function(String) onSelected, [bool isSecondary = false]) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isSecondary ? AppTheme.surfaceLight : AppTheme.primary)
              : (isSecondary ? Colors.transparent : AppTheme.surfaceLight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected && isSecondary 
                ? AppTheme.primary 
                : (isSecondary ? Colors.transparent : Colors.white.withValues(alpha: 0.05)),
          ),
          boxShadow: isSelected && !isSecondary ? [
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? (isSecondary ? AppTheme.primary : Colors.black)
                : AppTheme.textMuted,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    final hasValue = items.any((item) => item.value == value);
    final safeValue = hasValue ? value : items.first.value;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: AppTheme.surfaceLight,
          style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 18),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildLibraryCard(LibraryShow libItem) {
    final show = libItem.show;
    final isMovie = show.type == 'movie';
    final unwatched = libItem.airedEpisodes - libItem.watchedEpisodes;
    
    String? badgeText;
    Color? badgeColor;

    if (isMovie) {
      if (libItem.watchedEpisodes == 0) {
        badgeText = 'Watchlist';
        badgeColor = const Color(0xFFff9f0a); // Yellow/Orange
      } else {
        badgeText = 'Seen';
        badgeColor = const Color(0xFF34c759); // Green
      }
    } else {
      if (show.isStopped == 1) {
        badgeText = 'Stopped';
        badgeColor = const Color(0xFFff3b30); // Red
      } else if (libItem.watchedEpisodes == 0) {
        badgeText = 'Not Started';
        badgeColor = const Color(0xFF8e8e93); // Grey
      } else if (libItem.watchedEpisodes >= libItem.airedEpisodes && libItem.airedEpisodes > 0) {
        if (show.status == 'Ended' || show.status == 'Canceled') {
          badgeText = 'Finished';
          badgeColor = const Color(0xFF34c759); // Green
        } else {
          badgeText = 'Up to Date';
          badgeColor = const Color(0xFF0a84ff); // Blue
        }
      } else {
        badgeText = 'Watching';
        badgeColor = const Color(0xFFFFD600); // Yellow
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
          tmdbId: show.apiId,
          type: show.type,
        )));
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: badgeColor != null ? badgeColor.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.4),
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
                  child: show.posterUrl != null
                    ? CachedNetworkImage(
                          imageUrl: show.posterUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => _buildPlaceholder(show.title),
                        )
                    : _buildPlaceholder(show.title),
              ),
            ),
            
            // Subtle Border matching status color
            if (badgeColor != null)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                ),
              ),
            
            // Top Right: Status Badge
            if (badgeText != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                    ],
                  ),
                  child: Text(
                    badgeText.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Top Left: Unwatched Badge
            if (!isMovie && unwatched > 0 && show.isStopped == 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4)],
                  ),
                  child: Text(
                    '+$unwatched',
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            // Bottom: Title & Progress Overlay
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
                  children: [
                    Text(
                      show.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (libItem.watchedEpisodes > 0 && libItem.lastWatched != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        isMovie ? 'Seen: ${_formatDate(libItem.lastWatched!)}' : 'Last watched: ${_formatDate(libItem.lastWatched!)}',
                        style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (!isMovie) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (libItem.airedEpisodes > 0) ...[
                            Expanded(
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (libItem.watchedEpisodes / libItem.airedEpisodes).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: badgeColor ?? AppTheme.primary,
                                      borderRadius: BorderRadius.circular(1.5),
                                      boxShadow: [
                                        if (badgeColor != null)
                                          BoxShadow(color: badgeColor.withValues(alpha: 0.5), blurRadius: 4)
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${libItem.watchedEpisodes}/${libItem.airedEpisodes}',
                              style: TextStyle(
                                fontSize: 8,
                                color: badgeColor ?? AppTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                show.status ?? 'TBA',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: AppTheme.textMuted,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Stopped overlay
            if (show.isStopped == 1)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              )
          ],
        ),
      ),
    );
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
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  List<String> _extractGenres(List<LibraryShow> library) {
    final Set<String> genres = {};
    for (var l in library) {
      if (l.show.genre.isNotEmpty) {
        genres.addAll(l.show.genre.split(',').map((e) => e.trim()));
      }
    }
    final sorted = genres.toList()..sort();
    return sorted;
  }

  List<LibraryShow> _filterAndSort(List<LibraryShow> library) {
    List<LibraryShow> filtered = List.from(library);

    // 1. Search
    if (_search.isNotEmpty) {
      filtered = filtered.where((l) => l.show.title.toLowerCase().contains(_search)).toList();
    }

    // 2. Genre
    if (_genre != 'all') {
      filtered = filtered.where((l) => l.show.genre.contains(_genre)).toList();
    }

    // 3. Top Filter
    if (_topFilter == 'tv') {
      filtered = filtered.where((l) => l.show.type == 'tv').toList();
      // TV Sub-filter
      if (_tvFilter == 'watching') {
        filtered = filtered.where((l) => l.show.isStopped == 0 && l.watchedEpisodes < l.airedEpisodes && l.watchedEpisodes > 0).toList();
      } else if (_tvFilter == 'uptodate') {
        filtered = filtered.where((l) => l.show.isStopped == 0 && l.watchedEpisodes >= l.airedEpisodes && l.watchedEpisodes > 0 && l.show.status != 'Ended' && l.show.status != 'Canceled').toList();
      } else if (_tvFilter == 'finished') {
        filtered = filtered.where((l) => l.show.isStopped == 0 && l.watchedEpisodes >= l.airedEpisodes && l.watchedEpisodes > 0 && (l.show.status == 'Ended' || l.show.status == 'Canceled')).toList();
      } else if (_tvFilter == 'stopped') {
        filtered = filtered.where((l) => l.show.isStopped == 1).toList();
      } else if (_tvFilter == 'notstarted') {
        filtered = filtered.where((l) => l.watchedEpisodes == 0 && l.show.isStopped == 0).toList();
      }
    } else if (_topFilter == 'movie') {
      filtered = filtered.where((l) => l.show.type == 'movie').toList();
      // Movie Sub-filter
      if (_movieFilter == 'watchlist') {
        filtered = filtered.where((l) => l.watchedEpisodes == 0).toList();
      } else if (_movieFilter == 'seen') {
        filtered = filtered.where((l) => l.watchedEpisodes > 0).toList();
      }
    }

    // 4. Sort
    filtered.sort((a, b) {
      switch (_sort) {
        case 'titleAsc':
          return a.show.title.compareTo(b.show.title);
        case 'addedDesc':
          return b.show.id.compareTo(a.show.id); // higher ID = newer
        case 'episodesDesc':
          return b.watchedEpisodes.compareTo(a.watchedEpisodes);
        case 'notWatchedAsc':
          final aUnseen = (a.airedEpisodes - a.watchedEpisodes).clamp(0, 99999);
          final bUnseen = (b.airedEpisodes - b.watchedEpisodes).clamp(0, 99999);
          if (aUnseen == bUnseen) return b.watchedEpisodes.compareTo(a.watchedEpisodes);
          return bUnseen.compareTo(aUnseen);
        case 'progressAsc':
        case 'progressDesc':
          final pctA = a.airedEpisodes > 0 ? a.watchedEpisodes / a.airedEpisodes : (a.watchedEpisodes > 0 ? 1.0 : 0.0);
          final pctB = b.airedEpisodes > 0 ? b.watchedEpisodes / b.airedEpisodes : (b.watchedEpisodes > 0 ? 1.0 : 0.0);
          if (pctA == pctB) return b.watchedEpisodes.compareTo(a.watchedEpisodes);
          return _sort == 'progressAsc' ? pctA.compareTo(pctB) : pctB.compareTo(pctA);
        case 'missingData':
          final aMissing = a.airedEpisodes == 0 ? 1 : 0;
          final bMissing = b.airedEpisodes == 0 ? 1 : 0;
          if (aMissing == bMissing) return a.show.title.compareTo(b.show.title);
          return bMissing.compareTo(aMissing);
        case 'lastWatchedAsc':
        case 'lastWatchedDesc':
        default:
          final dateA = a.lastWatched != null ? DateTime.parse(a.lastWatched!) : DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.lastWatched != null ? DateTime.parse(b.lastWatched!) : DateTime.fromMillisecondsSinceEpoch(0);
          return _sort == 'lastWatchedAsc' ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
      }
    });

    return filtered;
  }
}
