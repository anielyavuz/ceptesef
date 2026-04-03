import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcının bir tarifle olan etkileşimini temsil eder.
/// Fire-and-forget olarak Firestore'a yazılır.
class RecipeInteraction {
  final String recipeId;
  final String recipeName;

  /// viewed, cooked, saved, added_to_plan, replaced, skipped, rated
  final String action;

  final List<String> mutfaklar;
  final String ogunTipi;
  final String zorluk;

  /// Sadece 'rated' action için (1=beğenmedi, 2=iyi, 3=bayıldı)
  final int? rating;

  /// Sadece 'viewed' action için (saniye)
  final int? timeSpentSeconds;

  final DateTime timestamp;

  const RecipeInteraction({
    required this.recipeId,
    required this.recipeName,
    required this.action,
    this.mutfaklar = const [],
    this.ogunTipi = '',
    this.zorluk = '',
    this.rating,
    this.timeSpentSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'recipeName': recipeName,
      'action': action,
      'mutfaklar': mutfaklar,
      'ogunTipi': ogunTipi,
      'zorluk': zorluk,
      if (rating != null) 'rating': rating,
      if (timeSpentSeconds != null) 'timeSpentSeconds': timeSpentSeconds,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }

  factory RecipeInteraction.fromMap(Map<String, dynamic> map) {
    return RecipeInteraction(
      recipeId: map['recipeId'] as String? ?? '',
      recipeName: map['recipeName'] as String? ?? '',
      action: map['action'] as String? ?? '',
      mutfaklar: List<String>.from(map['mutfaklar'] ?? []),
      ogunTipi: map['ogunTipi'] as String? ?? '',
      zorluk: map['zorluk'] as String? ?? '',
      rating: map['rating'] as int?,
      timeSpentSeconds: map['timeSpentSeconds'] as int?,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
