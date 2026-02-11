import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

/// Callback for posting progress updates
typedef ProgressCallback = void Function(PostingStep step);

/// Steps in the Instagram posting process
enum PostingStep {
  uploadingImage,    // Uploading to Firebase
  sendingToN8n,      // Sending to n8n webhook
  postingToInstagram, // n8n is posting to Instagram (background)
  success,           // Done!
  failed,            // Something went wrong
}

extension PostingStepInfo on PostingStep {
  String get label {
    switch (this) {
      case PostingStep.uploadingImage:
        return 'Uploading image...';
      case PostingStep.sendingToN8n:
        return 'Connecting to Instagram...';
      case PostingStep.postingToInstagram:
        return 'Publishing to Instagram...';
      case PostingStep.success:
        return 'Posted to Instagram!';
      case PostingStep.failed:
        return 'Failed to post';
    }
  }

  String get description {
    switch (this) {
      case PostingStep.uploadingImage:
        return 'Preparing your photo for upload';
      case PostingStep.sendingToN8n:
        return 'Sending to automation server';
      case PostingStep.postingToInstagram:
        return 'Your post will appear on Instagram shortly';
      case PostingStep.success:
        return 'Check your Instagram profile!';
      case PostingStep.failed:
        return 'Please try again';
    }
  }

  double get progress {
    switch (this) {
      case PostingStep.uploadingImage:
        return 0.25;
      case PostingStep.sendingToN8n:
        return 0.50;
      case PostingStep.postingToInstagram:
        return 0.75;
      case PostingStep.success:
        return 1.0;
      case PostingStep.failed:
        return 0.0;
    }
  }
}

class InstagramService {
  // Read webhook URL from .env file (not committed to git)
  static String get _webhookUrl => dotenv.env['N8N_WEBHOOK_URL'] ?? '';
  
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  /// Posts an image with caption to Instagram via n8n workflow
  /// with progress callbacks for UI updates.
  Future<bool> postToInstagram({
    required File imageFile,
    required String caption,
    ProgressCallback? onProgress,
  }) async {
    try {
      // Step 1: Upload image to Firebase Storage
      onProgress?.call(PostingStep.uploadingImage);
      print('[Instagram] Starting Instagram post process...');
      
      final imageUrl = await _uploadToFirebase(imageFile);
      if (imageUrl == null) {
        print('[Instagram] Failed to upload image to Firebase');
        onProgress?.call(PostingStep.failed);
        return false;
      }
      
      print('[Instagram] Image uploaded to Firebase: $imageUrl');
      
      // Step 2: Send to n8n webhook
      onProgress?.call(PostingStep.sendingToN8n);
      print('[Instagram] Sending post request to n8n...');
      
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'imageUrl': imageUrl,
          'caption': caption,
        }),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timed out. Check n8n connection.');
        },
      );
      
      print('[Instagram] Response status: ${response.statusCode}');
      print('[Instagram] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        // Step 3: n8n is posting in background
        onProgress?.call(PostingStep.postingToInstagram);
        
        // Wait for n8n workflow to complete (~18 seconds with 10s wait)
        // This keeps the dialog visible while Instagram processes
        await Future.delayed(const Duration(seconds: 20));
        
        onProgress?.call(PostingStep.success);
        return true;
      }
      
      onProgress?.call(PostingStep.failed);
      return false;
    } catch (e) {
      print('[Instagram] Error: $e');
      onProgress?.call(PostingStep.failed);
      return false;
    }
  }
  
  /// Upload image to Firebase Storage and return public URL
  Future<String?> _uploadToFirebase(File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'instagram_posts/$timestamp.jpg';
      
      final ref = _storage.ref().child(filename);
      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploaded_at': timestamp.toString()},
        ),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
      
    } catch (e) {
      print('[Instagram] Firebase upload error: $e');
      return null;
    }
  }
  
  /// Test webhook connectivity
  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse(_webhookUrl));
      return response.statusCode == 200 || response.statusCode == 405;
    } catch (e) {
      print('[Instagram] Connection test failed: $e');
      return false;
    }
  }
}
