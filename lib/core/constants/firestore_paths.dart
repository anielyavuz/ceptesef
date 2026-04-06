/// Firestore koleksiyon ve doküman yollarını tutan sabitler sınıfı
class FirestorePaths {
  FirestorePaths._();

  /// Sistem konfigürasyonu koleksiyonu
  static const String systemCollection = 'system';

  /// Genel uygulama ayarları dokümanı
  static const String generalDoc = 'general';

  /// Kullanıcılar koleksiyonu
  static const String usersCollection = 'users';

  /// Bildirimler alt koleksiyonu (users/{uid}/notifications)
  static const String notificationsSubcollection = 'notifications';

  /// Yemek planları alt koleksiyonu (users/{uid}/meal_plans)
  static const String mealPlansSubcollection = 'meal_plans';

  /// Günlük planlar alt koleksiyonu (users/{uid}/daily_plans)
  static const String dailyPlansSubcollection = 'daily_plans';

  /// Kaydedilen tarifler alt koleksiyonu (users/{uid}/saved_recipes)
  static const String savedRecipesSubcollection = 'saved_recipes';

  /// Tarif etkileşimleri alt koleksiyonu (users/{uid}/recipe_interactions)
  static const String recipeInteractionsSubcollection = 'recipe_interactions';

  /// Alışveriş listeleri alt koleksiyonu (users/{uid}/shopping_lists)
  static const String shoppingListsSubcollection = 'shopping_lists';

  /// Tarif havuzu koleksiyonu (tarifler/{mutfak_id})
  /// Her doc bir mutfak türü, içinde recipes dizisi
  static const String tariflerCollection = 'tarifler';

  /// Market fiyatları koleksiyonu (marketFiyatlar/{YYYYMMDD})
  static const String marketFiyatlarCollection = 'marketFiyatlar';

  /// Market kategorileri alt koleksiyonu (marketFiyatlar/{YYYYMMDD}/kategoriler)
  static const String marketKategorilerSubcollection = 'kategoriler';

  /// Tarif etiketleri alt koleksiyonu (users/{uid}/recipe_tags)
  static const String recipeTagsSubcollection = 'recipe_tags';

  /// Aile planı (household) koleksiyonu
  static const String householdsCollection = 'households';
}
