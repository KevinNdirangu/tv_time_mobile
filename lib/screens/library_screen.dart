import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import '../models/library_show.dart';
import '../theme/app_theme.dart';
import 'show_details_screen.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  String _topFilter = 'all'; // all, tv, movie
  String _tvFilter = 'watching'; // watching, uptodate, finished, stopped
  String _movieFilter = 'watchlist'; // watchlist, seen
  String _sort = 'lastWatchedDesc';
  String _genre = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: libraryAsync.when(
        data: (library) {
          final filtered = _filterAndSort(library);
          final genres = _extractGenres(library);

          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  onChanged: (val) => setState(() => _search = val.toLowerCase()),
                  style: const TextStyle(color: AppTheme.textMain),
                  decoration: InputDecoration(
                    hintText: 'Search library...',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // Top Filters & Sort
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    _buildChip('All', 'all', _topFilter, (v) => setState(() => _topFilter = v)),
                    const SizedBox(width: 8),
                    _buildChip('TV Shows', 'tv', _topFilter, (v) => setState(() => _topFilter = v)),
                    const SizedBox(width: 8),
                    _buildChip('Movies', 'movie', _topFilter, (v) => setState(() => _topFilter = v)),
                    const SizedBox(width: 16),
                    _buildDropdown(
                      value: _sort,
                      items: const [
                        DropdownMenuItem(value: 'lastWatchedDesc', child: Text('Last Watched')),
                        DropdownMenuItem(value: 'titleAsc', child: Text('Title (A-Z)')),
                        DropdownMenuItem(value: 'addedDesc', child: Text('Recently Added')),
                        DropdownMenuItem(value: 'episodesDesc', child: Text('Most Watched')),
                        DropdownMenuItem(value: 'notWatchedAsc', child: Text('Not Watched First')),
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
              if (_topFilter == 'tv')
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      _buildChip('Watching', 'watching', _tvFilter, (v) => setState(() => _tvFilter = v)),
                      const SizedBox(width: 8),
                      _buildChip('Up to Date', 'uptodate', _tvFilter, (v) => setState(() => _tvFilter = v)),
                      const SizedBox(width: 8),
                      _buildChip('Finished', 'finished', _tvFilter, (v) => setState(() => _tvFilter = v)),
                      const SizedBox(width: 8),
                      _buildChip('Stopped', 'stopped', _tvFilter, (v) => setState(() => _tvFilter = v)),
                    ],
                  ),
                ),
              if (_topFilter == 'movie')
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      _buildChip('Watchlist', 'watchlist', _movieFilter, (v) => setState(() => _movieFilter = v)),
                      const SizedBox(width: 8),
                      _buildChip('Seen', 'seen', _movieFilter, (v) => setState(() => _movieFilter = v)),
                    ],
                  ),
                ),

              // Grid
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No items match your filters.', style: TextStyle(color: AppTheme.textMuted)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.65,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildLibraryCard(filtered[index]);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildChip(String label, String value, String groupValue, Function(String) onSelected) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : AppTheme.textMain,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({required String value, required List<DropdownMenuItem<String>> items, required Function(String?) onChanged}) {
    // Ensure the value exists in items to prevent assertions
    final hasValue = items.any((item) => item.value == value);
    final safeValue = hasValue ? value : items.first.value;

    return Container(
      height: 35,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          dropdownColor: AppTheme.surfaceLight,
          style: const TextStyle(color: AppTheme.textMain, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
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
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
          tmdbId: show.apiId,
          type: show.type,
        )));
      },
      child: Stack(
        children: [
          // Poster
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: show.posterUrl != null
                  ? Image.network(
                      show.posterUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          
          // Unwatched Badge
          if (!isMovie && unwatched > 0 && show.isStopped == 0)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                ),
                child: Text(
                  '+$unwatched',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
          // Progress Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 4,
              decoration: const BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (libItem.airedEpisodes > 0) ? (libItem.watchedEpisodes / libItem.airedEpisodes).clamp(0.0, 1.0) : 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: (libItem.watchedEpisodes >= libItem.airedEpisodes && libItem.airedEpisodes > 0) ? AppTheme.primary : Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
          
          // Stopped overlay
          if (show.isStopped == 1)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.block, color: Colors.white54, size: 30),
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceLight,
      child: const Center(
        child: Icon(Icons.movie, color: AppTheme.textMuted, size: 40),
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
        filtered = filtered.where((l) => l.show.isStopped == 0 && l.watchedEpisodes >= l.airedEpisodes && l.show.status != 'Ended').toList();
      } else if (_tvFilter == 'finished') {
        filtered = filtered.where((l) => l.show.isStopped == 0 && l.watchedEpisodes >= l.airedEpisodes && l.show.status == 'Ended').toList();
      } else if (_tvFilter == 'stopped') {
        filtered = filtered.where((l) => l.show.isStopped == 1).toList();
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
          final aUnseen = a.airedEpisodes - a.watchedEpisodes;
          final bUnseen = b.airedEpisodes - b.watchedEpisodes;
          // Put ones with most unseen at top
          return bUnseen.compareTo(aUnseen);
        case 'lastWatchedDesc':
        default:
          final dateA = a.lastWatched != null ? DateTime.parse(a.lastWatched!) : DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.lastWatched != null ? DateTime.parse(b.lastWatched!) : DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
      }
    });

    return filtered;
  }
}
