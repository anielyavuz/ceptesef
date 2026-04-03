import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../models/meal_plan.dart';
import '../models/user_preferences.dart';
import 'remote_logger_service.dart';

/// Gemini'dan üretilen tarifleri Firestore'da cache'leyen servis.
///
/// Firestore yapısı:
/// ```
/// tarifler/{mutfak_id}
///   recipes: [
///     { id, yemek_adi, ogun_tipi, mutfaklar, alerjenler, diyetler, zorluk, toplam_sure_dk, kisi_sayisi }
///   ]
///   updatedAt: Timestamp
/// ```
///
/// Her mutfak türü bir doc, içinde tarif dizisi.
/// Bu sayede tek read ile bir mutfağın tüm tariflerine erişilir.
class RecipeCacheService {
  final FirebaseFirestore _firestore;

  RecipeCacheService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Bir MealPlan'daki tüm tarifleri cache'e yazar.
  /// Her tarif, birincil mutfağının doc'una eklenir.
  Future<void> cacheRecipesFromPlan(MealPlan plan) async {
    // Tarifleri mutfağa göre grupla
    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final day in plan.gunler) {
      for (final recipe in day.tumTarifler) {
        if (recipe.id.isEmpty || recipe.yemekAdi.isEmpty) continue;

        // Birincil mutfak (ilk eleman)
        final primaryCuisine =
            recipe.mutfaklar.isNotEmpty ? recipe.mutfaklar.first : 'diger';

        grouped.putIfAbsent(primaryCuisine, () => []);
        grouped[primaryCuisine]!.add(_recipeToCache(recipe));
      }
    }

    // Her mutfak doc'una batch yaz
    final batch = _firestore.batch();

    for (final entry in grouped.entries) {
      final docRef = _firestore
          .collection(FirestorePaths.tariflerCollection)
          .doc(entry.key);

      // arrayUnion ile mevcut listeye ekle (duplicate'ler otomatik engellenir — id bazlı kontrol aşağıda)
      batch.set(
        docRef,
        {
          'recipes': FieldValue.arrayUnion(entry.value),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();

    RemoteLoggerService.info(
      'recipes_cached',
      extra: {
        'cuisine_count': grouped.length,
        'recipe_count':
            grouped.values.fold<int>(0, (total, list) => total + list.length),
      },
    );
  }

  /// Kullanıcı tercihlerine uygun tarifleri cache'den çeker.
  /// Alerjen ve diyet filtreleri uygular, sevmediklerini hariç tutar.
  Future<List<Recipe>> getMatchingRecipes(UserPreferences prefs) async {
    final results = <Recipe>[];
    final seenIds = <String>{};

    // Kullanıcının sevdiği mutfak doc'larını çek
    for (final cuisine in prefs.mutfaklar) {
      try {
        final doc = await _firestore
            .collection(FirestorePaths.tariflerCollection)
            .doc(cuisine)
            .get();

        if (!doc.exists || doc.data() == null) continue;

        final recipes = doc.data()!['recipes'] as List<dynamic>? ?? [];

        for (final r in recipes) {
          final map = r as Map<String, dynamic>;
          final recipe = Recipe.fromMap(map);

          // Duplicate kontrolü
          if (seenIds.contains(recipe.id)) continue;

          // Alerjen filtresi: kullanıcının alerjenleri tarifte olmamalı
          final userAllergens = prefs.alerjenler
              .where((a) => !a.startsWith('custom:'))
              .toSet();
          if (recipe.alerjenler.any((a) => userAllergens.contains(a))) continue;

          // Custom alerjen filtresi: yemek adında custom alerjen geçiyorsa atla
          final customAllergens = prefs.alerjenler
              .where((a) => a.startsWith('custom:'))
              .map((a) => a.replaceFirst('custom:', '').toLowerCase())
              .toList();
          final nameL = recipe.yemekAdi.toLowerCase();
          if (customAllergens.any((a) => nameL.contains(a))) continue;

          // Sevmedikleri filtresi
          final customDislikes = prefs.sevmedikleri
              .where((s) => s.startsWith('custom:'))
              .map((s) => s.replaceFirst('custom:', '').toLowerCase())
              .toList();
          final stdDislikes = prefs.sevmedikleri
              .where((s) => !s.startsWith('custom:'))
              .map((s) => s.toLowerCase())
              .toList();
          final allDislikes = [...stdDislikes, ...customDislikes];
          if (allDislikes.any((d) => nameL.contains(d))) continue;

          // Diyet filtresi: kullanıcının diyetlerinden en az biri tarifte olmalı
          if (prefs.diyetler.isNotEmpty) {
            final hasDietMatch =
                prefs.diyetler.any((d) => recipe.diyetler.contains(d));
            if (!hasDietMatch) continue;
          }

          seenIds.add(recipe.id);
          results.add(recipe);
        }
      } catch (e) {
        RemoteLoggerService.error('cache_read_failed: $cuisine', error: e);
      }
    }

    // Karıştır — her seferinde farklı seçim
    results.shuffle();
    return results;
  }

  /// Recipe → cache formatı (full data — kalori, malzeme, yapılış dahil)
  Map<String, dynamic> _recipeToCache(Recipe recipe) {
    return recipe.toMap();
  }
}
