/// Model for a saved AI generation (photo + captions)
class SavedGeneration {
  final int? id;
  final String foodName;
  final String cuisine;
  final String description;
  final List<String> ingredients;
  final String captionEnglish;
  final String captionMalay;
  final String captionMandarin;
  final List<String> hashtags;
  final String originalImagePath;
  final List<String> enhancedImagePaths;
  final DateTime createdAt;
  
  SavedGeneration({
    this.id,
    required this.foodName,
    required this.cuisine,
    required this.description,
    required this.ingredients,
    required this.captionEnglish,
    required this.captionMalay,
    required this.captionMandarin,
    required this.hashtags,
    required this.originalImagePath,
    this.enhancedImagePaths = const [],
    required this.createdAt,
  });
  
  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'foodName': foodName,
      'cuisine': cuisine,
      'description': description,
      'ingredients': ingredients.join('|'), // Store as pipe-separated string
      'captionEnglish': captionEnglish,
      'captionMalay': captionMalay,
      'captionMandarin': captionMandarin,
      'hashtags': hashtags.join('|'),
      'originalImagePath': originalImagePath,
      'enhancedImagePaths': enhancedImagePaths.join('|'),
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  /// Create from Map (database row)
  factory SavedGeneration.fromMap(Map<String, dynamic> map) {
    return SavedGeneration(
      id: map['id'] as int?,
      foodName: map['foodName'] as String,
      cuisine: map['cuisine'] as String,
      description: map['description'] as String,
      ingredients: (map['ingredients'] as String).split('|'),
      captionEnglish: map['captionEnglish'] as String,
      captionMalay: map['captionMalay'] as String,
      captionMandarin: map['captionMandarin'] as String,
      hashtags: (map['hashtags'] as String).split('|'),
      originalImagePath: map['originalImagePath'] as String,
      enhancedImagePaths: (map['enhancedImagePaths'] as String?)?.split('|').where((s) => s.isNotEmpty).toList() ?? [],
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
  
  /// Copy with method for updates
  SavedGeneration copyWith({
    int? id,
    String? foodName,
    String? cuisine,
    String? description,
    List<String>? ingredients,
    String? captionEnglish,
    String? captionMalay,
    String? captionMandarin,
    List<String>? hashtags,
    String? originalImagePath,
    List<String>? enhancedImagePaths,
    DateTime? createdAt,
  }) {
    return SavedGeneration(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      cuisine: cuisine ?? this.cuisine,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      captionEnglish: captionEnglish ?? this.captionEnglish,
      captionMalay: captionMalay ?? this.captionMalay,
      captionMandarin: captionMandarin ?? this.captionMandarin,
      hashtags: hashtags ?? this.hashtags,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      enhancedImagePaths: enhancedImagePaths ?? this.enhancedImagePaths,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
