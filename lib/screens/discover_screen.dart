import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/tmdb_service.dart';
import '../services/supabase_service.dart';
import 'show_details_screen.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();

  String _currentType = 'all'; // all, movie, tv, anime
  String _currentGenre = 'all';

  final List<Map<String, String>> _genres = [
    {'id': 'all', 'name': 'All Genres'},
    {'id': 'action', 'name': 'Action'},
    {'id': 'animation', 'name': 'Animation'},
    {'id': 'comedy', 'name': 'Comedy'},
    {'id': 'crime', 'name': 'Crime'},
    {'id': 'documentary', 'name': 'Documentary'},
    {'id': 'drama', 'name': 'Drama'},
    {'id': 'family', 'name': 'Family'},
    {'id': 'fantasy', 'name': 'Fantasy'},
    {'id': 'horror', 'name': 'Horror'},
    {'id': 'mystery', 'name': 'Mystery'},
    {'id': 'romance', 'name': 'Romance'},
    {'id': 'thriller', 'name': 'Thriller'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadMore() async {
    try {
      setState(() => _isLoadingMore = true);
      
      final libraryAsync = ref.read(libraryProvider);
      final localApiIds = libraryAsync.maybeWhen(
        data: (data) => data.map((s) => s.show.apiId).toSet(),
        orElse: () => <int>{},
      );

      int validCount = _results.where((item) => !localApiIds.contains(item['id'])).length;
      final targetCount = validCount + 15;
      
      while (validCount < targetCount && _page <= 20) {
        _page++;
        List<dynamic> newResults = [];
        if (_searchController.text.trim().isEmpty) {
          newResults = await TmdbService.getTrending(type: _currentType, genre: _currentGenre, page: _page);
        } else {
          newResults = await TmdbService.search(_searchController.text.trim(), page: _page);
          newResults = newResults.where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie').toList();
        }
        if (newResults.isEmpty) break;
        _results.addAll(newResults);
        validCount = _results.where((item) => !localApiIds.contains(item['id'])).length;
      }
    } catch (e) {
      debugPrint('Error loading more: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadTrending() async {
    try {
      setState(() {
        _isLoading = true;
        _page = 1;
        _results.clear();
      });

      final libraryAsync = ref.read(libraryProvider);
      final localApiIds = libraryAsync.maybeWhen(
        data: (data) => data.map((s) => s.show.apiId).toSet(),
        orElse: () => <int>{},
      );

      int validCount = 0;
      while (validCount < 15 && _page <= 10) {
        final results = await TmdbService.getTrending(type: _currentType, genre: _currentGenre, page: _page);
        if (results.isEmpty) break;
        _results.addAll(results);
        validCount = _results.where((item) => !localApiIds.contains(item['id'])).length;
        if (validCount < 15) _page++;
      }
    } catch (e) {
      debugPrint('Error loading trending: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        if (query.trim().isEmpty) {
          _loadTrending();
          return;
        }
        setState(() {
          _isLoading = true;
          _page = 1;
          _results.clear();
        });
        
        final libraryAsync = ref.read(libraryProvider);
        final localApiIds = libraryAsync.maybeWhen(
          data: (data) => data.map((s) => s.show.apiId).toSet(),
          orElse: () => <int>{},
        );

        int validCount = 0;
        while (validCount < 15 && _page <= 10) {
          final results = await TmdbService.search(query, page: _page);
          if (results.isEmpty) break;
          final filteredNew = results.where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie').toList();
          _results.addAll(filteredNew);
          validCount = _results.where((item) => !localApiIds.contains(item['id'])).length;
          if (validCount < 15) _page++;
        }
      } catch (e) {
        debugPrint('Error searching: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final showsAsync = ref.watch(showsProvider);
    final localApiIds = showsAsync.asData?.value.map((s) => s.apiId).toSet() ?? {};
    final filteredResults = _results.where((item) => !localApiIds.contains(item['id'])).toList();

    return Scaffold(
      drawer: const GlobalNavigationDrawer(),
      endDrawer: const NotificationsDrawer(),
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppTheme.textMain),
              decoration: InputDecoration(
                hintText: 'Search for movies, TV shows...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Sub-nav for filtering
            if (_searchController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildTypeChip('All', 'all'),
                            _buildTypeChip('Movies', 'movie'),
                            _buildTypeChip('TV Shows', 'tv'),
                            _buildTypeChip('Anime', 'anime'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentGenre,
                          dropdownColor: AppTheme.surfaceLight,
                          style: const TextStyle(color: AppTheme.textMain, fontSize: 12),
                          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
                          items: _genres.map((g) => DropdownMenuItem<String>(
                            value: g['id'],
                            child: Text(g['name']!),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _currentGenre = val);
                              _loadTrending();
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Results Section
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filteredResults.isEmpty
                      ? const Center(child: Text('No results found (or all are in your library).', style: TextStyle(color: AppTheme.textMuted)))
                      : GridView.builder(
                          controller: _scrollController,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filteredResults.length,
                          itemBuilder: (context, index) {
                            final item = filteredResults[index];
                            final title = item['title'] ?? item['name'] ?? 'Unknown';
                            final posterPath = item['poster_path'];
                            
                            // Discover endpoint sometimes omits media_type for specific endpoints, so fallback based on current type or general guess
                            final type = item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv');

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                                  tmdbId: item['id'],
                                  type: type,
                                )));
                              },
                              child: Stack(
                                children: [
                                  // Background Poster
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: posterPath != null
                                          ? Image.network(
                                              'https://image.tmdb.org/t/p/w200$posterPath', 
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildPlaceholder(title),
                                            )
                                          : _buildPlaceholder(title),
                                    ),
                                  ),
                                  
                                  // Top Left: Tag (MOVIE / TV)
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: type == 'movie' ? AppTheme.primary : Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        type.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Top Right: + Add Button
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        // Quick add action (for now just open details modal)
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                                          tmdbId: item['id'],
                                          type: type,
                                        )));
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white24),
                                        ),
                                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ),

                                  // Bottom: Title Overlay
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.9),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, String value) {
    final isActive = _currentType == value;
    return GestureDetector(
      onTap: () {
        setState(() => _currentType = value);
        _loadTrending();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? AppTheme.primary : AppTheme.surfaceLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AppTheme.primary : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String title) {
    return Container(
      color: AppTheme.surfaceLight,
      padding: const EdgeInsets.all(8.0),
      alignment: Alignment.center,
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
        textAlign: TextAlign.center,
      ),
    );
  }
}
