import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('gemini_api_key');
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.isEmpty) {
      await prefs.remove('gemini_api_key');
    } else {
      await prefs.setString('gemini_api_key', key);
    }
  }

  static Future<String> callGemini(String prompt) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API Key not configured in Settings.');
    }

    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    return response.text?.trim() ?? '';
  }

  static Future<String> generateRecap(String showTitle, List<Map<String, dynamic>> episodes) async {
    final epsList = episodes.map((ep) => 'S${ep['season_number']}E${ep['episode_number']}: ${ep['title']}').join('\n');
    final prompt = '''You are a TV show recap assistant. The user wants a recap of the show "$showTitle". They have watched the following episodes:
$epsList
Generate a concise, spoiler-free recap of ONLY what happens in these specific episodes to refresh their memory before they watch the next episode. Do not spoil anything that happens after these episodes. Format the output in Markdown.''';
    return await callGemini(prompt);
  }

  static Future<String> autoTag(String showTitle, String overview, String genres) async {
    final prompt = '''You are a media categorizer. Based on the following TV show / movie details, generate 3 to 5 hyper-specific, comma-separated "vibe" tags (e.g., slow-burn, enemies-to-lovers, gritty, mind-bending, feel-good). 
Title: $showTitle
Overview: $overview
Genres: $genres
Output ONLY the comma-separated tags, nothing else.''';
    try {
      return await callGemini(prompt);
    } catch (e) {
      print('Auto-tag failed: $e');
      return '';
    }
  }

  static Future<String> chatWithLibrary(String query, String libraryJson) async {
    final prompt = '''You are a helpful AI TV/Movie assistant inside a tracking app. The user has the following library data (JSON format):
$libraryJson
The user says: "$query"
Answer their query conversationally based on their library data. Do not show the JSON. Format output in Markdown.''';
    return await callGemini(prompt);
  }
}
