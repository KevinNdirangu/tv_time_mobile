import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../services/tmdb_service.dart';
import '../services/supabase_service.dart';
import 'show_details_screen.dart';
import 'notifications_drawer.dart';
import 'navigation_drawer.dart';
import '../providers/notifications_provider.dart';
import '../services/ai_service.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _aiSearchController = TextEditingController();
  List<String> _aiExistingTitles = [];
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
        if (_aiSearchController.text.trim().isNotEmpty) {
          final titles = await AiService.smartSearch(_aiSearchController.text.trim(), existingTitles: _aiExistingTitles);
          if (titles.isEmpty) break;
          _aiExistingTitles.addAll(titles);
          for (final t in titles) {
            final res = await TmdbService.search(t, page: 1);
            if (res.isNotEmpty) newResults.add(res.first);
          }
        } else if (_searchController.text.trim().isEmpty) {
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
          _aiSearchController.clear();
          _aiExistingTitles.clear();
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

  Future<void> _onAiSearchSubmit(String query) async {
    if (query.trim().isEmpty) return;
    
    // Check API key first
    final hasKey = await AiService.hasKey();
    if (!hasKey && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your Groq API key in Settings first.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _page = 1;
      _results.clear();
      _aiExistingTitles.clear();
      _searchController.clear(); // clear standard search
    });

    try {
      final titles = await AiService.smartSearch(query);
      if (titles.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not find any matches.')),
        );
        setState(() => _isLoading = false);
        return;
      }

      List<dynamic> aiResults = [];
      for (final title in titles) {
        final res = await TmdbService.search(title, page: 1);
        if (res.isNotEmpty) {
          aiResults.add(res.first);
        }
      }

      if (mounted) {
        setState(() {
          _aiExistingTitles.addAll(titles);
          _results = aiResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('AI Search error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
    final libraryAsync = ref.watch(libraryProvider);
    final localApiIds = libraryAsync.asData?.value.map((s) => s.show.apiId).toSet() ?? {};
    final filteredResults = _results.where((item) => !localApiIds.contains(item['id'])).toList();

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
                      'Discover',
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
            
            // Search & Filters Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Column(
                children: [
                  // AI Search Bar
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _aiSearchController,
                      onSubmitted: _onAiSearchSubmit,
                      style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: '✨ Describe a vibe or plot...',
                        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7)),
                        prefixIcon: Icon(Icons.auto_awesome, color: AppTheme.accent),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send, color: AppTheme.accent),
                          onPressed: () => _onAiSearchSubmit(_aiSearchController.text),
                        ),
                      ),
                    ),
                  ),
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
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: 'Search movies, TV shows...',
                        hintStyle: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.7)),
                        prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  
                  // Filter Chips
                  if (_searchController.text.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
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
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _currentGenre,
                                dropdownColor: AppTheme.surfaceLight,
                                style: const TextStyle(color: AppTheme.textMain, fontSize: 13, fontWeight: FontWeight.w600),
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 18),
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
                ],
              ),
            ),
            
            // Results Grid
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : filteredResults.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 64, color: AppTheme.surfaceLight),
                              const SizedBox(height: 16),
                              const Text('No results found.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: () async {
                            if (_searchController.text.trim().isEmpty) {
                              await _loadTrending();
                            } else {
                              _onSearchChanged(_searchController.text);
                            }
                          },
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: filteredResults.length + (_isLoadingMore ? 3 : 0),
                          itemBuilder: (context, index) {
                            if (index >= filteredResults.length) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            }

                            final item = filteredResults[index];
                            final title = item['title'] ?? item['name'] ?? 'Unknown';
                            final posterPath = item['poster_path'];
                            final type = item['media_type'] ?? (item['title'] != null ? 'movie' : 'tv');

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                                  tmdbId: item['id'],
                                  type: type,
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
                                    // Background Poster
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                          child: posterPath != null
                                            ? CachedNetworkImage(
                                                  imageUrl: 'https://image.tmdb.org/t/p/w300$posterPath', 
                                                  fit: BoxFit.cover,
                                                  errorWidget: (context, url, error) => _buildPlaceholder(title),
                                                )
                                            : _buildPlaceholder(title),
                                      ),
                                    ),
                                    
                                    // Top Left: Pill Badge
                                    Positioned(
                                      top: 8,
                                      left: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: type == 'movie' ? AppTheme.primary : AppTheme.surfaceLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: type == 'movie' ? Colors.transparent : Colors.white.withValues(alpha: 0.2),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                                          ],
                                        ),
                                        child: Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            color: type == 'movie' ? Colors.black : Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Top Right: + Add Button
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                                            tmdbId: item['id'],
                                            type: type,
                                          )));
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                          child: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
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
                                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.95),
                                              Colors.black.withValues(alpha: 0.6),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
          color: isActive ? AppTheme.primary : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : Colors.white.withValues(alpha: 0.05),
          ),
          boxShadow: isActive ? [
            BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
            fontSize: 13,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.movie_creation_rounded, color: Colors.white.withValues(alpha: 0.1), size: 32),
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
}
