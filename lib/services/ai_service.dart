import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_api_key');
  }

  static Future<bool> hasKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove('groq_api_key');
    } else {
      await prefs.setString('groq_api_key', key);
    }
  }

  static Future<String> callGroq(String prompt) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Groq API Key not configured in Settings.');
    }

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': [{'role': 'user', 'content': prompt}]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].toString().trim();
    } else {
      throw Exception('Groq error: ${response.body}');
    }
  }

  static Future<String> generateRecap(String showTitle, List<Map<String, dynamic>> episodes) async {
    final epsList = episodes.map((ep) => 'S${ep['season_number']}E${ep['episode_number']}: ${ep['title']}').join('\n');
    final prompt = '''You are a TV show recap assistant. The user wants a recap of the show "$showTitle". They have watched the following episodes:
$epsList
Generate a concise, spoiler-free recap of ONLY what happens in these specific episodes to refresh their memory before they watch the next episode. Do not spoil anything that happens after these episodes. Format the output in Markdown.''';
    return await callGroq(prompt);
  }

  static Future<String> autoTag(String showTitle, String overview, String genres) async {
    final prompt = '''You are a media categorizer. Based on the following TV show / movie details, generate 3 to 5 hyper-specific, comma-separated "vibe" tags (e.g., slow-burn, enemies-to-lovers, gritty, mind-bending, feel-good). 
Title: $showTitle
Overview: $overview
Genres: $genres
Output ONLY the comma-separated tags, nothing else.''';
    try {
      return await callGroq(prompt);
    } catch (e) {
      print('Auto-tag failed: $e');
      return '';
    }
  }

  static Future<List<String>> smartSearch(String vibeQuery, {List<String> existingTitles = const []}) async {
    String excludeText = '';
    if (existingTitles.isNotEmpty) {
      excludeText = 'DO NOT recommend any of these titles (you already recommended them): ${existingTitles.join(", ")}. Recommend entirely new titles.';
    }
    
    final prompt = '''You are a TV show and Movie recommendation engine. The user is looking for something to watch based on this vibe or description: "$vibeQuery".
$excludeText
Please recommend exactly 5 relevant TV show or movie titles. 
Output ONLY a JSON array of strings containing the titles. Do not include any markdown formatting, backticks, or extra text. Example output: ["Inception", "Interstellar", "The Matrix", "Tenet", "Blade Runner 2049"]''';
    
    try {
      final result = await callGroq(prompt);
      final cleanResult = result.replaceAll('```json', '').replaceAll('```', '').trim();
      final List<dynamic> parsed = jsonDecode(cleanResult);
      return parsed.map((e) => e.toString()).toList();
    } catch (e) {
      print('Smart search failed: $e');
      return [];
    }
  }

  static Future<String> generateUserRecap(Map<String, dynamic> statsData) async {
    final statsJson = jsonEncode(statsData);
    final prompt = '''You are a fun and energetic TV/Movie tracking assistant. The user has requested their "TV Time Recap" (similar to Spotify Wrapped).
Here are their lifetime watching statistics:
$statsJson
Write a fun, highly engaging 2-3 paragraph summary celebrating their watching habits. Use markdown formatting, emojis, and a conversational tone. Do not use headers. Focus on their top genres, total time watched, and favorite shows.''';
    try {
      return await callGroq(prompt);
    } catch (e) {
      print('Recap failed: $e');
      return 'Oops! I couldn\'t generate your recap right now.';
    }
  }

  static Future<String> chatWithLibrary(String query, String libraryData) async {
    final prompt = '''You are a helpful AI TV/Movie assistant inside a tracking app. The user has the following library data (Title|Status|Rating|Tags):
$libraryData
The user says: "$query"
Answer their query conversationally based on their library data. Do not show the raw data format. Format output in Markdown.''';
    return await callGroq(prompt);
  }
}
