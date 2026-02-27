import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../models/saved_generation.dart';
import 'ai_service.dart';
import 'database_service.dart';
import 'notification_service.dart';

class BackgroundReelService extends ChangeNotifier {
  static final BackgroundReelService _instance =
      BackgroundReelService._internal();
  factory BackgroundReelService() => _instance;
  BackgroundReelService._internal();

  final Set<int> _generatingIds = {};
  final AiService _aiService = AiService();
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  bool isGenerating(int generationId) {
    return _generatingIds.contains(generationId);
  }

  Future<void> generateReelsFor(
    SavedGeneration generation,
    FoodAnalysis foodAnalysis,
    List<File> images,
  ) async {
    final int genId = generation.id!;
    if (_generatingIds.contains(genId)) return;

    _generatingIds.add(genId);
    notifyListeners();

    try {
      final reelsBytes = await _aiService.generateReels(images, foodAnalysis);

      if (reelsBytes.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        final reelsDir = Directory(path.join(appDir.path, 'reels'));
        if (!await reelsDir.exists()) {
          await reelsDir.create(recursive: true);
        }

        List<String> reelPaths = [];
        for (int i = 0; i < reelsBytes.length; i++) {
          final reelPath = path.join(
            reelsDir.path,
            'reel_${genId}_${DateTime.now().millisecondsSinceEpoch}_$i.mp4',
          );
          final reelFile = File(reelPath);
          await reelFile.writeAsBytes(reelsBytes[i]);
          reelPaths.add(reelPath);
        }

        final updatedGeneration = generation.copyWith(
          reelPaths: [...generation.reelPaths, ...reelPaths],
        );

        await _databaseService.updateGeneration(updatedGeneration);

        await _notificationService.showNotification(
          id: genId,
          title: 'Reel ready!',
          body:
              'Your AI reels for ${generation.foodName} have been generated successfully.',
        );
      } else {
        await _notificationService.showNotification(
          id: genId,
          title: 'Reel generation failed',
          body: 'We could not generate reels for ${generation.foodName}.',
        );
      }
    } catch (e) {
      print('[BackgroundReelService] Error generating reels for $genId: $e');
      await _notificationService.showNotification(
        id: genId,
        title: 'Reel generation error',
        body:
            'An error occurred while generating reels for ${generation.foodName}.',
      );
    } finally {
      _generatingIds.remove(genId);
      notifyListeners();
    }
  }
}
