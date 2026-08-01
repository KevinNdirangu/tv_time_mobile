import 'show.dart';

class LibraryShow {
  final Show show;
  final int watchedEpisodes;
  final int airedEpisodes;
  final int runtime;
  final String? lastWatched;

  LibraryShow({
    required this.show,
    required this.watchedEpisodes,
    required this.airedEpisodes,
    required this.runtime,
    this.lastWatched,
  });

  factory LibraryShow.fromJson(Map<String, dynamic> json) {
    return LibraryShow(
      show: Show.fromJson(json['show']),
      watchedEpisodes: json['watchedEpisodes'] ?? 0,
      airedEpisodes: json['airedEpisodes'] ?? 0,
      runtime: json['runtime'] ?? 0,
      lastWatched: json['lastWatched'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'show': show.toJson(),
      'watchedEpisodes': watchedEpisodes,
      'airedEpisodes': airedEpisodes,
      'runtime': runtime,
      'lastWatched': lastWatched,
    };
  }
}
