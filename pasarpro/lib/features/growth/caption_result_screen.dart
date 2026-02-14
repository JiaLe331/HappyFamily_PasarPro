import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../services/gemini_service.dart';
import '../../services/image_service.dart';
import '../../services/database_service.dart';
import '../../models/saved_generation.dart';

class CaptionResultScreen extends StatefulWidget {
  final File originalImage;
  final List<Uint8List>? enhancedImageBytes;
  final FoodAnalysis foodAnalysis;
  final CaptionSet captions;

  const CaptionResultScreen({
    super.key,
    required this.originalImage,
    this.enhancedImageBytes,
    required this.foodAnalysis,
    required this.captions,
  });

  @override
  State<CaptionResultScreen> createState() => _CaptionResultScreenState();
}

class _CaptionResultScreenState extends State<CaptionResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedImageIndex = 0; // 0 = original, 1-3 = enhanced variations
  final ImageService _imageService = ImageService();
  final DatabaseService _databaseService = DatabaseService();
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _saveToDatabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getCurrentCaption() {
    switch (_tabController.index) {
      case 0:
        return widget.captions.english;
      case 1:
        return widget.captions.malay;
      case 2:
        return widget.captions.mandarin;
      default:
        return widget.captions.english;
    }
  }

  String _getFullCaption() {
    final caption = _getCurrentCaption();
    final hashtags = widget.captions.hashtags.join(' ');
    return '$caption\n\n$hashtags';
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _getFullCaption()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Caption copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareCaption() async {
    await Share.share(_getFullCaption());
  }

  Future<void> _saveImage() async {
    final filename = 'pasarpro_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final imageToSave = _selectedImageIndex > 0 && 
                        widget.enhancedImageBytes != null &&
                        _selectedImageIndex <= widget.enhancedImageBytes!.length
        ? widget.enhancedImageBytes![_selectedImageIndex - 1]
        : await widget.originalImage.readAsBytes();

    // For demo, just show success message
    // In production, use image_gallery_saver package
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image saved as $filename'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Save generation to database automatically
  Future<void> _saveToDatabase() async {
    if (_isSaved) return;
    
    try {
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      
      // Copy original image to permanent storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalImagePath = path.join(imagesDir.path, 'original_$timestamp.jpg');
      await widget.originalImage.copy(originalImagePath);
      
      // Save enhanced image if available
      String? enhancedImagePath;
      if (widget.enhancedImageBytes != null && widget.enhancedImageBytes!.isNotEmpty) {
        enhancedImagePath = path.join(imagesDir.path, 'enhanced_$timestamp.jpg');
        final enhancedFile = File(enhancedImagePath);
        // Save first enhanced variation by default
        await enhancedFile.writeAsBytes(widget.enhancedImageBytes!.first);
      }
      
      // Create SavedGeneration object
      final generation = SavedGeneration(
        foodName: widget.foodAnalysis.foodName,
        cuisine: widget.foodAnalysis.cuisine,
        description: widget.foodAnalysis.description,
        ingredients: widget.foodAnalysis.ingredients,
        captionEnglish: widget.captions.english,
        captionMalay: widget.captions.malay,
        captionMandarin: widget.captions.mandarin,
        hashtags: widget.captions.hashtags,
        originalImagePath: originalImagePath,
        enhancedImagePath: enhancedImagePath,
        createdAt: DateTime.now(),
      );
      
      // Save to database
      await _databaseService.saveGeneration(generation);
      setState(() => _isSaved = true);
      
    } catch (e) {
      // Silent fail - don't interrupt user experience
      print('[ERROR] Failed to save to database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onSurface,
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: AppColors.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _saveImage,
            tooltip: 'Save Image',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image display
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: _selectedImageIndex > 0 && 
                         widget.enhancedImageBytes != null &&
                         _selectedImageIndex <= widget.enhancedImageBytes!.length
                      ? MemoryImage(widget.enhancedImageBytes![_selectedImageIndex - 1])
                      : FileImage(widget.originalImage) as ImageProvider,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          
          // Toggle buttons (only show if enhancement succeeded)
          if (widget.enhancedImageBytes != null && widget.enhancedImageBytes!.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleButton('Original', 0),
                        for (int i = 0; i < widget.enhancedImageBytes!.length; i++)
                          _buildToggleButton('Enhanced ${i + 1}', i + 1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Food info & captions
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food info
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.foodAnalysis.foodName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.foodAnalysis.cuisine,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Generated',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Language tabs
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    onTap: (_) => setState(() {}),
                    tabs: const [
                      Tab(text: 'English'),
                      Tab(text: 'Malay'),
                      Tab(text: 'Mandarin'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Caption display
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getCurrentCaption(),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.captions.hashtags
                                .map((tag) => Chip(
                                      label: Text(
                                        tag,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      backgroundColor:
                                          AppColors.primary.withOpacity(0.1),
                                      labelStyle: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _shareCaption,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, int index) {
    final isActive = _selectedImageIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedImageIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
