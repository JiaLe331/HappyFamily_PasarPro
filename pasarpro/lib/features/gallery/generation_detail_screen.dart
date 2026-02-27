import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../models/saved_generation.dart';
import '../../services/database_service.dart';
import '../../services/instagram_service.dart';
import '../../services/ai_service.dart';
import '../../services/background_reel_service.dart';
import '../growth/reel_generation_screen.dart';
import '../templates/poster_generator_screen.dart';
import '../../services/poster_service.dart';

enum ReelGenerationState { notGenerated, generating, generated }

class GenerationDetailScreen extends StatefulWidget {
  final SavedGeneration? generation; // null if newly generated
  final File? originalImage; // for newly generated
  final List<Uint8List>? enhancedImageBytes; // for newly generated
  final FoodAnalysis? foodAnalysis; // for newly generated
  final CaptionSet? captions; // for newly generated

  const GenerationDetailScreen({
    super.key,
    this.generation,
    this.originalImage,
    this.enhancedImageBytes,
    this.foodAnalysis,
    this.captions,
  }) : assert(
         (generation != null) ||
             (originalImage != null &&
                 foodAnalysis != null &&
                 captions != null),
         'Either generation or (originalImage, foodAnalysis, captions) must be provided',
       );

  @override
  State<GenerationDetailScreen> createState() => _GenerationDetailScreenState();
}

