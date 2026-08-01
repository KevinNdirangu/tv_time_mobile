import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tmdb_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

class ShowDetailsScreen extends ConsumerStatefulWidget {
  final int tmdbId;
  final String type;

  const ShowDetailsScreen({super.key, required this.tmdbId, required this.type});

  @override
  ConsumerState<ShowDetailsScreen> createState() => _ShowDetailsScreenState();
}

class _ShowDetailsScreenState extends ConsumerState<ShowDetailsScreen> {
  Map<String, dynamic>? tmdbData;
  SupabaseShowDetails? localData;
  bool isLoading = true;
  bool _isAddingMedia = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final tData = await TmdbService.getDetails(widget.tmdbId, widget.type);
    SupabaseShowDetails? sData;
    if (tData != null) {
      sData = await SupabaseActions.getShowDetails(widget.tmdbId);
    }
    setState(() {
      tmdbData = tData;
      localData = sData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    if (tmdbData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Could not load details.', style: TextStyle(color: AppTheme.textMuted))),
      );
    }

    final backdrop = tmdbData!['backdrop_path'];
    final title = tmdbData!['title'] ?? tmdbData!['name'] ?? 'Unknown';
    final overview = tmdbData!['overview'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
              ),
              background: backdrop != null
                  ? Image.network(
                      'https://image.tmdb.org/t/p/w780$backdrop',
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
                      colorBlendMode: BlendMode.darken,
                    )
                  : Container(color: AppTheme.surfaceLight),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons
                  if (localData == null)
                    Row(
                      children: [
                        if (widget.type == 'movie') ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAddingMedia ? null : () => _addMedia(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9F0A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isAddingMedia
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Add to Watchlist', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isAddingMedia ? null : () => _addMedia(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF34C759),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isAddingMedia
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('Mark as Seen', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isAddingMedia ? null : () => _addMedia(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isAddingMedia ? const SizedBox.shrink() : const Icon(Icons.add),
                              label: _isAddingMedia
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                  : const Text('Add to Library', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppTheme.primary)),
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('In Library', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Meta & Ratings
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.type.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      if (tmdbData!['vote_average'] != null) ...[
                        const SizedBox(width: 16),
                        const Icon(Icons.star, color: Color(0xFFFFD600), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${(tmdbData!['vote_average'] as num).toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                        const Text(' / 10', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      ],
                      if (tmdbData!['status'] != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          tmdbData!['status'],
                          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (tmdbData!['genres'] != null)
                    Text(
                      ((tmdbData!['genres'] as List).map((g) => g['name']).join(', ')),
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),

                  const SizedBox(height: 24),
                  const Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                  const SizedBox(height: 8),
                  Text(overview, style: const TextStyle(color: AppTheme.textMuted, height: 1.5)),
                  const SizedBox(height: 24),
                  
                  // Trailer Button
                  if (tmdbData!['videos'] != null && tmdbData!['videos']['results'] != null)
                    ..._buildTrailerButton(tmdbData!['videos']['results']),

                  if (widget.type == 'tv' && localData != null) ...[
                    const Text('Seasons', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                    const SizedBox(height: 16),
                    _buildSeasonsList(),
                  ],

                  // Recommendations
                  if (tmdbData!['recommendations'] != null && tmdbData!['recommendations']['results'] != null && (tmdbData!['recommendations']['results'] as List).isNotEmpty)
                    ..._buildRecommendations(tmdbData!['recommendations']['results']),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMedia(bool markSeen) async {
    setState(() => _isAddingMedia = true);
    try {
      await SupabaseActions.addMedia(widget.tmdbId, widget.type, markSeen: markSeen);
      ref.invalidate(showsProvider);
      ref.invalidate(libraryProvider);
      ref.invalidate(calendarProvider);
      await _fetchData(); // Reload localData
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding media: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAddingMedia = false);
    }
  }

  List<Widget> _buildTrailerButton(List<dynamic> videos) {
    final tr = videos.cast<Map<String, dynamic>>().firstWhere(
      (v) => v['type'] == 'Trailer' && v['site'] == 'YouTube',
      orElse: () => <String, dynamic>{},
    );
    if (tr.isEmpty) return [];

    return [
      ElevatedButton.icon(
        onPressed: () async {
          final url = Uri.parse('https://youtube.com/watch?v=${tr['key']}');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3B30),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Watch Trailer', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildRecommendations(List<dynamic> recs) {
    return [
      const Divider(color: Colors.white10, height: 40),
      const Text('Similar & Recommended', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
      const SizedBox(height: 16),
      SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: recs.length > 10 ? 10 : recs.length,
          itemBuilder: (context, index) {
            final rec = recs[index];
            final posterPath = rec['poster_path'];
            final recType = rec['media_type'] ?? widget.type;
            
            return GestureDetector(
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ShowDetailsScreen(
                  tmdbId: rec['id'],
                  type: recType,
                )));
              },
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: posterPath != null
                          ? Image.network(
                              'https://image.tmdb.org/t/p/w200$posterPath',
                              width: 100,
                              height: 150,
                              fit: BoxFit.cover,
                            )
                          : Container(width: 100, height: 150, color: AppTheme.surfaceLight),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec['title'] ?? rec['name'] ?? '',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildSeasonsList() {
    final seasons = (tmdbData!['seasons'] as List?)?.where((s) => s['season_number'] > 0).toList() ?? [];
    if (seasons.isEmpty) return const Text('No seasons found.', style: TextStyle(color: AppTheme.textMuted));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: seasons.length,
      itemBuilder: (context, index) {
        final season = seasons[index];
        final seasonNum = season['season_number'];

        // Get local episodes for this season
        final localEpisodes = localData?.episodes.where((e) => e['season_number'] == seasonNum).toList() ?? [];
        final watchedCount = localEpisodes.where((e) => localData!.watchedEpisodeIds.contains(e['id'])).length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(season['name'] ?? 'Season $seasonNum', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain)),
            subtitle: localData != null
                ? Text('$watchedCount / ${localEpisodes.length} Watched', style: const TextStyle(color: AppTheme.primary))
                : Text('${season['episode_count']} Episodes', style: const TextStyle(color: AppTheme.textMuted)),
            children: localData != null ? _buildEpisodeRows(localEpisodes) : [const Padding(padding: EdgeInsets.all(16), child: Text('Add to library to track episodes', style: TextStyle(color: AppTheme.textMuted)))],
          ),
        );
      },
    );
  }

  List<Widget> _buildEpisodeRows(List<Map<String, dynamic>> localEpisodes) {
    // sort episodes by episode_number
    localEpisodes.sort((a, b) => a['episode_number'].compareTo(b['episode_number']));

    return localEpisodes.map((ep) {
      final isWatched = localData!.watchedEpisodeIds.contains(ep['id']);
      return ListTile(
        title: Text('Episode ${ep['episode_number']}', style: TextStyle(color: isWatched ? AppTheme.textMuted : AppTheme.textMain)),
        trailing: IconButton(
          icon: Icon(
            isWatched ? Icons.check_circle : Icons.circle_outlined,
            color: isWatched ? AppTheme.primary : AppTheme.textMuted,
          ),
          onPressed: () async {
            // Optimistic update
            setState(() {
              if (isWatched) {
                localData!.watchedEpisodeIds.remove(ep['id']);
              } else {
                localData!.watchedEpisodeIds.add(ep['id']);
              }
            });
            await SupabaseActions.toggleWatched(ep['id'], !isWatched);
            ref.invalidate(showsProvider);
            ref.invalidate(calendarProvider);
          },
        ),
      );
    }).toList();
  }
}
