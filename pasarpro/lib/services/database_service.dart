import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/saved_generation.dart';
import '../models/saved_poster.dart';

/// Service for managing local database storage of AI generations
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  /// Get database instance (create if doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'pasarpro.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE generations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        foodName TEXT NOT NULL,
        cuisine TEXT NOT NULL,
        description TEXT NOT NULL,
        ingredients TEXT NOT NULL,
        captionEnglish TEXT NOT NULL,
        captionMalay TEXT NOT NULL,
        captionMandarin TEXT NOT NULL,
        hashtags TEXT NOT NULL,
        originalImagePath TEXT NOT NULL,
        enhancedImagePaths TEXT,
        reelPaths TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS posters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        itemName TEXT NOT NULL,
        price TEXT NOT NULL,
        promoText TEXT NOT NULL,
        aiCaption TEXT NOT NULL,
        templateName TEXT NOT NULL,
        originalImagePath TEXT NOT NULL,
        posterImagePath TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate from single enhancedImagePath to multiple enhancedImagePaths
      await db.execute('''
        ALTER TABLE generations RENAME COLUMN enhancedImagePath TO enhancedImagePaths
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        ALTER TABLE generations ADD COLUMN reelPaths TEXT
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS posters (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          itemName TEXT NOT NULL,
          price TEXT NOT NULL,
          promoText TEXT NOT NULL,
          aiCaption TEXT NOT NULL,
          templateName TEXT NOT NULL,
          originalImagePath TEXT NOT NULL,
          posterImagePath TEXT NOT NULL,
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  /// Save a new generation
  Future<int> saveGeneration(SavedGeneration generation) async {
    final db = await database;
    return await db.insert('generations', generation.toMap());
  }

  /// Get all generations (newest first)
  Future<List<SavedGeneration>> getAllGenerations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'generations',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return SavedGeneration.fromMap(maps[i]);
    });
  }

  /// Get generation by ID
  Future<SavedGeneration?> getGenerationById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'generations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavedGeneration.fromMap(maps.first);
  }

  /// Search generations by food name or cuisine
  Future<List<SavedGeneration>> searchGenerations(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'generations',
      where: 'foodName LIKE ? OR cuisine LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return SavedGeneration.fromMap(maps[i]);
    });
  }

  /// Delete a generation
  Future<int> deleteGeneration(int id) async {
    final db = await database;

    // Get the generation to delete associated images
    final generation = await getGenerationById(id);
    if (generation != null) {
      // Delete original image file
      try {
        final originalFile = File(generation.originalImagePath);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }
      } catch (e) {
        // Ignore file deletion errors
      }

      // Delete enhanced image files if exist
      if (generation.enhancedImagePaths.isNotEmpty) {
        for (final enhancedPath in generation.enhancedImagePaths) {
          try {
            final enhancedFile = File(enhancedPath);
            if (await enhancedFile.exists()) {
              await enhancedFile.delete();
            }
          } catch (e) {
            // Ignore file deletion errors
          }
        }
      }

      // Delete reel files if exist
      if (generation.reelPaths.isNotEmpty) {
        for (final reelPath in generation.reelPaths) {
          try {
            final reelFile = File(reelPath);
            if (await reelFile.exists()) {
              await reelFile.delete();
            }
          } catch (e) {
            // Ignore file deletion errors
          }
        }
      }
    }

    return await db.delete('generations', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // POSTERS
  // ==========================================

  /// Save a new poster
  Future<int> savePoster(SavedPoster poster) async {
    final db = await database;
    return await db.insert('posters', poster.toMap());
  }

  /// Get all posters (newest first)
  Future<List<SavedPoster>> getAllPosters() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posters',
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) {
      return SavedPoster.fromMap(maps[i]);
    });
  }

  /// Get poster by ID
  Future<SavedPoster?> getPosterById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'posters',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return SavedPoster.fromMap(maps.first);
  }

  /// Delete a poster
  Future<int> deletePoster(int id) async {
    final db = await database;

    // Get the poster to delete associated images
    final poster = await getPosterById(id);
    if (poster != null) {
      // Delete original image file
      try {
        final originalFile = File(poster.originalImagePath);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }
      } catch (e) {
        // Ignore file deletion errors
      }

      // Delete poster image file
      try {
        final posterFile = File(poster.posterImagePath);
        if (await posterFile.exists()) {
          await posterFile.delete();
        }
      } catch (e) {
        // Ignore file deletion errors
      }
    }

    return await db.delete('posters', where: 'id = ?', whereArgs: [id]);
  }

  /// Update a generation
  Future<int> updateGeneration(SavedGeneration generation) async {
    final db = await database;
    return await db.update(
      'generations',
      generation.toMap(),
      where: 'id = ?',
      whereArgs: [generation.id],
    );
  }

  /// Get total count of generations
  Future<int> getGenerationCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM generations',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all generations (for testing/reset)
  Future<void> clearAllGenerations() async {
    final db = await database;
    await db.delete('generations');
  }
}
