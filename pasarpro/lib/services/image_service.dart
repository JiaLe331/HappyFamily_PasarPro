import 'dart:io';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class ImageService {
  final ImagePicker _picker = ImagePicker();
  
  /// Capture photo using device camera
  Future<File?> capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Compress to reduce file size
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (photo == null) return null;
      
      return File(photo.path);
    } catch (e) {
      // Camera capture failed
      return null;
    }
  }
  
  /// Pick image from gallery
  Future<File?> pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      if (image == null) return null;
      
      return File(image.path);
    } catch (e) {
      // Gallery picker failed
      return null;
    }
  }
  
  /// Compress image to reduce file size (for API upload)
  Future<File> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // Resize if too large
      final resized = img.copyResize(
        image,
        width: image.width > 1920 ? 1920 : null,
        height: image.height > 1920 ? 1920 : null,
      );
      
      // Compress as JPEG
      final compressed = img.encodeJpg(resized, quality: 85);
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressed);
      
      return tempFile;
    } catch (e) {
      // Compression failed, return original
      return imageFile;
    }
  }
  
  /// Save image to device gallery
  Future<bool> saveToGallery(File imageFile, String filename) async {
    try {
      // For Android, we'll use the app's documents directory
      // In production, you'd use a package like 'gal' or 'image_gallery_saver'
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/$filename';
      
      await imageFile.copy(path);
      return true;
    } catch (e) {
      // Save failed
      return false;
    }
  }
  
  /// Get list of available cameras
  static Future<List<CameraDescription>> getAvailableCameras() async {
    try {
      return await availableCameras();
    } catch (e) {
      // Failed to get cameras
      return [];
    }
  }
}
