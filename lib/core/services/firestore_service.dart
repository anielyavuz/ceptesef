import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../models/app_config.dart';
import '../models/app_user.dart';
import '../models/meal_plan.dart';
import '../models/shopping_list.dart';
import '../models/user_preferences.dart';

/// Firestore ile iletişim kuran genel servis sınıfı.
/// Sık okunan veriler için in-memory cache kullanır (read tasarrufu).
class FirestoreService {
  final FirebaseFirestore _firestore;

  // ─── In-Memory Cache ───────────────────────────────────
  MealPlan? _cachedMealPlan;
  String? _cachedMealPlanUid;
  DateTime? _mealPlanCacheTime;

  UserPreferences? _cachedPrefs;
  String? _cachedPrefsUid;
  DateTime? _prefsCacheTime;

  List<Recipe>? _cachedSavedRecipes;
  String? _cachedSavedRecipesUid;
  DateTime? _savedRecipesCacheTime;

  static const _cacheDuration = Duration(minutes: 5);

  bool _isCacheValid(DateTime? cacheTime) =>
      cacheTime != null && DateTime.now().difference(cacheTime) < _cacheDuration;

  /// Cache'i temizle (veri değiştiğinde çağır)
  void invalidateMealPlanCache() {
    _cachedMealPlan = null;
    _mealPlanCacheTime = null;
  }

  void invalidatePrefsCache() {
    _cachedPrefs = null;
    _prefsCacheTime = null;
  }

  void invalidateSavedRecipesCache() {
    _cachedSavedRecipes = null;
    _savedRecipesCacheTime = null;
  }
  // ─────────────────────────────────────────────────────────

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// system/general dokümanından uygulama konfigürasyonunu getirir
  Future<AppConfig> getAppConfig() async {
    final doc = await _firestore
        .collection(FirestorePaths.systemCollection)
        .doc(FirestorePaths.generalDoc)
        .get();

    if (!doc.exists || doc.data() == null) {
      throw Exception('Uygulama konfigürasyonu bulunamadı');
    }

    return AppConfig.fromMap(doc.data()!);
  }

