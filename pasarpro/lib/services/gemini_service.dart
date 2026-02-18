import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final GenerativeModel _visionModel;
  late final GenerativeModel _imageModel;
  late final GenerativeModel _textModel;

  GeminiService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }

    // Gemini 2.5 Flash for vision (food analysis)
    _visionModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);

    // Gemini 2.5 Flash Image (Nano Banana) for image enhancement
    _imageModel = GenerativeModel(
      model: 'gemini-2.5-flash-image',
      apiKey: apiKey,
    );

    // Gemini 2.5 Flash for text generation (captions)
    _textModel = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
  }

  /// Analyze food image to identify dish name, cuisine, and ingredients
  Future<FoodAnalysis> analyzeFood(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt = '''
Analyze this food image and provide:
1. Food name (in English)
2. Cuisine type (e.g., Malaysian, Chinese, Indian)
3. Main ingredients (list 3-5 key ingredients)
4. Brief description (1-2 sentences)

Respond in JSON format:
{
  "foodName": "...",
  "cuisine": "...",
  "ingredients": ["...", "..."],
  "description": "..."
}
''';

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      final response = await _visionModel.generateContent(content);
      final text = response.text ?? '';

      // Extract JSON from response (handle markdown code blocks)
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('Failed to parse food analysis response');
      }

      final jsonData = jsonDecode(jsonMatch.group(0)!);
      return FoodAnalysis.fromJson(jsonData);
    } catch (e) {
      throw Exception('Food analysis failed: $e');
    }
  }

  /// Enhance food image using Nano Banana (background cleanup, lighting)
  Future<Uint8List?> enhanceImage(
    File imageFile, {
    String? customPrompt,
  }) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt =
          customPrompt ??
          '''
Transform this hawker stall food photo into professional food photography:
- Clean up cluttered background and replace with simple, clean surface
- Enhance lighting to make the food look appetizing and vibrant
- Improve colors to look natural and mouth-watering
- Keep the authentic Malaysian food appearance
- Maintain the original food composition and angle
''';

      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];

      print('[DEBUG] Calling gemini-2.5-flash-image for enhancement...');
      final response = await _imageModel.generateContent(content);
      print(
        '[DEBUG] Response received. Candidates: ${response.candidates.length}',
      );

      // Extract image data from response
      if (response.candidates.isNotEmpty) {
        final candidate = response.candidates.first;
        print('[DEBUG] Parts in response: ${candidate.content.parts.length}');
        if (candidate.content.parts.isNotEmpty) {
          for (final part in candidate.content.parts) {
            print('[DEBUG] Part type: ${part.runtimeType}');
            if (part is DataPart) {
              print('[DEBUG] Found DataPart with ${part.bytes.length} bytes');
              return part.bytes;
            }
          }
        }
      }

      print('[DEBUG] No image data found in response');
      return null;
    } catch (e) {
      print('[ERROR] Image enhancement failed: $e');
      return null;
    }
  }

  /// Generate multi-language captions with hashtags
  Future<CaptionSet> generateCaptions(
    String foodName,
    String description,
  ) async {
    try {
      final prompt =
          '''
Create engaging social media captions for this Malaysian food: $foodName

Description: $description

Generate 3 captions in different languages:
1. English - Casual, appetizing, use food emojis
2. Malay - Natural Bahasa Malaysia, friendly tone
3. Mandarin (Simplified Chinese) - Appealing to Chinese-speaking audience

Also generate 5-7 relevant hashtags (mix of English and Malay).

Respond in JSON format:
{
  "english": "...",
  "malay": "...",
  "mandarin": "...",
  "hashtags": ["#NasiLemak", "#MalaysianFood", ...]
}
''';

      final response = await _textModel.generateContent([Content.text(prompt)]);
      final text = response.text ?? '';

      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('Failed to parse caption response');
      }

      final jsonData = jsonDecode(jsonMatch.group(0)!);
      return CaptionSet.fromJson(jsonData);
    } catch (e) {
      throw Exception('Caption generation failed: $e');
    }
  }
}

/// Data model for food analysis results
class FoodAnalysis {
  final String foodName;
  final String cuisine;
  final List<String> ingredients;
  final String description;

  FoodAnalysis({
    required this.foodName,
    required this.cuisine,
    required this.ingredients,
    required this.description,
  });

  factory FoodAnalysis.fromJson(Map<String, dynamic> json) {
    return FoodAnalysis(
      foodName: json['foodName'] as String,
      cuisine: json['cuisine'] as String,
      ingredients: (json['ingredients'] as List).cast<String>(),
      description: json['description'] as String,
    );
  }
}

/// Data model for multi-language captions
class CaptionSet {
  final String english;
  final String malay;
  final String mandarin;
  final List<String> hashtags;

  CaptionSet({
    required this.english,
    required this.malay,
    required this.mandarin,
    required this.hashtags,
  });

  factory CaptionSet.fromJson(Map<String, dynamic> json) {
    return CaptionSet(
      english: json['english'] as String,
      malay: json['malay'] as String,
      mandarin: json['mandarin'] as String,
      hashtags: (json['hashtags'] as List).cast<String>(),
    );
  }
}
