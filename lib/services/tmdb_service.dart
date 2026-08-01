import 'dart:convert';
import 'package:http/http.dart' as http;

class TmdbService {
  static const String _apiKey = '87ca90817435c5a482ec6cb70ce71199';
  static const String _baseUrl = 'https://api.themoviedb.org/3';

  static Future<List<dynamic>> search(String query) async {
    final url = '$_baseUrl/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&include_adult=false';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getDetails(int id, String type) async {
    final t = type == 'movie' ? 'movie' : 'tv';
    final url = '$_baseUrl/$t/$id?api_key=$_apiKey&append_to_response=videos,credits,recommendations';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return null;
  }

  static Future<List<dynamic>> getTrending({String type = 'all', String genre = 'all', int page = 1}) async {
    if (genre == 'all') {
      if (type == 'anime') {
        final url = '$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=16&with_original_language=ja&page=$page';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) return json.decode(response.body)['results'] ?? [];
        return [];
      } else {
        final t = type == 'all' ? 'all' : type;
        final url = '$_baseUrl/trending/$t/week?api_key=$_apiKey&page=$page';
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) return json.decode(response.body)['results'] ?? [];
        return [];
      }
    }

    final gMap = {
      'action': {'movie': 28, 'tv': 10759},
      'animation': {'movie': 16, 'tv': 16},
      'comedy': {'movie': 35, 'tv': 35},
      'crime': {'movie': 80, 'tv': 80},
      'documentary': {'movie': 99, 'tv': 99},
      'drama': {'movie': 18, 'tv': 18},
      'family': {'movie': 10751, 'tv': 10751},
      'fantasy': {'movie': 14, 'tv': 10765}, // simplified fantasy logic
      'horror': {'movie': 27, 'tv': 27},
      'mystery': {'movie': 9648, 'tv': 9648},
      'romance': {'movie': 10749, 'tv': 18},
      'thriller': {'movie': 53, 'tv': 9648},
    };

    final g = gMap[genre];
    if (g == null) return [];

    if (type == 'all') {
      final resM = await http.get(Uri.parse('$_baseUrl/discover/movie?api_key=$_apiKey&with_genres=${g['movie']}&page=$page'));
      final resT = await http.get(Uri.parse('$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=${g['tv']}&page=$page'));
      
      final List<dynamic> results = [];
      if (resM.statusCode == 200) results.addAll(json.decode(resM.body)['results'] ?? []);
      if (resT.statusCode == 200) results.addAll(json.decode(resT.body)['results'] ?? []);
      return results;
    } else if (type == 'anime') {
      final url = '$_baseUrl/discover/tv?api_key=$_apiKey&with_genres=16,${g['tv']}&with_original_language=ja&page=$page';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body)['results'] ?? [];
      return [];
    } else {
      final gid = type == 'movie' ? g['movie'] : g['tv'];
      final url = '$_baseUrl/discover/$type?api_key=$_apiKey&with_genres=$gid&page=$page';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) return json.decode(response.body)['results'] ?? [];
      return [];
    }
  }
}
