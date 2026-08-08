import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('groq_api_key');
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

  static Future<String> chatWithLibrary(String query, String libraryData) async {
    final prompt = '''You are a helpful AI TV/Movie assistant inside a tracking app. The user has the following library data (Title|Status|Rating|Tags):
$libraryData
The user says: "$query"
Answer their query conversationally based on their library data. Do not show the raw data format. Format output in Markdown.''';
    return await callGroq(prompt);
  }
}
