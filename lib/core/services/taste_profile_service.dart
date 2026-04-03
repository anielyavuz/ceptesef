import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../models/meal_plan.dart';
import '../models/recipe_interaction.dart';
import 'remote_logger_service.dart';

/// Lezzet profili — kullanıcı öğretilen model verisi.
class TasteProfile {
  final Map<String, int> favoriteMutfaklar;
  final Map<String, int> favoriteOgunTipleri;
  final List<String> cookedRecipeIds;
  final List<String> dislikedRecipeIds;
  final String preferredZorluk;
  final int avgCookingTimeDk;
  final int totalCooked;
  final int totalRated;
  final double avgRating;

  const TasteProfile({
    this.favoriteMutfaklar = const {},
    this.favoriteOgunTipleri = const {},
    this.cookedRecipeIds = const [],
    this.dislikedRecipeIds = const [],
    this.preferredZorluk = '',
    this.avgCookingTimeDk = 0,
    this.totalCooked = 0,
    this.totalRated = 0,
    this.avgRating = 0,
  });

  factory TasteProfile.fromMap(Map<String, dynamic> map) {
    return TasteProfile(
      favoriteMutfaklar: Map<String, int>.from(map['favoriteMutfaklar'] ?? {}),
      favoriteOgunTipleri:
          Map<String, int>.from(map['favoriteOgunTipleri'] ?? {}),
      cookedRecipeIds: List<String>.from(map['cookedRecipeIds'] ?? []),
      dislikedRecipeIds: List<String>.from(map['dislikedRecipeIds'] ?? []),
      preferredZorluk: map['preferredZorluk'] as String? ?? '',
      avgCookingTimeDk: map['avgCookingTimeDk'] as int? ?? 0,
      totalCooked: map['totalCooked'] as int? ?? 0,
      totalRated: map['totalRated'] as int? ?? 0,
      avgRating: (map['avgRating'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'favoriteMutfaklar': favoriteMutfaklar,
      'favoriteOgunTipleri': favoriteOgunTipleri,
      'cookedRecipeIds': cookedRecipeIds,
      'dislikedRecipeIds': dislikedRecipeIds,
      'preferredZorluk': preferredZorluk,
      'avgCookingTimeDk': avgCookingTimeDk,
      'totalCooked': totalCooked,
      'totalRated': totalRated,
      'avgRating': avgRating,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  bool get hasEnoughData => totalCooked >= 3;

  /// Gemini promptuna eklenecek kompakt metin (~300 token)
  String toPromptBlock() {
    if (!hasEnoughData) return '';

    final buf = StringBuffer();
    buf.writeln('KULLANICI LEZZET PROFİLİ:');

    if (favoriteMutfaklar.isNotEmpty) {
      final sorted = favoriteMutfaklar.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(5).map((e) => '${e.key} (${e.value}x)').join(', ');
      buf.writeln('- En sevdiği mutfaklar: $top');
    }

    if (preferredZorluk.isNotEmpty) {
      buf.writeln('- Tercih ettiği zorluk: $preferredZorluk');
    }

    if (avgCookingTimeDk > 0) {
      buf.writeln('- Ortalama pişirme süresi: $avgCookingTimeDk dk');
    }

    if (cookedRecipeIds.isNotEmpty) {
      final recent = cookedRecipeIds.take(30).join(', ');
      buf.writeln('- Son pişirdiği tarifler (TEKRARLAMA): $recent');
    }

    if (dislikedRecipeIds.isNotEmpty) {
      final disliked = dislikedRecipeIds.take(20).join(', ');
      buf.writeln('- Beğenmediği tarifler (ÖNERME): $disliked');
    }

    buf.writeln('- Toplam $totalCooked tarif pişirmiş.');

    return buf.toString();
  }
}

/// Kullanıcı-tarif etkileşimlerini takip eden ve lezzet profili oluşturan servis.
class TasteProfileService {
  final FirebaseFirestore _firestore;

  TasteProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ─── Etkileşim Kaydetme (fire-and-forget) ───────────────

  /// Genel etkileşim kaydet
  void logInteraction(String uid, RecipeInteraction interaction) {
    _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.recipeInteractionsSubcollection)
        .add(interaction.toMap());
  }

  /// Recipe'den hızlı interaction oluştur
  void logRecipeAction(String uid, Recipe recipe, String action,
      {int? rating, int? timeSpentSeconds}) {
    logInteraction(
      uid,
      RecipeInteraction(
        recipeId: recipe.id.isNotEmpty ? recipe.id : recipe.yemekAdi,
        recipeName: recipe.yemekAdi,
        action: action,
        mutfaklar: recipe.mutfaklar,
        ogunTipi: recipe.ogunTipi,
        zorluk: recipe.zorluk,
        rating: rating,
        timeSpentSeconds: timeSpentSeconds,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ─── Lezzet Profili Okuma ───────────────────────────────

  /// Firestore'dan mevcut lezzet profilini oku
  Future<TasteProfile?> getTasteProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || data['tasteProfile'] == null) return null;
    return TasteProfile.fromMap(data['tasteProfile'] as Map<String, dynamic>);
  }

  /// Kullanıcının tüm 'rated' etkileşimlerini recipeId → rating olarak döner.
  /// Composite index gerektirmemek için client-side filtreleme yapar.
  Future<Map<String, int>> getRatedRecipes(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .collection(FirestorePaths.recipeInteractionsSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final map = <String, int>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['action'] != 'rated') continue;
        final id = data['recipeId'] as String? ?? '';
        final rating = data['rating'] as int? ?? 0;
        if (id.isNotEmpty && !map.containsKey(id)) {
          map[id] = rating;
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  /// Puanlanan tariflerin detaylı etkileşim bilgilerini döner.
  /// Her recipeId için sadece son (en güncel) etkileşimi tutar.
  Future<List<RecipeInteraction>> getRatedInteractions(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .collection(FirestorePaths.recipeInteractionsSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final seen = <String>{};
      final result = <RecipeInteraction>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['action'] != 'rated') continue;
        final id = data['recipeId'] as String? ?? '';
        if (id.isEmpty || seen.contains(id)) continue;
        seen.add(id);
        result.add(RecipeInteraction.fromMap(data));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // ─── Lezzet Profili Yeniden Hesaplama ───────────────────

  /// Son 200 etkileşimden lezzet profilini yeniden hesapla ve kaydet.
  Future<TasteProfile> rebuildTasteProfile(String uid) async {
    try {
      final snapshot = await _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .collection(FirestorePaths.recipeInteractionsSubcollection)
          .orderBy('timestamp', descending: true)
          .limit(200)
          .get();

      final interactions = snapshot.docs
          .map((d) => RecipeInteraction.fromMap(d.data()))
          .toList();

      if (interactions.isEmpty) return const TasteProfile();

      // Aggregasyon
      final mutfakCounts = <String, int>{};
      final ogunCounts = <String, int>{};
      final cookedIds = <String>[];
      final dislikedIds = <String>{};
      final zorlukCounts = <String, int>{};
      var totalTime = 0;
      var timeCount = 0;
      var totalCooked = 0;
      var totalRated = 0;
      var ratingSum = 0;

      for (final i in interactions) {
        // Pozitif sinyaller: cooked, rated>=2
        if (i.action == 'cooked' ||
            (i.action == 'rated' && (i.rating ?? 0) >= 2)) {
          for (final m in i.mutfaklar) {
            mutfakCounts[m] = (mutfakCounts[m] ?? 0) + 1;
          }
          if (i.ogunTipi.isNotEmpty) {
            ogunCounts[i.ogunTipi] = (ogunCounts[i.ogunTipi] ?? 0) + 1;
          }
          if (i.zorluk.isNotEmpty) {
            zorlukCounts[i.zorluk] = (zorlukCounts[i.zorluk] ?? 0) + 1;
          }
        }

        if (i.action == 'cooked') {
          totalCooked++;
          if (!cookedIds.contains(i.recipeId)) {
            cookedIds.add(i.recipeId);
          }
        }

        if (i.action == 'rated') {
          totalRated++;
          ratingSum += i.rating ?? 0;
        }

        // Negatif sinyaller
        if (i.action == 'replaced' ||
            i.action == 'skipped' ||
            (i.action == 'rated' && (i.rating ?? 0) == 1)) {
          dislikedIds.add(i.recipeId);
        }

        // Süre istatistiği
        if (i.action == 'viewed' && (i.timeSpentSeconds ?? 0) > 10) {
          totalTime += i.timeSpentSeconds!;
          timeCount++;
        }
      }

      // En çok tercih edilen zorluk
      var preferredZorluk = '';
      if (zorlukCounts.isNotEmpty) {
        final sorted = zorlukCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        preferredZorluk = sorted.first.key;
      }

      final profile = TasteProfile(
        favoriteMutfaklar: mutfakCounts,
        favoriteOgunTipleri: ogunCounts,
        cookedRecipeIds: cookedIds.take(50).toList(),
        dislikedRecipeIds: dislikedIds.take(20).toList(),
        preferredZorluk: preferredZorluk,
        avgCookingTimeDk: timeCount > 0 ? (totalTime / timeCount).round() : 0,
        totalCooked: totalCooked,
        totalRated: totalRated,
        avgRating: totalRated > 0 ? ratingSum / totalRated : 0,
      );

      // Firestore'a kaydet (fire-and-forget)
      _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .set({'tasteProfile': profile.toMap()}, SetOptions(merge: true));

      RemoteLoggerService.info('taste_profile_rebuilt',
          screen: 'system',
          extra: {'totalCooked': totalCooked, 'totalRated': totalRated});

      return profile;
    } catch (e) {
      RemoteLoggerService.error('taste_profile_rebuild_failed', error: e);
      return const TasteProfile();
    }
  }
}
