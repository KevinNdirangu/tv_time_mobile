import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../services/tmdb_service.dart';
import '../services/supabase_service.dart';
import 'show_details_screen.dart';

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
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    final results = await TmdbService.getTrending(type: _currentType, genre: _currentGenre);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        _loadTrending();
        return;
      }
      setState(() => _isLoading = true);
      final results = await TmdbService.search(query);
      if (!mounted) return;
      setState(() {
        _results = results.where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie').toList();
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);
    final localApiIds = libraryAsync.maybeWhen(
      data: (data) => data.map((s) => s.show.apiId).toSet(),
      orElse: () => <int>{},
    );

    // Filter results to remove items already in the library
    final filteredResults = _results.where((item) => !localApiIds.contains(item['id'])).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover', style: TextStyle(fontWeight: FontWeight.bold)),
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
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primary),
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
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filteredResults.isEmpty
                      ? const Center(child: Text('No results found (or all are in your library).', style: TextStyle(color: AppTheme.textMuted)))
                      : GridView.builder(
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
