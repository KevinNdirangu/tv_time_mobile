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
}
