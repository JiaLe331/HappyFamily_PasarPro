import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  late final String _apiKey;
  late final String _projectId;
  late final String _location;
  late final String _baseUrl;
  
  GeminiService() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _projectId = dotenv.env['PROJECT_ID'] ?? '';
    _location = dotenv.env['REGION'] ?? '';
    _baseUrl = dotenv.env['BASE_URL'] ?? '';
    
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }
  
  /// Helper method to encode image to base64
  String _encodeImage(Uint8List imageBytes) {
    return base64Encode(imageBytes);
  }
  
  /// Call Vertex AI generative API
  Future<String> _callVertexAI(
    String model,
    String prompt,
    Uint8List? imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final url = Uri(
      scheme: 'https',
      host: _baseUrl,
      path: '/v1/projects/$_projectId/locations/$_location/publishers/google/models/$model:generateContent',
      queryParameters: {'key': _apiKey},
    );

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            if (imageBytes != null)
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': _encodeImage(imageBytes),
                }
              }
          ],
        }
      ],
      'generationConfig': {
        'temperature': 1.0,
        'topP': 0.95,
      },
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception('Vertex AI API error: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final content = responseData['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
    
    if (content == null) {
      throw Exception('No text content in Vertex AI response');
    }

    return content;
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
      
      final text = await _callVertexAI('gemini-2.5-flash', prompt, imageBytes);
      
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
  
  /// Enhance food image using Gemini 2.5 Flash Image (Nano Banana)
  /// Returns a list of enhanced image variations (generates 3 in one call)
  Future<List<Uint8List>> enhanceImage(File imageFile, {String? customPrompt}) async {
    try 
    {
      final imageBytes = await imageFile.readAsBytes();
      
      final prompt = customPrompt ?? 
'''
Transform this image and create 3 separate images based on each instruction:
Image 1 (Clean and Bright Style):
- Clean background with white/light surface
- Bright, natural lighting
- Vibrant, appetizing colors

Image 2 (Warm and Cozy Style):
- Wooden table background
- Warm, soft lighting with golden tones
- Natural, home-cooked feel
        
Image 3 (Modern and Minimalist Style):
- Dark background for contrast
- Dramatic lighting highlighting the food
- Professional restaurant presentation

All 3 images must:
- Keep authentic Malaysian food appearance
- Maintain original food composition and angle (make sure the entire dish is visible)
- Make suitable for social media posting
''';

      final enhancedImages = await _callImageEnhanceAI(imageBytes, prompt);
      return enhancedImages;
    }
    catch (e)
    {
      throw Exception('Image enhancement failed: $e');
    }
  }

  Future<List<Uint8List>> _callImageEnhanceAI(Uint8List imageBytes, String prompt) async
  {
    final url = Uri
    (
      scheme: 'https',
      host: _baseUrl,
      // path: '/v1/projects/$_projectId/locations/$_location/publishers/google/models/gemini-2.0-flash-exp:generateContent',
      path: '/v1/projects/$_projectId/locations/$_location/publishers/google/models/gemini-2.5-flash-image:generateContent',
      queryParameters: {'key': _apiKey}
    );
    
    final requestBody =
    {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': _encodeImage(imageBytes),
              }
            }
          ],
        }
      ],
      'generationConfig': {
        'temperature': 1.0,
        'topP': 0.95,
        'responseModalities': ['text','image'],
        "imageConfig": {
          "aspectRatio": "4:5",
        },
      },
    };

    print('[Enhancing Image] Sending request...');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    
    print('[Enhancing Image] Response status: ${response.statusCode}');
    print('[Enhancing Image] Response body: ${response.body}');
    
    if (response.statusCode != 200) 
    {
      print('[Enhancing Image] Error response: ${response.body}');
      throw Exception('Enhancing Image API error: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final candidates = responseData['candidates'] as List?;
    
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in response');
    }
    
    final List<Uint8List> enhancedImages = [];
    
    for (final candidate in candidates) {
      final parts = candidate?['content']?['parts'] as List?;
      if (parts == null || parts.isEmpty) continue;
      
      for (final part in parts) {
        if (part is Map && part.containsKey('inlineData')) {
          final inlineData = part['inlineData'] as Map;
          final base64Image = inlineData['data'] as String?;
          
          if (base64Image != null) {
            enhancedImages.add(base64Decode(base64Image));
          }
        }
      }
    }

    print('[Enhancing Image] Extracted ${enhancedImages.length} images.');
    if (enhancedImages.isEmpty) {
      throw Exception('No image data in response');
    }
    
    return enhancedImages;
  }
  
  /// Generate multi-language captions with hashtags
  Future<CaptionSet> generateCaptions(String foodName, String description) async {
    try {
      final prompt = '''
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
      
      final text = await _callVertexAI('gemini-2.5-flash', prompt, null);
      
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
