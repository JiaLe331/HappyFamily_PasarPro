import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Responsible for generating poster captions via the Gemini REST API.
class PosterService {
  static const _model = 'gemini-2.5-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Returns a 2-line social media caption matching the template vibe.
  Future<String> generateCaption({
    required PosterTemplate template,
    required String itemName,
    required String price,
    required String promoText,
  }) async {
    final String vibeDescription = switch (template) {
      PosterTemplate.flashSale =>
        'urgent, high-energy, FOMO-driven (Yellow on Red / Flash Sale vibe)',
      PosterTemplate.newMenu =>
        'clean, premium, elegant (White minimalist / New Arrival vibe)',
      PosterTemplate.dailyPromo =>
        'warm, friendly, community-driven (Green / Earth-tone Daily Promo vibe)',
    };

    final prompt = '''
You are a social media copywriter for Malaysian hawker and pasar food stalls.
Create a 2-line social media post caption for a poster with the following details:

- Template Vibe: $vibeDescription
- Food / Item Name: $itemName
- Price: $price
- Promotion: $promoText

Rules:
- Line 1: Attention-grabbing hook (use emojis, mix Malay/English naturally)
- Line 2: Clear call-to-action with relevant hashtags (3-5 tags)
- Keep it punchy, under 30 words total
- DO NOT add any extra explanation, just output the two lines.
''';

    try {
      return await _callGemini(prompt);
    } catch (e) {
      // Fallback caption if AI fails
      return '🔥 $promoText on $itemName — only $price!\nGrab yours now! #PasarPro #MalaysianFood #WajibCuba';
    }
  }

  /// Calls the Gemini REST API (text-only) and returns the response text.
  Future<String> _callGemini(String prompt) async {
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }

    final uri = Uri.parse('$_endpoint?key=$_apiKey');

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.9,
        'topP': 0.95,
        'maxOutputTokens': 150,
      },
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text =
        data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Empty response from Gemini');
    }

    return text.trim();
  }
}

/// The three available poster templates.
enum PosterTemplate {
  flashSale,
  newMenu,
  dailyPromo,
}

extension PosterTemplateExtension on PosterTemplate {
  String get displayName => switch (this) {
        PosterTemplate.flashSale => 'FLASH SALE',
        PosterTemplate.newMenu => 'NEW ARRIVAL',
        PosterTemplate.dailyPromo => 'DAILY PROMO',
      };

  String get emoji => switch (this) {
        PosterTemplate.flashSale => '⚡',
        PosterTemplate.newMenu => '🎉',
        PosterTemplate.dailyPromo => '🌿',
      };
}
