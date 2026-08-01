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
}
