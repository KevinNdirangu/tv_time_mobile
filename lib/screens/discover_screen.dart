import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/tmdb_service.dart';
import 'show_details_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
        return;
      }
      setState(() => _isLoading = true);
      final results = await TmdbService.search(query);
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
            
            // Results Section
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                  : _results.isEmpty && _searchController.text.isNotEmpty
                      ? const Center(child: Text('No results found.', style: TextStyle(color: AppTheme.textMuted)))
                      : _results.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.trending_up_rounded, size: 64, color: AppTheme.surfaceLight),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Type something to start searching',
                                    style: TextStyle(color: AppTheme.textMuted.withOpacity(0.5)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final item = _results[index];
                                final title = item['title'] ?? item['name'] ?? 'Unknown';
                                final type = item['media_type'] == 'movie' ? 'Movie' : 'TV Show';
                                final posterPath = item['poster_path'];
                                final year = (item['release_date'] ?? item['first_air_date'] ?? '').split('-').first;

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: posterPath != null
                                        ? Image.network('https://image.tmdb.org/t/p/w200$posterPath', width: 50, height: 75, fit: BoxFit.cover)
                                        : Container(width: 50, height: 75, color: AppTheme.surfaceLight, child: const Icon(Icons.movie, size: 20)),
                                  ),
                                  title: Text(title, style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.bold)),
                                  subtitle: Text('$type ${year.isNotEmpty ? "• $year" : ""}', style: const TextStyle(color: AppTheme.primary)),
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                                      tmdbId: item['id'],
                                      type: item['media_type'] == 'movie' ? 'movie' : 'tv',
                                    )));
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
