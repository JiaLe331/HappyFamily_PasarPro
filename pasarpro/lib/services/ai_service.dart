import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiService {
  late final String _apiKey;
  late final String _projectId;
  late final String _location;
  late final String _baseUrl;
  static const String _veoModelId = 'veo-3.1-fast-generate-preview';
  
  AiService() {
    _apiKey = dotenv.env['VERTEX_API_KEY'] ?? '';
    _projectId = dotenv.env['PROJECT_ID'] ?? '';
    _location = dotenv.env['REGION'] ?? '';
    _baseUrl = dotenv.env['BASE_URL'] ?? '';
    
    if (_apiKey.isEmpty) {
      throw Exception('VERTEX_API_KEY not found in .env file');
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

      final enhancedImages = await _callNanoBanana(imageBytes, prompt);
      return enhancedImages;
    }
    catch (e)
    {
      throw Exception('Image enhancement failed: $e');
    }
  }

  Future<List<Uint8List>> _callNanoBanana(Uint8List imageBytes, String prompt) async
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

  /// Generate a plain-text caption from a freeform prompt (no image needed)
  Future<String> generateCaption(String prompt) async {
    try {
      return await _callVertexAI('gemini-2.5-flash', prompt, null);
    } catch (e) {
      throw Exception('Caption generation failed: $e');
    }
  }

  /// Generate a short video reel using up to 3 reference images
  Future<List<Uint8List>> generateReels(List<File> referenceImageFiles, FoodAnalysis foodAnalysis) async
  {
    try
    {
      final imageBytesList = <Uint8List>[];
      for (final imageFile in referenceImageFiles) {
        final bytes = await imageFile.readAsBytes();
        imageBytesList.add(bytes);
      }

      final prompt = 
'''
Create a short video reel for this Malaysian food
- Food name: ${foodAnalysis.foodName}
- Cuisine: ${foodAnalysis.cuisine}
- Description: ${foodAnalysis.description}
- Ingredients: ${foodAnalysis.ingredients.join(', ')}

Use the reference images to create an engaging and appetizing video to showcase and promote the food on social media.
''';

      final generatedReels = await _callVeo(imageBytesList, prompt);
      return generatedReels;
    }
    catch (e)
    {
      throw Exception('Reels generation failed: $e');
    }
  }

  Future<List<Uint8List>> _callVeo(List<Uint8List> imageBytesList, String prompt) async
  {
    final url = Uri
    (
      scheme: 'https',
      host: _baseUrl,
      path: '/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_veoModelId:predictLongRunning',
      queryParameters: {'key': _apiKey}
    );
    
    final requestBody =
    {
      "instances": [
        {
          "prompt": prompt,
          // The following fields can be repeated for up to three total images.
          "referenceImages": [
            for (final imageBytes in imageBytesList)
            {
              "image": {
                "bytesBase64Encoded": base64Encode(imageBytes),
                "mimeType": "image/jpeg"
              },
              "referenceType": "asset"
            }
          ]
        }
      ],
      "parameters": {
        "aspectRatio": "9:16",
        "durationSeconds": 8, // can let user choose
        "sampleCount": 2,
        "resolution": "720p", // can let user choose
      }
    };

    print('[Generating Reels] Sending request...');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );
    
    print('[Generating Reels] Response status: ${response.statusCode}');
    print('[Generating Reels] Response body: ${response.body}');
    
    if (response.statusCode != 200) 
    {
      print('[Generating Reels] Error response: ${response.body}');
      throw Exception('Generating Reels API error: ${response.statusCode} - ${response.body}');
    }

    final responseData = jsonDecode(response.body);
    final operationName = responseData['name'] as String?;
    
    if (operationName == null) {
      throw Exception('No operation name in response');
    }

    print('[Generating Reels] Operation started: $operationName');

    // Poll the operation until it completes
    final result = await _pollLongRunningOperation(operationName);
    
    final List<Uint8List> generatedReels = [];
    
    // Extract videos from the operation result
    final responsePayload = result['response'] ?? result['result'] ?? result['predictResponse'] ?? result;

    final predictions = responsePayload['predictions'] as List?;
    if (predictions != null) {
      for (final prediction in predictions) {
        if (prediction is Map<String, dynamic>) {
          final base64Video = prediction['bytesBase64Encoded'] as String?;
          if (base64Video != null) {
            generatedReels.add(base64Decode(base64Video));
          }
        }
      }
    }

    if (generatedReels.isEmpty) {
      final videosList = responsePayload['videos'] as List?;
      if (videosList != null) {
        for (final video in videosList) {
          if (video is Map<String, dynamic>) {
            final base64Video = video['bytesBase64Encoded'] as String?;
            if (base64Video != null) {
              generatedReels.add(base64Decode(base64Video));
            }
          }
        }
      }
    }

    print('[Generating Reels] Extracted ${generatedReels.length} videos.');
    if (generatedReels.isEmpty) {
      throw Exception('No video data in operation result');
    }
    
    return generatedReels;
  }

  Future<Map<String, dynamic>> _pollLongRunningOperation(String operationName) async {
    // 2 Minutes 30 Seconds
    const maxAttempts = 5; 
    const delaySeconds = 30;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final url = Uri(
        scheme: 'https',
        host: _baseUrl,
        path: '/v1/projects/$_projectId/locations/$_location/publishers/google/models/$_veoModelId:fetchPredictOperation',
        queryParameters: {'key': _apiKey},
      );

      print('[Polling Operation] Checking: ${url.toString()}');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'operationName': operationName}),
      );

      print('[Polling Operation] Attempt ${attempt + 1}/$maxAttempts - Status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('Failed to get operation status: ${response.statusCode} - ${response.body}');
      }

      final operationData = jsonDecode(response.body) as Map<String, dynamic>;
      final isDone = operationData['done'] as bool? ?? false;

      if (isDone) {
        print('[Polling Operation] Operation completed!');
        
        // Check for errors
        if (operationData.containsKey('error')) {
          throw Exception('Operation failed: ${operationData['error']}');
        }

        final payload = operationData['response'] ?? operationData['result'] ?? operationData;
        if (payload is! Map<String, dynamic>) {
          throw Exception('No result payload in completed operation');
        }

        final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
        print('[Polling Operation] Result payload:\n$prettyJson');

        return payload;
      }

      print('[Polling Operation] Operation still running, waiting ${delaySeconds}s...');
      await Future.delayed(Duration(seconds: delaySeconds));
    }

    throw Exception('Operation timed out after ${maxAttempts * delaySeconds} seconds');
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