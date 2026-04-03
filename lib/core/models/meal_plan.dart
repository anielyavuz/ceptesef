import 'dart:convert';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_preferences.dart';

/// Gemini'dan dönen haftalık yemek planı modeli
class MealPlan {
  final String haftaBaslangic;
  final List<String> secilenOgunler;
  final List<MealDay> gunler;
  final DateTime? createdAt;

  const MealPlan({
    required this.haftaBaslangic,
    this.secilenOgunler = const ['kahvalti', 'ogle', 'aksam'],
    required this.gunler,
    this.createdAt,
  });

  /// Gemini'ın JSON çıktısından parse eder
  factory MealPlan.fromGeminiResponse(String rawJson) {
    // Markdown code fence temizliği
    var cleaned = rawJson.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }

    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    return MealPlan.fromMap(map);
  }

  factory MealPlan.fromMap(Map<String, dynamic> map) {
    // Backward compat: yeni secilen_ogunler varsa kullan, yoksa eski ogun_plani'den migrate et
    List<String> ogunler;
    if (map['secilen_ogunler'] != null) {
      ogunler = List<String>.from(map['secilen_ogunler']);
    } else {
      final plan = map['ogun_plani'] as String? ?? 'standart';
      ogunler = UserPreferences.migrateOgunPlani(plan);
    }

    return MealPlan(
      haftaBaslangic: map['hafta_baslangic'] as String? ?? '',
      secilenOgunler: ogunler,
      gunler: (map['gunler'] as List<dynamic>?)
              ?.map((g) => MealDay.fromMap(g as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hafta_baslangic': haftaBaslangic,
      'secilen_ogunler': secilenOgunler,
      'gunler': gunler.map((g) => g.toMap()).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  // ─── Helper'lar ────────────────────────────────────────

  /// Planın kapsadığı Pazar günü (hafta sonu)
  DateTime get weekEndDate {
    final start = DateTime.parse(haftaBaslangic);
    return start.add(const Duration(days: 6)); // Pzt + 6 = Pazar
  }

  /// Plan süresi dolmuş mu? (Pazar geçti mi?)
  bool get isExpired {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = weekEndDate;
    return today.isAfter(sunday);
  }

  /// Planın bitmesine kalan gün sayısı (bugün dahil)
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sunday = weekEndDate;
    final diff = sunday.difference(today).inDays;
    return diff < 0 ? 0 : diff + 1; // bugünü de say
  }

  /// Bugünün tarih string'i
  static String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Geçmiş günlerin index listesi (bugün hariç)
  List<int> get pastDayIndices {
    final today = _todayStr();
    final indices = <int>[];
    for (var i = 0; i < gunler.length; i++) {
      if (gunler[i].gun.compareTo(today) < 0) indices.add(i);
    }
    return indices;
  }

  /// Bugün dahil kalan günlerin index listesi
  List<int> get remainingDayIndices {
    final today = _todayStr();
    final indices = <int>[];
    for (var i = 0; i < gunler.length; i++) {
      if (gunler[i].gun.compareTo(today) >= 0) indices.add(i);
    }
    return indices;
  }

  /// Günler listesini değiştirerek yeni plan döndürür
  MealPlan copyWith({
    String? haftaBaslangic,
    List<String>? secilenOgunler,
    List<MealDay>? gunler,
    DateTime? createdAt,
  }) {
    return MealPlan(
      haftaBaslangic: haftaBaslangic ?? this.haftaBaslangic,
      secilenOgunler: secilenOgunler ?? this.secilenOgunler,
      gunler: gunler ?? this.gunler,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Bir günün öğünleri
class MealDay {
  final String gun;
  final String gunAdi;
  final Map<String, List<Recipe>> ogunler;

  const MealDay({
    required this.gun,
    required this.gunAdi,
    required this.ogunler,
  });

  factory MealDay.fromMap(Map<String, dynamic> map) {
    final ogunlerMap = map['ogunler'] as Map<String, dynamic>? ?? {};
    final parsed = <String, List<Recipe>>{};
    for (final entry in ogunlerMap.entries) {
      final value = entry.value;
      if (value is List) {
        // Yeni format: array of recipes
        parsed[entry.key] = value
            .map((r) => Recipe.fromMap(r as Map<String, dynamic>))
            .toList();
      } else if (value is Map<String, dynamic>) {
        // Eski format: tek recipe object → listeye çevir
        parsed[entry.key] = [Recipe.fromMap(value)];
      }
    }
    return MealDay(
      gun: map['gun'] as String? ?? '',
      gunAdi: map['gun_adi'] as String? ?? '',
      ogunler: parsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gun': gun,
      'gun_adi': gunAdi,
      'ogunler': ogunler.map(
        (k, v) => MapEntry(k, v.map((r) => r.toMap()).toList()),
      ),
    };
  }

  /// Bir slot'taki toplam kalori
  int slotKalori(String slotKey) {
    final recipes = ogunler[slotKey];
    if (recipes == null || recipes.isEmpty) return 0;
    return recipes.fold(0, (sum, r) => sum + r.kalori);
  }

  /// Bir slot'taki toplam süre
  int slotSure(String slotKey) {
    final recipes = ogunler[slotKey];
    if (recipes == null || recipes.isEmpty) return 0;
    return recipes.fold(0, (sum, r) => sum + r.toplamSureDk);
  }

  /// Tüm slotlardaki tüm tariflerin düz listesi
  List<Recipe> get tumTarifler =>
      ogunler.values.expand((list) => list).toList();
}

/// Tek bir tarif
class Recipe {
  final String id;
  final String yemekAdi;
  final String ogunTipi;
  final List<String> mutfaklar;
  final List<String> alerjenler;
  final List<String> diyetler;
  final String zorluk;
  final List<String> malzemeler;
  final List<String> yapilis;
  final int hazirlanmaSuresiDk;
  final int pisirmeSuresiDk;
  final int toplamSureDk;
  final int kisiSayisi;
  final int kalori;
  final String? imageBase64;
  final DateTime? savedAt;
  final List<String> tags;

  const Recipe({
    required this.id,
    required this.yemekAdi,
    required this.ogunTipi,
    this.mutfaklar = const [],
    this.alerjenler = const [],
    this.diyetler = const [],
    this.zorluk = 'orta',
    this.malzemeler = const [],
    this.yapilis = const [],
    this.hazirlanmaSuresiDk = 0,
    this.pisirmeSuresiDk = 0,
    this.toplamSureDk = 0,
    this.kisiSayisi = 4,
    this.kalori = 0,
    this.imageBase64,
    this.savedAt,
    this.tags = const [],
  });

  factory Recipe.fromMap(Map<String, dynamic> map) {
    return Recipe(
      id: map['id'] as String? ?? '',
      yemekAdi: map['yemek_adi'] as String? ?? '',
      ogunTipi: map['ogun_tipi'] as String? ?? '',
      mutfaklar: List<String>.from(map['mutfaklar'] ?? []),
      alerjenler: List<String>.from(map['alerjenler'] ?? []),
      diyetler: List<String>.from(map['diyetler'] ?? []),
      zorluk: map['zorluk'] as String? ?? 'orta',
      malzemeler: List<String>.from(map['malzemeler'] ?? []),
      yapilis: List<String>.from(map['yapilis'] ?? []),
      hazirlanmaSuresiDk: map['hazirlanma_suresi_dk'] as int? ?? 0,
      pisirmeSuresiDk: map['pisirme_suresi_dk'] as int? ?? 0,
      toplamSureDk: map['toplam_sure_dk'] as int? ?? 0,
      kisiSayisi: map['kisi_sayisi'] as int? ?? 4,
      kalori: map['kalori'] as int? ?? 0,
      imageBase64: map['image_base64'] as String?,
      savedAt: map['savedAt'] is Timestamp
          ? (map['savedAt'] as Timestamp).toDate()
          : null,
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'yemek_adi': yemekAdi,
      'ogun_tipi': ogunTipi,
      'mutfaklar': mutfaklar,
      'alerjenler': alerjenler,
      'diyetler': diyetler,
      'zorluk': zorluk,
      'malzemeler': malzemeler,
      'yapilis': yapilis,
      'hazirlanma_suresi_dk': hazirlanmaSuresiDk,
      'pisirme_suresi_dk': pisirmeSuresiDk,
      'toplam_sure_dk': toplamSureDk,
      'kisi_sayisi': kisiSayisi,
      'kalori': kalori,
      if (imageBase64 != null) 'image_base64': imageBase64,
      if (tags.isNotEmpty) 'tags': tags,
    };
  }

  Recipe copyWith({String? imageBase64, List<String>? tags}) {
    return Recipe(
      id: id,
      yemekAdi: yemekAdi,
      ogunTipi: ogunTipi,
      mutfaklar: mutfaklar,
      alerjenler: alerjenler,
      diyetler: diyetler,
      zorluk: zorluk,
      malzemeler: malzemeler,
      yapilis: yapilis,
      hazirlanmaSuresiDk: hazirlanmaSuresiDk,
      pisirmeSuresiDk: pisirmeSuresiDk,
      toplamSureDk: toplamSureDk,
      kisiSayisi: kisiSayisi,
      kalori: kalori,
      imageBase64: imageBase64 ?? this.imageBase64,
      savedAt: savedAt,
      tags: tags ?? this.tags,
    );
  }
}

/// Tarif etiketi (kullanıcı tanımlı)
class RecipeTag {
  final String id;
  final String name;
  final int colorValue;

  const RecipeTag({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  factory RecipeTag.fromMap(Map<String, dynamic> map, String docId) {
    return RecipeTag(
      id: docId,
      name: map['name'] as String? ?? '',
      colorValue: map['colorValue'] as int? ?? 0xFF48A14D,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'colorValue': colorValue,
    };
  }
}
