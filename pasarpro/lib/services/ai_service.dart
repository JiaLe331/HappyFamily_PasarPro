import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiService — fully powered by Google AI Studio (generativelanguage.googleapis.com)
//
// Previously used Vertex AI (projects/locations/publishers URLs) which required
// PROJECT_ID, REGION, and BASE_URL env vars that were not set — causing the
// "No host specified in URI" crash.
//
// Now uses GEMINI_API_KEY (already in .env) with the simple AI Studio REST API,
// identical to how KiraKiraService works.
// ─────────────────────────────────────────────────────────────────────────────

class AiService {
  static const String _geminiHost = 'generativelanguage.googleapis.com';
  // gemini-2.5-flash: supports multimodal input (text + image) and is fast
  static const String _geminiModel = 'gemini-2.5-flash';
  // gemini-2.5-flash-preview-image-generation: supports native image OUTPUT (responseModalities)
  static const String _imageGenModel = 'gemini-2.5-flash-image';

  late final String _apiKey;

  AiService() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Core HTTP helper — AI Studio REST API
  // ─────────────────────────────────────────────────────────────────────────

  /// Calls the Gemini AI Studio generateContent endpoint.
  ///
  /// [model]      — model ID (e.g. 'gemini-2.5-flash')
  /// [prompt]     — text prompt
  /// [imageBytes] — optional image bytes for multimodal requests
  /// [mimeType]   — MIME type of the image (default: image/jpeg)
  /// [responseModalities] — e.g. ['TEXT', 'IMAGE'] for image-generation models
  Future<Map<String, dynamic>> _callGemini(
    String model,
    String prompt, {
    Uint8List? imageBytes,
    String mimeType = 'image/jpeg',
    List<String> responseModalities = const ['TEXT'],
  }) async {
    final url = Uri(
      scheme: 'https',
      host: _geminiHost,
      path: '/v1beta/models/$model:generateContent',
      queryParameters: {'key': _apiKey},
    );

    final parts = <Map<String, dynamic>>[
      {'text': prompt},
      if (imageBytes != null)
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(imageBytes),
          }
        },
    ];

    final body = jsonEncode({
      'contents': [
        {'role': 'user', 'parts': parts}
      ],
      'generationConfig': {
        'temperature': 1.0,
        'topP': 0.95,
        'responseModalities': responseModalities,
      },
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Gemini API error ${response.statusCode}: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Food Analysis
  // ─────────────────────────────────────────────────────────────────────────

  /// Analyzes a food image and returns dish name, cuisine, ingredients, and description.
  Future<FoodAnalysis> analyzeFood(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      const prompt = '''
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

      final data = await _callGemini(
        _geminiModel,
        prompt,
        imageBytes: imageBytes,
      );

      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text == null || text.isEmpty) {
        throw Exception('Empty response from Gemini');
      }

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) {
        throw Exception('Failed to parse food analysis response');
      }

      return FoodAnalysis.fromJson(
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Food analysis failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Image Enhancement (Nano Banana — gemini-2.0-flash-exp with image output)
  // ─────────────────────────────────────────────────────────────────────────

  /// Enhances a food photo by generating 3 styled variations.
  Future<List<Uint8List>> enhanceImage(File imageFile,
      {String? customPrompt}) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      final prompt = customPrompt ??
          '''
Transform this food photo into 3 beautiful styled versions for social media:

Style 1 — Clean & Bright:
- Crisp white or light background
- Bright, natural daylight lighting
- Vibrant, appetizing colours

Style 2 — Warm & Cosy:
- Rustic wooden table surface
- Warm golden-hour lighting
- Home-cooked, inviting feel

Style 3 — Modern & Dramatic:
- Dark moody background for contrast
- Dramatic spotlighting on the food
- Fine-dining restaurant presentation

All versions must:
- Keep the authentic Malaysian food appearance
- Maintain original composition (full dish visible)
- Look stunning for Instagram / TikTok
''';

      return await _callNanoBanana(imageBytes, prompt);
    } catch (e) {
      throw Exception('Image enhancement failed: $e');
    }
  }

  Future<List<Uint8List>> _callNanoBanana(
      Uint8List imageBytes, String prompt) async {
    final data = await _callGemini(
      _imageGenModel,
      prompt,
      imageBytes: imageBytes,
      responseModalities: ['TEXT', 'IMAGE'],
    );

    print('[NanaBanana] Raw response keys: ${data.keys}');

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('No candidates in image generation response');
    }

    final List<Uint8List> images = [];

    for (final candidate in candidates) {
      final parts = candidate?['content']?['parts'] as List?;
      if (parts == null) continue;
      for (final part in parts) {
        if (part is! Map) continue;
        // AI Studio returns inlineData (camelCase)
        final inlineData =
            (part['inlineData'] ?? part['inline_data']) as Map?;
        if (inlineData == null) continue;
        final b64 = inlineData['data'] as String?;
        if (b64 != null && b64.isNotEmpty) {
          images.add(base64Decode(b64));
        }
      }
    }

    print('[NanaBanana] Extracted ${images.length} images.');

    if (images.isEmpty) {
      // The model returned text but no images — surface a meaningful error
      final textParts = (candidates[0]?['content']?['parts'] as List? ?? [])
          .where((p) => p is Map && p['text'] != null)
          .map((p) => p['text'] as String)
          .join('\n');
      throw Exception(
          'Image generation returned no images. Model said: $textParts');
    }

    return images;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Caption Generation
  // ─────────────────────────────────────────────────────────────────────────

  /// Generates English, Malay, and Mandarin captions with hashtags.
  Future<CaptionSet> generateCaptions(
      String foodName, String description) async {
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

      final data = await _callGemini(_geminiModel, prompt);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text == null) throw Exception('Empty caption response');

      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch == null) throw Exception('Failed to parse caption response');

      return CaptionSet.fromJson(
          jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Caption generation failed: $e');
    }
  }

  /// Generates a plain-text caption from a freeform prompt (no image needed).
  Future<String> generateCaption(String prompt) async {
    try {
      final data = await _callGemini(_geminiModel, prompt);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text == null) throw Exception('Empty caption response');
      return text;
    } catch (e) {
      throw Exception('Caption generation failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reel Generation — Veo 3.1 via Google AI Studio REST API
  // ─────────────────────────────────────────────────────────────────────────

  static const String _veoModel = 'veo-3.1-generate-preview';

  /// Generates short promotional video reels using Veo 3.1 via AI Studio.
  ///
  /// REST API flow (from official docs):
  ///   1. POST :predictLongRunning  → returns a long-running operation name
  ///   2. GET  {operationName}      → poll every 10 s until done == true
  ///   3. Extract video URI from response.generateVideoResponse.generatedSamples
  ///   4. Download video bytes      → save to temp .mp4 file
  Future<List<String>> generateReels(
      List<File> referenceImageFiles, FoodAnalysis foodAnalysis) async {
    // ── 1. Build prompt with narration cues ──────────────────────────────
    // Veo 3.1 natively generates audio — the docs use single quotes for
    // dialogue and explicit speaker/sound descriptions.
    final ingredientList = foodAnalysis.ingredients.take(3).join(', ');
    final prompt =
        "A cinematic food promotional video. "
        "Close-up shot of ${foodAnalysis.foodName}, a ${foodAnalysis.cuisine} dish, "
        "steam rising from the plate, warm golden lighting. "
        "A professional male narrator with a deep, warm voice speaks clearly: "
        "'Introducing ${foodAnalysis.foodName}. A beloved ${foodAnalysis.cuisine} classic, "
        "crafted with $ingredientList.' "
        "Sizzling sounds, gentle kitchen ambience. "
        "The camera slowly pans across the dish. "
        "The narrator continues speaking: '${foodAnalysis.description}' "
        "Dramatic hero shot of the complete dish, beautifully plated. "
        "The narrator says with passion: 'Taste the tradition.' "
        "9:16 portrait, shallow depth of field, cinematic food photography.";

    // Auth header used by the REST API (NOT query param)
    final authHeaders = {
      'Content-Type': 'application/json',
      'x-goog-api-key': _apiKey,
    };

    // ── 2. Start long-running generation ──────────────────────────────────
    // Endpoint: POST /v1beta/models/{model}:predictLongRunning
    final startUrl = Uri.parse(
        'https://$_geminiHost/v1beta/models/$_veoModel:predictLongRunning');

    // Request body uses "instances" + "parameters" format (NOT prompt/generationConfig)
    final startBody = jsonEncode({
      'instances': [
        {
          'prompt': prompt,
        }
      ],
      'parameters': {
        'aspectRatio': '9:16',
      },
    });

    debugPrint('[Veo] Starting video generation...');
    final startResponse = await http.post(
      startUrl,
      headers: authHeaders,
      body: startBody,
    );

    if (startResponse.statusCode != 200) {
      throw Exception(
          'Veo predictLongRunning error ${startResponse.statusCode}: ${startResponse.body}');
    }

    final startData =
        jsonDecode(startResponse.body) as Map<String, dynamic>;
    final operationName = startData['name'] as String?;
    if (operationName == null) {
      throw Exception(
          'Veo: no operation name in response: ${startResponse.body}');
    }
    debugPrint('[Veo] Operation started: $operationName');

    // ── 3. Poll until done ────────────────────────────────────────────────
    // Max wait: 6 minutes (36 polls × 10 s)
    const maxPolls = 36;
    const pollIntervalSeconds = 10;
    Map<String, dynamic>? completedData;

    for (int i = 0; i < maxPolls; i++) {
      await Future<void>.delayed(
          const Duration(seconds: pollIntervalSeconds));

      // GET /v1beta/{operationName}
      final pollUrl =
          Uri.parse('https://$_geminiHost/v1beta/$operationName');

      debugPrint('[Veo] Polling attempt ${i + 1}/$maxPolls...');
      final pollResponse = await http.get(
        pollUrl,
        headers: {'x-goog-api-key': _apiKey},
      );

      if (pollResponse.statusCode != 200) {
        throw Exception(
            'Veo poll error ${pollResponse.statusCode}: ${pollResponse.body}');
      }

      final pollData =
          jsonDecode(pollResponse.body) as Map<String, dynamic>;
      final isDone = pollData['done'] as bool? ?? false;

      if (pollData.containsKey('error')) {
        throw Exception('Veo operation failed: ${pollData['error']}');
      }

      if (isDone) {
        debugPrint('[Veo] Operation completed!');
        completedData = pollData;
        break;
      }
    }

    if (completedData == null) {
      throw Exception(
          'Veo: timed out after ${maxPolls * pollIntervalSeconds} seconds');
    }

    // ── 4. Extract video URIs ─────────────────────────────────────────────
    // REST response shape:
    //   { response: { generateVideoResponse: { generatedSamples: [ { video: { uri } } ] } } }
    final response = completedData['response'] as Map<String, dynamic>?;
    final generateVideoResponse =
        response?['generateVideoResponse'] as Map<String, dynamic>?;
    final generatedSamples =
        generateVideoResponse?['generatedSamples'] as List?;

    if (generatedSamples == null || generatedSamples.isEmpty) {
      throw Exception(
          'Veo: no videos in completed operation: $completedData');
    }

    // ── 5. Download each video and save to a temp file ────────────────────
    final tmpDir = await Directory.systemTemp.createTemp('veo_reels_');
    final List<String> reelPaths = [];

    for (int i = 0; i < generatedSamples.length; i++) {
      final sample = generatedSamples[i] as Map<String, dynamic>;
      final videoMeta = sample['video'] as Map<String, dynamic>?;
      final videoUri = videoMeta?['uri'] as String?;

      if (videoUri == null) continue;

      debugPrint('[Veo] Downloading video $i from $videoUri');

      // Download with API key in header (following redirects via client)
      final videoResponse = await http.get(
        Uri.parse(videoUri),
        headers: {'x-goog-api-key': _apiKey},
      );

      if (videoResponse.statusCode != 200) {
        debugPrint(
            '[Veo] Download failed for video $i: ${videoResponse.statusCode}');
        continue;
      }

      final videoFile = File('${tmpDir.path}/reel_$i.mp4');
      await videoFile.writeAsBytes(videoResponse.bodyBytes);
      reelPaths.add(videoFile.path);
      debugPrint('[Veo] Saved reel $i to ${videoFile.path}');
    }

    if (reelPaths.isEmpty) {
      throw Exception('Veo: all video downloads failed');
    }

    return reelPaths;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

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