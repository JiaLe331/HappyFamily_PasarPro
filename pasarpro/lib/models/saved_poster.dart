import '../services/poster_service.dart';

/// Model for a saved generated poster
class SavedPoster {
  final int? id;
  final String itemName;
  final String price;
  final String promoText;
  final String aiCaption;
  final PosterTemplate template;
  final String originalImagePath;
  final String posterImagePath;
  final DateTime createdAt;

  SavedPoster({
    this.id,
    required this.itemName,
    required this.price,
    required this.promoText,
    required this.aiCaption,
    required this.template,
    required this.originalImagePath,
    required this.posterImagePath,
    required this.createdAt,
  });

  /// Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'price': price,
      'promoText': promoText,
      'aiCaption': aiCaption,
      'templateName': template.name,
      'originalImagePath': originalImagePath,
      'posterImagePath': posterImagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from Map (database row)
  factory SavedPoster.fromMap(Map<String, dynamic> map) {
    return SavedPoster(
      id: map['id'] as int?,
      itemName: map['itemName'] as String,
      price: map['price'] as String,
      promoText: map['promoText'] as String,
      aiCaption: map['aiCaption'] as String,
      template: PosterTemplate.values.firstWhere(
        (e) => e.name == map['templateName'] as String,
        orElse: () => PosterTemplate.flashSale, // default fallback
      ),
      originalImagePath: map['originalImagePath'] as String,
      posterImagePath: map['posterImagePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// Copy with method for updates
  SavedPoster copyWith({
    int? id,
    String? itemName,
    String? price,
    String? promoText,
    String? aiCaption,
    PosterTemplate? template,
    String? originalImagePath,
    String? posterImagePath,
    DateTime? createdAt,
  }) {
    return SavedPoster(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      price: price ?? this.price,
      promoText: promoText ?? this.promoText,
      aiCaption: aiCaption ?? this.aiCaption,
      template: template ?? this.template,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      posterImagePath: posterImagePath ?? this.posterImagePath,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
