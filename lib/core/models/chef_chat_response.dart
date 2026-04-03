import 'meal_plan.dart';

/// Gemini chatWithChef yanıt sarmalayıcısı.
/// type: "chat" → sadece mesaj, "recipe" → mesaj + tarif.
class ChefChatResponse {
  final String type; // "chat" veya "recipe"
  final String message;
  final Recipe? recipe;

  const ChefChatResponse({
    required this.type,
    required this.message,
    this.recipe,
  });

  bool get isRecipe => type == 'recipe' && recipe != null;

  factory ChefChatResponse.fromMap(Map<String, dynamic> map) {
    Recipe? recipe;
    if (map['type'] == 'recipe' && map['recipe'] is Map<String, dynamic>) {
      recipe = Recipe.fromMap(map['recipe'] as Map<String, dynamic>);
    }
    return ChefChatResponse(
      type: map['type'] as String? ?? 'chat',
      message: map['message'] as String? ?? '',
      recipe: recipe,
    );
  }
}