class _GenerationDetailScreenState extends State<GenerationDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedImageIndex = 0;
  final DatabaseService _databaseService = DatabaseService();
  final InstagramService _instagramService = InstagramService();
  final AiService _aiService = AiService();
  bool _isSaved = false;
  bool _isPostingToInstagram = false;
  void Function(void Function())? _dialogSetState;
  PostingStep _currentStep = PostingStep.uploadingImage;
  ReelGenerationState _reelGenerationState = ReelGenerationState.notGenerated;

  bool get _isNewlyGenerated => widget.generation == null;

  SavedGeneration? _savedGeneration;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    if (_isNewlyGenerated) {
      _saveToDatabase();
    } else {
      _isSaved = true;
      _savedGeneration = widget.generation;
      // Check if reels already exist for this generation
      if (widget.generation!.reelPaths.isNotEmpty) {
        _reelGenerationState = ReelGenerationState.generated;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  FoodAnalysis _getFoodAnalysis() {
    final generation = _savedGeneration ?? widget.generation;
    return widget.foodAnalysis ??
        FoodAnalysis(
          foodName: generation!.foodName,
          cuisine: generation.cuisine,
          description: generation.description,
          ingredients: generation.ingredients,
        );
  }

  String _getCurrentCaption() {
    final generation = _savedGeneration ?? widget.generation;
    switch (_tabController.index) {
      case 0:
        return generation!.captionEnglish;
      case 1:
        return generation!.captionMalay;
      case 2:
        return generation!.captionMandarin;
      default:
        return generation!.captionEnglish;
    }
  }

  String _getFullCaption() {
    final caption = _getCurrentCaption();
    final generation = _savedGeneration ?? widget.generation;
    final hashtags = generation!.hashtags.join(' ');
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

  Future<void> _sharePost() async {
    final generation = _savedGeneration ?? widget.generation;
    File? imageToShare;

    if (generation != null) {
      imageToShare =
          _selectedImageIndex > 0 &&
              generation.enhancedImagePaths.isNotEmpty &&
              _selectedImageIndex <= generation.enhancedImagePaths.length
          ? File(generation.enhancedImagePaths[_selectedImageIndex - 1])
          : File(generation.originalImagePath);
    } else if (_isNewlyGenerated) {
      if (_selectedImageIndex > 0 &&
          widget.enhancedImageBytes != null &&
          widget.enhancedImageBytes!.isNotEmpty &&
          _selectedImageIndex <= widget.enhancedImageBytes!.length) {
        imageToShare = await _createTempFile(
          widget.enhancedImageBytes![_selectedImageIndex - 1],
        );
      } else if (widget.originalImage != null) {
        imageToShare = widget.originalImage;
      }
    }

    if (imageToShare == null) {
      await Share.share(_getFullCaption());
      return;
    }

    await Share.shareXFiles([
      XFile(imageToShare.path),
    ], text: _getFullCaption());
  }

  Future<void> _saveImage() async {
    final filename = 'pasarpro_${DateTime.now().millisecondsSinceEpoch}.jpg';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Image saved as $filename'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveToDatabase() async {
    if (_isSaved || _isNewlyGenerated && widget.originalImage == null) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final originalImagePath = path.join(
        imagesDir.path,
        'original_$timestamp.jpg',
      );
      await widget.originalImage!.copy(originalImagePath);

      List<String> enhancedImagePaths = [];
      if (widget.enhancedImageBytes != null &&
          widget.enhancedImageBytes!.isNotEmpty) {
        for (int i = 0; i < widget.enhancedImageBytes!.length; i++) {
          final enhancedPath = path.join(
            imagesDir.path,
            'enhanced_${timestamp}_$i.jpg',
          );
          final enhancedFile = File(enhancedPath);
          await enhancedFile.writeAsBytes(widget.enhancedImageBytes![i]);
          enhancedImagePaths.add(enhancedPath);
        }
      }

      final generation = SavedGeneration(
        foodName: widget.foodAnalysis!.foodName,
        cuisine: widget.foodAnalysis!.cuisine,
        description: widget.foodAnalysis!.description,
        ingredients: widget.foodAnalysis!.ingredients,
        captionEnglish: widget.captions!.english,
        captionMalay: widget.captions!.malay,
        captionMandarin: widget.captions!.mandarin,
        hashtags: widget.captions!.hashtags,
        originalImagePath: originalImagePath,
        enhancedImagePaths: enhancedImagePaths,
        createdAt: DateTime.now(),
      );

      final generationId = await _databaseService.saveGeneration(generation);
      setState(() {
        _savedGeneration = generation.copyWith(id: generationId);
        _isSaved = true;
      });
    } catch (e) {
      print('[ERROR] Failed to save to database: $e');
    }
  }

  Future<bool> _saveReelsToDatabase(List<Uint8List> reelBytesList) async {
    if (_savedGeneration == null) return false;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final reelsDir = Directory(path.join(appDir.path, 'reels'));
      if (!await reelsDir.exists()) {
        await reelsDir.create(recursive: true);
      }

      List<String> reelPaths = [];
      for (int i = 0; i < reelBytesList.length; i++) {
        final reelPath = path.join(
          reelsDir.path,
          'reel_${_savedGeneration!.id}_${DateTime.now().millisecondsSinceEpoch}_$i.mp4',
        );
        final reelFile = File(reelPath);
        await reelFile.writeAsBytes(reelBytesList[i]);
        reelPaths.add(reelPath);
      }

      final updatedGeneration = _savedGeneration!.copyWith(
        reelPaths: [..._savedGeneration!.reelPaths, ...reelPaths],
      );

      await _databaseService.updateGeneration(updatedGeneration);
      setState(() {
        _savedGeneration = updatedGeneration;
      });

      return true;
    } catch (e) {
      print('[ERROR] Failed to save reels to database: $e');
      return false;
    }
  }

  Future<void> _postToInstagram() async {
    setState(() => _isPostingToInstagram = true);
    _currentStep = PostingStep.uploadingImage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            _dialogSetState = setDialogState;
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFFF58529),
                          Color(0xFFDD2A7B),
                          Color(0xFF8134AF),
                          Color(0xFF515BD4),
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _currentStep == PostingStep.success
                        ? '🎉 Posted!'
                        : _currentStep == PostingStep.failed
                        ? '❌ Failed'
                        : 'Posting to Instagram',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _currentStep.progress,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentStep == PostingStep.failed
                            ? Colors.red
                            : _currentStep == PostingStep.success
                            ? Colors.green
                            : AppColors.primary,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildStepRow(
                    PostingStep.uploadingImage,
                    Icons.cloud_upload_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(PostingStep.sendingToN8n, Icons.sync),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    PostingStep.postingToInstagram,
                    Icons.send_rounded,
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    PostingStep.success,
                    Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentStep.description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final generation = _savedGeneration ?? widget.generation!;
      final imageToPost =
          _selectedImageIndex > 0 &&
              _selectedImageIndex <= generation.enhancedImagePaths.length
          ? File(generation.enhancedImagePaths[_selectedImageIndex - 1])
          : File(generation.originalImagePath);

      await _instagramService.postToInstagram(
        imageFile: imageToPost,
        caption: _getFullCaption(),
        onProgress: (step) {
          if (mounted && _dialogSetState != null) {
            _dialogSetState!(() {
              _currentStep = step;
            });
          }
        },
      );

      if (mounted) {
        await Future.delayed(Duration(seconds: 2));
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      print('[ERROR] Instagram post error: $e');
      if (mounted) {
        if (_dialogSetState != null) {
          _dialogSetState!(() {
            _currentStep = PostingStep.failed;
          });
        }
        await Future.delayed(Duration(seconds: 2));
        Navigator.of(context, rootNavigator: true).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingToInstagram = false);
      }
    }
  }

  Widget _buildStepRow(PostingStep step, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep.progress > step.progress;
    final isFailed = _currentStep == PostingStep.failed;

    Color color;
    if (isFailed) {
      color = Colors.grey.shade400;
    } else if (isCompleted) {
      color = Colors.green;
    } else if (isActive) {
      color = AppColors.primary;
    } else {
      color = Colors.grey.shade300;
    }

    return Row(
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withOpacity(0.1)
                : isActive
                ? AppColors.primary.withOpacity(0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: isCompleted
              ? Icon(Icons.check, color: Colors.green, size: 18)
              : Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            step.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: isActive || isCompleted
                  ? Colors.black87
                  : Colors.grey.shade400,
            ),
          ),
        ),
        if (isActive && !isFailed && step != PostingStep.success)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
      ],
    );
  }

  Future<File> _createTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_instagram_post.jpg');
    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  Future<void> _generateReels() async {
    final generation = _savedGeneration ?? widget.generation;
    if (generation == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Generation not available')));
      return;
    }

    if (BackgroundReelService().isGenerating(generation.id!)) {
      return;
    }

    List<File> images = [];
    for (String path
        in generation.enhancedImagePaths.isNotEmpty
            ? generation.enhancedImagePaths
            : [generation.originalImagePath]) {
      images.add(File(path));
    }

    BackgroundReelService().generateReelsFor(
      generation,
      _getFoodAnalysis(),
      images,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reel generating... Please wait around 3 minutes and check back later.',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _navigateToPosterGenerator(SavedGeneration generation) {
    final imageFile = File(
      _selectedImageIndex > 0 &&
              generation.enhancedImagePaths.isNotEmpty &&
              _selectedImageIndex <= generation.enhancedImagePaths.length
          ? generation.enhancedImagePaths[_selectedImageIndex - 1]
          : generation.originalImagePath,
    );

    Uint8List? imageBytes;
    if (imageFile.existsSync()) {
      imageBytes = imageFile.readAsBytesSync();
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PosterGeneratorScreen(
          initialTemplate: PosterTemplate.flashSale,
          initialImageBytes: imageBytes,
          initialItemName: generation.foodName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final generation = _savedGeneration ?? widget.generation;
    final dateFormat = DateFormat('MMMM d, y \'at\' h:mm a');

    if (generation == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final imageFile = File(
      _selectedImageIndex > 0 &&
              generation.enhancedImagePaths.isNotEmpty &&
              _selectedImageIndex <= generation.enhancedImagePaths.length
          ? generation.enhancedImagePaths[_selectedImageIndex - 1]
          : generation.originalImagePath,
    );

    return Scaffold(
      backgroundColor: AppColors.onSurface,
      appBar: AppBar(
        title: const Text('Generation Details'),
        backgroundColor: AppColors.onSurface,
        actions: [
          if (!_isNewlyGenerated)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _saveImage,
              tooltip: 'Save Image',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Image display
          Column(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16).copyWith(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: FileImage(imageFile),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              if (generation.enhancedImagePaths.isNotEmpty)
                Container(
                  padding: const EdgeInsets.only(bottom: 20),
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
                            for (
                              int i = 0;
                              i < generation.enhancedImagePaths.length;
                              i++
                            )
                              _buildToggleButton('Enhanced ${i + 1}', i + 1),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 350), // Space for collapsed sheet
            ],
          ),
          // Draggable Food info & captions
          DraggableScrollableSheet(
            initialChildSize: 0.4,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      generation.foodName,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      generation.cuisine,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateFormat.format(generation.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
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
                            children: generation.hashtags
                                .map(
                                  (tag) => Chip(
                                    label: Text(
                                      tag,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    backgroundColor: AppColors.primary
                                        .withOpacity(0.1),
                                    labelStyle: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: BackgroundReelService(),
                                builder: (context, child) {
                                  final isBgGenerating = BackgroundReelService()
                                      .isGenerating(generation.id!);
                                  final hasReels =
                                      generation.reelPaths.isNotEmpty;

                                  return Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: isBgGenerating
                                          ? null
                                          : (hasReels
                                                ? () {
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ReelGenerationScreen(
                                                              reelPaths:
                                                                  generation
                                                                      .reelPaths,
                                                            ),
                                                      ),
                                                    );
                                                  }
                                                : _generateReels),
                                      icon: isBgGenerating
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Icon(
                                              hasReels
                                                  ? Icons
                                                        .play_circle_outline_rounded
                                                  : Icons.video_library_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        isBgGenerating
                                            ? 'Generating...'
                                            : hasReels
                                            ? 'View Reels'
                                            : 'Gen Reels',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _navigateToPosterGenerator(generation),
                                  icon: const Icon(
                                    Icons.art_track_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Gen Poster'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isPostingToInstagram
                                  ? null
                                  : _postToInstagram,
                              icon: _isPostingToInstagram
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(Icons.camera_alt_rounded, size: 18),
                              label: Text(
                                _isPostingToInstagram
                                    ? 'Posting...'
                                    : 'Post to Instagram',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _copyToClipboard,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Copy Caption'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: BorderSide(color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _sharePost,
                                  icon: const Icon(
                                    Icons.share_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
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