  /// Yeni kullanıcı dokümanı oluşturur (kayıt sırasında çağrılır)
  Future<void> createUser(AppUser user) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(user.uid)
        .set(user.toMap());
  }

  /// Kullanıcı dokümanını getirir
  Future<AppUser?> getUser(String uid) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  /// FCM token'ı kullanıcı dokümanına kaydeder
  Future<void> saveFcmToken(String uid, String token) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .update({'fcmToken': token});
  }

  /// Kullanıcı tercihlerini kaydeder (onboarding sonrası)
  Future<void> saveUserPreferences(String uid, UserPreferences prefs) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .set({'preferences': prefs.toMap()}, SetOptions(merge: true));
    invalidatePrefsCache();
  }

  /// Kullanıcı tercihlerini getirir
  Future<UserPreferences?> getUserPreferences(String uid) async {
    // Cache kontrolü
    if (_cachedPrefsUid == uid && _isCacheValid(_prefsCacheTime)) {
      return _cachedPrefs;
    }

    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    final prefsMap = doc.data()!['preferences'] as Map<String, dynamic>?;
    if (prefsMap == null) return null;
    final prefs = UserPreferences.fromMap(prefsMap);

    // Cache'e yaz
    _cachedPrefs = prefs;
    _cachedPrefsUid = uid;
    _prefsCacheTime = DateTime.now();
    return prefs;
  }

  /// Haftalık yemek planını kaydeder
  Future<void> saveMealPlan(String uid, MealPlan plan) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.mealPlansSubcollection)
        .doc(plan.haftaBaslangic)
        .set(plan.toMap());
    invalidateMealPlanCache();
  }

  /// Tüm yemek planlarını siler (test amaçlı)
  Future<void> deleteAllMealPlans(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.mealPlansSubcollection)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
    invalidateMealPlanCache();
  }

  /// En güncel yemek planını getirir.
  /// Önce bu haftanın Pazartesi tarihine göre plan arar (O(1) sorgu).
  /// Bulunamazsa en son oluşturulan planı döndürür (geriye uyumluluk).
  Future<MealPlan?> getCurrentMealPlan(String uid) async {
    // Cache kontrolü
    if (_cachedMealPlanUid == uid && _isCacheValid(_mealPlanCacheTime)) {
      return _cachedMealPlan;
    }

    // Bu haftanın Pazartesi'sini hesapla
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - DateTime.monday) % 7;
    final thisMonday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysFromMonday));
    final mondayStr =
        '${thisMonday.year}-${thisMonday.month.toString().padLeft(2, '0')}-${thisMonday.day.toString().padLeft(2, '0')}';

    // Direkt bu haftanın planını ara (doc ID = haftaBaslangic)
    final exactMatch = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.mealPlansSubcollection)
        .doc(mondayStr)
        .get();

    MealPlan? result;
    if (exactMatch.exists && exactMatch.data() != null) {
      result = MealPlan.fromMap(exactMatch.data()!);
    } else {
      // Fallback: en son plan (geriye uyumluluk)
      final snapshot = await _firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .collection(FirestorePaths.mealPlansSubcollection)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (final doc in snapshot.docs) {
        final plan = MealPlan.fromMap(doc.data());
        if (!plan.isExpired) { result = plan; break; }
      }
    }

    // Cache'e yaz
    _cachedMealPlan = result;
    _cachedMealPlanUid = uid;
    _mealPlanCacheTime = DateTime.now();
    return result;
  }

  /// Kullanıcının tüm verilerini siler (alt koleksiyonlar dahil)
  Future<void> deleteUserData(String uid) async {
    final userRef = _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid);

    // Alt koleksiyonları sil: notifications
    final notifications = await userRef
        .collection(FirestorePaths.notificationsSubcollection)
        .get();
    for (final doc in notifications.docs) {
      await doc.reference.delete();
    }

    // Alt koleksiyonları sil: meal_plans
    final mealPlans = await userRef
        .collection(FirestorePaths.mealPlansSubcollection)
        .get();
    for (final doc in mealPlans.docs) {
      await doc.reference.delete();
    }

    // Ana kullanıcı dokümanını sil
    await userRef.delete();
  }

  /// Mevcut plandaki belirli bir günün belirli slotunu günceller
  /// [newRecipes] — slot'a atanacak tarif listesi
  Future<void> updateMealSlot(
    String uid,
    MealPlan plan,
    int dayIndex,
    String slotKey,
    List<Recipe> newRecipes,
  ) async {
    final updatedGunler = List<MealDay>.from(plan.gunler);
    final oldDay = updatedGunler[dayIndex];
    final updatedOgunler = Map<String, List<Recipe>>.from(oldDay.ogunler);
    updatedOgunler[slotKey] = newRecipes;

    updatedGunler[dayIndex] = MealDay(
      gun: oldDay.gun,
      gunAdi: oldDay.gunAdi,
      ogunler: updatedOgunler,
    );

    final updatedPlan = MealPlan(
      haftaBaslangic: plan.haftaBaslangic,
      secilenOgunler: plan.secilenOgunler,
      gunler: updatedGunler,
    );

    await saveMealPlan(uid, updatedPlan);
  }

  /// Haftalık plandaki belirli bir günün belirli slotunu siler
  Future<void> removeWeeklySlot(
    String uid,
    MealPlan plan,
    int dayIndex,
    String slotKey,
  ) async {
    final updatedGunler = List<MealDay>.from(plan.gunler);
    final oldDay = updatedGunler[dayIndex];
    final updatedOgunler = Map<String, List<Recipe>>.from(oldDay.ogunler);
    updatedOgunler.remove(slotKey);

    updatedGunler[dayIndex] = MealDay(
      gun: oldDay.gun,
      gunAdi: oldDay.gunAdi,
      ogunler: updatedOgunler,
    );

    final updatedPlan = MealPlan(
      haftaBaslangic: plan.haftaBaslangic,
      secilenOgunler: plan.secilenOgunler,
      gunler: updatedGunler,
    );

    await saveMealPlan(uid, updatedPlan);
  }

  /// Belirtilen hafta başlangıç tarihine göre planı getirir (doc ID = weekStart)
  Future<MealPlan?> getMealPlanByWeekStart(String uid, String weekStart) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.mealPlansSubcollection)
        .doc(weekStart)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return MealPlan.fromMap(doc.data()!);
  }

  /// Kullanıcının herhangi bir yemek planı olup olmadığını kontrol eder
  Future<bool> hasMealPlan(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.mealPlansSubcollection)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  // ─── Günlük Plan (Tek Seferlik) ────────────────────────────

  /// Bugünün günlük planını getirir
  Future<MealDay?> getDailyPlan(String uid, String date) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.dailyPlansSubcollection)
        .doc(date)
        .get();

    if (!doc.exists || doc.data() == null) return null;
    return MealDay.fromMap(doc.data()!);
  }

  /// Günlük plana yemek ekler/günceller
  Future<void> saveDailyPlan(String uid, String date, MealDay day) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.dailyPlansSubcollection)
        .doc(date)
        .set(day.toMap());
  }

  /// Günlük plana tek bir slot ekler
  Future<void> addDailySlot(
    String uid,
    String date,
    MealDay currentDay,
    String slotKey,
    List<Recipe> recipes,
  ) async {
    final updatedOgunler = Map<String, List<Recipe>>.from(currentDay.ogunler);
    updatedOgunler[slotKey] = recipes;

    final updatedDay = MealDay(
      gun: currentDay.gun,
      gunAdi: currentDay.gunAdi,
      ogunler: updatedOgunler,
    );

    await saveDailyPlan(uid, date, updatedDay);
  }

  /// Günlük plandan tek bir slot siler
  Future<void> removeDailySlot(
    String uid,
    String date,
    MealDay currentDay,
    String slotKey,
  ) async {
    final updatedOgunler = Map<String, List<Recipe>>.from(currentDay.ogunler);
    updatedOgunler.remove(slotKey);

    final updatedDay = MealDay(
      gun: currentDay.gun,
      gunAdi: currentDay.gunAdi,
      ogunler: updatedOgunler,
    );

    await saveDailyPlan(uid, date, updatedDay);
  }

  // ─── Kaydedilen Tarifler (Arşiv) ────────────────────────

  /// Tarifi kaydedilenler arşivine ekler (fire-and-forget)
  Future<void> saveRecipeToArchive(String uid, Recipe recipe) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .doc(recipe.id.isNotEmpty ? recipe.id : recipe.yemekAdi)
        .set({
      ...recipe.toMap(),
      'savedAt': FieldValue.serverTimestamp(),
    });
    invalidateSavedRecipesCache();
  }

  /// Kaydedilen tarifleri getirir (en son kaydedilen önce)
  Future<List<Recipe>> getSavedRecipes(String uid) async {
    // Cache kontrolü
    if (_cachedSavedRecipesUid == uid && _isCacheValid(_savedRecipesCacheTime)) {
      return _cachedSavedRecipes!;
    }

    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .orderBy('savedAt', descending: true)
        .get();

    final recipes = snapshot.docs
        .map((doc) => Recipe.fromMap({...doc.data(), 'id': doc.id}))
        .toList();

    // Cache'e yaz
    _cachedSavedRecipes = recipes;
    _cachedSavedRecipesUid = uid;
    _savedRecipesCacheTime = DateTime.now();
    return recipes;
  }

  /// Kaydedilen tarifleri starred bilgisiyle getirir
  /// Dönen map: recipeDocId → starred (true/false)
  Future<Map<String, bool>> getSavedRecipeStars(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .get();

    final stars = <String, bool>{};
    for (final doc in snapshot.docs) {
      stars[doc.id] = doc.data()['starred'] == true;
    }
    return stars;
  }

  /// Kaydedilen tarifin yıldız durumunu değiştirir
  Future<void> toggleSavedRecipeStar(
      String uid, String recipeDocId, bool starred) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .doc(recipeDocId)
        .update({'starred': starred});
  }

  /// Tek bir kaydedilen tarifi doc ID ile getirir
  Future<Recipe?> getSavedRecipeById(String uid, String recipeDocId) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .doc(recipeDocId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return Recipe.fromMap({...doc.data()!, 'id': doc.id});
  }

  /// Kaydedilen tarifi arşivden siler
  Future<void> deleteSavedRecipe(String uid, String recipeDocId) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .doc(recipeDocId)
        .delete();
    invalidateSavedRecipesCache();
  }

  /// Birden fazla kaydedilen tarifi toplu siler
  Future<void> deleteSavedRecipes(String uid, List<String> recipeDocIds) async {
    final batch = _firestore.batch();
    for (final docId in recipeDocIds) {
      batch.delete(_firestore
          .collection(FirestorePaths.usersCollection)
          .doc(uid)
          .collection(FirestorePaths.savedRecipesSubcollection)
          .doc(docId));
    }
    await batch.commit();
    invalidateSavedRecipesCache();
  }

  // ─── Tarif Etiketleri ──────────────────────────────────

  /// Kullanıcının tüm tarif etiketlerini getirir
  Future<List<RecipeTag>> getRecipeTags(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.recipeTagsSubcollection)
        .orderBy('name')
        .get();

    return snapshot.docs
        .map((doc) => RecipeTag.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Yeni tarif etiketi oluşturur, oluşturulan doc ID döner
  Future<String> createRecipeTag(String uid, String name, int colorValue) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.recipeTagsSubcollection)
        .add({'name': name, 'colorValue': colorValue});
    return doc.id;
  }

  /// Tarif etiketini siler
  Future<void> deleteRecipeTag(String uid, String tagId) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.recipeTagsSubcollection)
        .doc(tagId)
        .delete();
  }

  /// Bir tarifin etiketlerini günceller
  Future<void> updateRecipeTags(String uid, String recipeDocId, List<String> tagIds) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.savedRecipesSubcollection)
        .doc(recipeDocId)
        .update({'tags': tagIds});
    invalidateSavedRecipesCache();
  }

  // ─── Alışveriş Listeleri ────────────────────────────────

  /// Alışveriş listesi kaydet
  Future<String> saveShoppingList(String uid, ShoppingList list) async {
    final doc = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.shoppingListsSubcollection)
        .add(list.toMap());
    return doc.id;
  }

  /// Tüm alışveriş listelerini getir (en yeniden eskiye)
  Future<List<ShoppingList>> getShoppingLists(String uid) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.shoppingListsSubcollection)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ShoppingList.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Alışveriş listesindeki öğelerin checked durumunu güncelle
  Future<void> updateShoppingListItems(
      String uid, String listId, List<ShoppingItem> items) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.shoppingListsSubcollection)
        .doc(listId)
        .update({'items': items.map((e) => e.toMap()).toList()});
  }

  /// Alışveriş listesi sil
  Future<void> deleteShoppingList(String uid, String listId) async {
    await _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.shoppingListsSubcollection)
        .doc(listId)
        .delete();
  }
}
