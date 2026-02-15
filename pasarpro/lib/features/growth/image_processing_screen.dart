import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../services/ai_service.dart';
import '../../services/image_service.dart';
import '../gallery/generation_detail_screen.dart';

class ImageProcessingScreen extends StatefulWidget {
  final File imageFile;

  const ImageProcessingScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<ImageProcessingScreen> createState() => _ImageProcessingScreenState();
}

class _ImageProcessingScreenState extends State<ImageProcessingScreen> {
  final GeminiService _geminiService = GeminiService();
  final ImageService _imageService = ImageService();

  // Processing states
  bool _isAnalyzing = false;
  bool _isEnhancing = false;
  bool _isGeneratingCaptions = false;
  
  // Results
  FoodAnalysis? _foodAnalysis;
  List<Uint8List>? _enhancedImageBytes;
  CaptionSet? _captions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  Future<void> _startProcessing() async {
    // Step 1: Analyze food
    await _analyzeFood();
    
    // Step 2: Enhance image
    if (_foodAnalysis != null) {
      await _enhanceImage();
    }
    
    // Step 3: Generate captions
    if (_foodAnalysis != null) {
      await _generateCaptions();
    }
    
    // Navigate to results if successful
    if (_foodAnalysis != null && _captions != null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GenerationDetailScreen(
            originalImage: widget.imageFile,
            enhancedImageBytes: _enhancedImageBytes,
            foodAnalysis: _foodAnalysis!,
            captions: _captions!,
          ),
        ),
      );
    }
  }

  Future<void> _analyzeFood() async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final analysis = await _geminiService.analyzeFood(widget.imageFile);
      setState(() {
        _foodAnalysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Food analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _enhanceImage() async {
    setState(() => _isEnhancing = true);

    try {
      final enhanced = await _geminiService.enhanceImage(widget.imageFile);
      setState(() {
        _enhancedImageBytes = enhanced;
        _isEnhancing = false;
      });
    } catch (e) {
      // Enhancement failed, continue without enhanced image
      setState(() => _isEnhancing = false);
    }
  }

  Future<void> _generateCaptions() async {
    setState(() => _isGeneratingCaptions = true);

    try {
      final captions = await _geminiService.generateCaptions(
        _foodAnalysis!.foodName,
        _foodAnalysis!.description,
      );
      setState(() {
        _captions = captions;
        _isGeneratingCaptions = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Caption generation failed: $e';
        _isGeneratingCaptions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.onSurface,
      appBar: AppBar(
        title: const Text('Processing...'),
        backgroundColor: AppColors.onSurface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Image preview
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: FileImage(widget.imageFile),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            // Processing status
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: _error != null
                    ? _buildErrorState()
                    : _buildProcessingSteps(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Processing',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        _buildProcessStep(
          icon: Icons.search_rounded,
          title: 'Analyzing Food',
          subtitle: _foodAnalysis != null
              ? 'Found: ${_foodAnalysis!.foodName}'
              : 'Identifying dish, cuisine, ingredients...',
          isActive: _isAnalyzing,
          isDone: _foodAnalysis != null,
        ),
        const SizedBox(height: 16),
        _buildProcessStep(
          icon: Icons.auto_fix_high_rounded,
          title: 'Enhancing Image',
          subtitle: _enhancedImageBytes != null
              ? 'Image enhanced successfully'
              : 'Cleaning background & improving lighting...',
          isActive: _isEnhancing,
          isDone: _enhancedImageBytes != null,
        ),
        const SizedBox(height: 16),
        _buildProcessStep(
          icon: Icons.translate_rounded,
          title: 'Generating Captions',
          subtitle: _captions != null
              ? 'Captions ready in 3 languages'
              : 'Creating EN/MY/ZH captions...',
          isActive: _isGeneratingCaptions,
          isDone: _captions != null,
        ),
      ],
    );
  }

  Widget _buildProcessStep({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required bool isDone,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.primary
                : isActive
                    ? AppColors.primary.withOpacity(0.2)
                    : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: isActive && !isDone
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : Icon(
                  isDone ? Icons.check_rounded : icon,
                  color: isDone ? Colors.white : Colors.grey.shade400,
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDone || isActive
                      ? AppColors.onSurface
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 64,
          color: Colors.red.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          'Processing Failed',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Unknown error',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
