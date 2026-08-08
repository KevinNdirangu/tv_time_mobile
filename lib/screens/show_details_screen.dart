import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import '../services/tmdb_service.dart';
import '../services/supabase_service.dart';
import '../services/ai_service.dart';
import '../models/show.dart';
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
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _fetchData();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

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

  void _checkIfFinished() {
    if (localData == null || tmdbData == null) return;
    if (tmdbData!['status'] != 'Ended' && tmdbData!['status'] != 'Canceled') return;
    
    int airedCount = 0;
    final now = DateTime.now();
    for (var ep in localData!.episodes) {
      if (ep['air_date'] != null) {
        final ad = DateTime.tryParse(ep['air_date']);
        if (ad != null && ad.compareTo(now) <= 0) {
          airedCount++;
        }
      }
    }
    
    if (localData!.watchedEpisodeIds.length >= airedCount && airedCount > 0) {
      _confettiController.play();
    }
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
      return Scaffold(
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

    return Stack(
      children: [
        Scaffold(
          body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppTheme.surface,
            actions: localData != null ? [
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'remove') {
                    await SupabaseActions.removeShow(localData!.show.id);
                    ref.invalidate(showsProvider);
                    ref.invalidate(libraryProvider);
                    if (mounted) Navigator.pop(context);
                  } else if (value == 'stop') {
                    int newVal = localData!.show.isStopped == 1 ? 0 : 1;
                    await SupabaseActions.setStopped(localData!.show.id, newVal);
                    ref.invalidate(showsProvider);
                    _fetchData();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'stop',
                    child: Text(localData!.show.isStopped == 1 ? 'Resume Watching' : 'Stop Watching'),
                  ),
                  const PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove Show', style: TextStyle(color: Colors.red)),
                  ),
                ],
              )
            ] : null,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
              ),
              background: backdrop != null
                  ? CachedNetworkImage(
                      imageUrl: 'https://image.tmdb.org/t/p/w780$backdrop',
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.4),
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
                  else if (widget.type == 'movie' && localData != null)
                    Builder(builder: (context) {
                      // A movie has exactly one episode (S1E1); check if it's watched
                      final movieEp = localData!.episodes.isNotEmpty ? localData!.episodes.first : null;
                      final isWatched = movieEp != null && localData!.watchedEpisodeIds.contains(movieEp['id']);
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isAddingMedia ? null : () async {
                                if (movieEp == null) {
                                  // Repair broken legacy movies
                                  setState(() => _isAddingMedia = true);
                                  await SupabaseActions.addMedia(widget.tmdbId, widget.type, markSeen: true);
                                  await _fetchData();
                                  ref.invalidate(showsProvider);
                                  ref.invalidate(libraryProvider);
                                  setState(() => _isAddingMedia = false);
                                  _confettiController.play();
                                  return;
                                }
                                
                                final epId = movieEp['id'] as int;
                                setState(() {
                                  if (isWatched) {
                                    localData!.watchedEpisodeIds.remove(epId);
                                  } else {
                                    localData!.watchedEpisodeIds.add(epId);
                                    _confettiController.play();
                                  }
                                });
                                await SupabaseActions.toggleWatched(epId, !isWatched);
                                ref.invalidate(showsProvider);
                                ref.invalidate(libraryProvider);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isWatched ? const Color(0xFF34C759).withValues(alpha: 0.15) : const Color(0xFF34C759),
                                foregroundColor: isWatched ? const Color(0xFF34C759) : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: isWatched ? const BorderSide(color: Color(0xFF34C759)) : BorderSide.none,
                                ),
                              ),
                              icon: _isAddingMedia 
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Icon(isWatched ? Icons.check_circle : Icons.check_circle_outline),
                              label: Text(isWatched ? 'Watched ✓' : 'Mark as Watched', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      );
                    })
                  else if (localData != null)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppTheme.primary)),
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
                      if (localData?.lastWatched != null && localData!.watchedEpisodeIds.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_today, size: 14, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatDate(localData!.lastWatched!)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                      if (tmdbData!['status'] != null) ...[
                        const SizedBox(width: 16),
                        Text(
                          tmdbData!['status'],
                          style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
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
      ),
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirection: 3.14159 / 2, // downwards
          maxBlastForce: 5,
          minBlastForce: 2,
          emissionFrequency: 0.05,
          numberOfParticles: 50,
          gravity: 0.1,
        ),
      ),
      ],
    );
  }

  Future<void> _addMedia(bool markSeen) async {
    // Optimistic UI Update
    setState(() {
      localData = SupabaseShowDetails(
        show: Show(
          id: 0,
          apiId: widget.tmdbId,
          title: tmdbData?['title'] ?? tmdbData?['name'] ?? 'Unknown',
          genre: '',
          totalEpisodes: 1,
          type: widget.type,
          timezoneOffset: 0,
          isStopped: 0,
        ),
        episodes: [],
        watchedEpisodeIds: [],
      );
      _isAddingMedia = true;
    });

    // Fire and forget background job
    SupabaseActions.addMedia(widget.tmdbId, widget.type, markSeen: markSeen).then((_) {
      if (mounted) {
        setState(() => _isAddingMedia = false);
      }
      // Trigger background syncs for other providers
      ref.invalidate(showsProvider);
      ref.invalidate(libraryProvider);
      ref.invalidate(calendarProvider);
    }).catchError((e) {
      if (mounted) {
        setState(() {
          localData = null; // Revert optimistic update
          _isAddingMedia = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding media: $e')));
      }
    });
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
                          ? CachedNetworkImage(
                                imageUrl: 'https://image.tmdb.org/t/p/w200$posterPath',
                                width: 100,
                                height: 150,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Container(width: 100, height: 150, color: AppTheme.surfaceLight, child: const Icon(Icons.tv_rounded, color: Colors.white24)),
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
        final isAllWatched = localEpisodes.isNotEmpty && watchedCount == localEpisodes.length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Row(
              children: [
                Expanded(child: Text(season['name'] ?? 'Season $seasonNum', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMain))),
                if (localData != null && localEpisodes.isNotEmpty)
                  IconButton(
                    icon: Icon(isAllWatched ? Icons.remove_done : Icons.done_all, color: isAllWatched ? AppTheme.textMuted : AppTheme.primary),
                    onPressed: () async {
                      await SupabaseActions.markSeason(localData!.show.id, seasonNum, !isAllWatched);
                      ref.invalidate(showsProvider);
                      _fetchData();
                    },
                  ),
              ],
            ),
            subtitle: localData != null
                ? Text('$watchedCount / ${localEpisodes.length} Watched', style: TextStyle(color: AppTheme.primary))
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

    final now = DateTime.now();

    return localEpisodes.map((ep) {
      final isWatched = localData!.watchedEpisodeIds.contains(ep['id']);
      
      bool hasAired = false;
      String airDateText = 'TBA';
      if (ep['air_date'] != null) {
        final ad = DateTime.tryParse(ep['air_date']);
        if (ad != null) {
          if (ad.compareTo(now) <= 0) {
            hasAired = true;
          } else {
            airDateText = 'Will air on ${ep['air_date']}';
          }
        }
      }

      final epTitle = ep['title'] ?? '';
      
      return ListTile(
        title: Text('E${ep['episode_number'].toString().padLeft(2, '0')} $epTitle', style: TextStyle(color: isWatched ? AppTheme.textMuted : AppTheme.textMain)),
        subtitle: isWatched && ep['watched_at'] != null
            ? Text('Logged: ${_formatDate(ep['watched_at'])}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))
            : (!hasAired ? Text(airDateText, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)) : null),
        onTap: hasAired ? () async {
          // Optimistic update
          setState(() {
            if (isWatched) {
              localData!.watchedEpisodeIds.remove(ep['id']);
            } else {
              localData!.watchedEpisodeIds.add(ep['id']);
              _checkIfFinished();
            }
          });
          await SupabaseActions.toggleWatched(ep['id'], !isWatched);
          ref.invalidate(showsProvider);
          ref.invalidate(calendarProvider);
        } : null,
        onLongPress: () async {
          if (hasAired) {
            await SupabaseActions.markUpTo(localData!.show.id, ep['season_number'], ep['episode_number']);
            ref.invalidate(showsProvider);
            _fetchData();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked up to this episode.')));
          }
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppTheme.textMuted),
              onPressed: () => _showEpisodeDetailsModal(ep),
            ),
            if (hasAired)
              IconButton(
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
                      _checkIfFinished();
                    }
                  });
                  await SupabaseActions.toggleWatched(ep['id'], !isWatched);
                  ref.invalidate(showsProvider);
                  ref.invalidate(calendarProvider);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                child: Text(
                  airDateText, 
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  void _showEpisodeDetailsModal(Map<String, dynamic> ep) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: TmdbService.getEpisodeDetails(widget.tmdbId, ep['season_number'], ep['episode_number']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final details = snapshot.data;
            final epTitle = ep['title'] ?? details?['name'] ?? 'TBA';
            final overview = details?['overview'] ?? 'No overview available.';
            final stillPath = details?['still_path'];

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (stillPath != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: Image.network(
                          'https://image.tmdb.org/t/p/w500$stillPath',
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Season ${ep['season_number']} Episode ${ep['episode_number']}', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(epTitle, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
                          const SizedBox(height: 16),
                          Text(overview, style: TextStyle(color: AppTheme.textMuted, fontSize: 16, height: 1.5)),
                          const SizedBox(height: 24),
                          if (localData != null)
                            _AiRecapWidget(
                              localData: localData!,
                              seasonNum: ep['season_number'],
                              epNum: ep['episode_number'],
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AiRecapWidget extends StatefulWidget {
  final SupabaseShowDetails localData;
  final int seasonNum;
  final int epNum;

  const _AiRecapWidget({required this.localData, required this.seasonNum, required this.epNum});

  @override
  State<_AiRecapWidget> createState() => _AiRecapWidgetState();
}

class _AiRecapWidgetState extends State<_AiRecapWidget> {
  bool _isLoading = false;
  String? _recap;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final key = await AiService.getApiKey();
    if (mounted && key != null && key.isNotEmpty) {
      setState(() => _hasKey = true);
    }
  }

  Future<void> _generate() async {
    setState(() => _isLoading = true);
    try {
      final eps = widget.localData.episodes.where((e) {
        if (!widget.localData.watchedEpisodeIds.contains(e['id'])) return false;
        if (e['season_number'] < widget.seasonNum) return true;
        if (e['season_number'] == widget.seasonNum && e['episode_number'] < widget.epNum) return true;
        return false;
      }).toList();

      if (eps.isEmpty) {
        setState(() {
          _recap = "You haven't watched any episodes prior to this one, so there's nothing to recap yet!";
          _isLoading = false;
        });
        return;
      }

      final res = await AiService.generateRecap(widget.localData.show.title, eps);
      if (mounted) setState(() { _recap = res; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _recap = "Error: \$e"; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasKey) return const SizedBox.shrink();

    if (_recap != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF1a1a2e), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF4a4e69))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✨ AI Season Recap', style: TextStyle(color: Color(0xFFa5a6f6), fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Text(_recap!, style: const TextStyle(color: AppTheme.textMuted, height: 1.5)),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFa5a6f6),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : const Icon(Icons.auto_awesome),
        label: Text(_isLoading ? 'Generating Recap...' : 'Generate AI Recap', style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _isLoading ? null : _generate,
      ),
    );
  }
}
