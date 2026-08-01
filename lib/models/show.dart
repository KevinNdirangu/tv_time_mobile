class Show {
  final int id;
  final int apiId;
  final String title;
  final String genre;
  final String? overview;
  final String? posterUrl;
  final int totalEpisodes;
  final String? status;
  final String type;
  final int timezoneOffset;
  final int isStopped;
  final int? userRating;
  final String? customTags;
  final String? userNotes;

  Show({
    required this.id,
    required this.apiId,
    required this.title,
    required this.genre,
    this.overview,
    this.posterUrl,
    required this.totalEpisodes,
    this.status,
    required this.type,
    required this.timezoneOffset,
    required this.isStopped,
    this.userRating,
    this.customTags,
    this.userNotes,
  });

  factory Show.fromJson(Map<String, dynamic> json) {
    return Show(
      id: json['id'],
      apiId: json['api_id'],
      title: json['title'] ?? '',
      genre: json['genre'] ?? '',
      overview: json['overview'],
      posterUrl: json['poster_url'],
      totalEpisodes: json['total_episodes'] ?? 0,
      status: json['status'],
      type: json['type'] ?? 'tv',
      timezoneOffset: json['timezone_offset'] ?? 0,
      isStopped: json['is_stopped'] ?? 0,
      userRating: json['user_rating'],
      customTags: json['custom_tags'],
      userNotes: json['user_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'api_id': apiId,
      'title': title,
      'genre': genre,
      'overview': overview,
      'poster_url': posterUrl,
      'total_episodes': totalEpisodes,
      'status': status,
      'type': type,
      'timezone_offset': timezoneOffset,
      'is_stopped': isStopped,
      'user_rating': userRating,
      'custom_tags': customTags,
      'user_notes': userNotes,
    };
  }
}
