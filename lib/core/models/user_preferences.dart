import 'package:cloud_firestore/cloud_firestore.dart';

/// Kullanıcı onboarding tercihlerini tutan model.
/// Gemini'a gönderilecek inputlarla birebir uyumlu.
class UserPreferences {
  /// Sevilen mutfak türleri
  final List<String> mutfaklar;

  /// Kullanıcının alerjileri (custom: prefix'li olanlar dahil)
  final List<String> alerjenler;

  /// Uygulanan diyetler (çoklu seçim)
  final List<String> diyetler;

  /// Seçilen öğün slotları: kahvalti, ogle, aksam, ara_ogun
  final List<String> secilenOgunler;

  /// Hane halkı sayısı: 1, 2, 4, 5+
  final int kisiSayisi;

  /// Sevmediği malzemeler
  final List<String> sevmedikleri;

  /// Onboarding tamamlandı mı
  final bool onboardingCompleted;

  /// Ana ekran görünüm modu: 0 = haftalık, 1 = günlük
  final int viewMode;

  /// Kullanıcının serbest yazılı yemek alışkanlığı notu
  final String foodNote;

  /// Tercih edilen marketler (boş = hepsi)
  final List<String> preferredMarkets;

  /// Seçilebilir öğün slotları (sabahtan akşama sıralı)
  static const availableSlots = ['kahvalti', 'ogle', 'aksam', 'ara_ogun'];

  /// Varsayılan öğün seçimi
  static const defaultSlots = ['kahvalti', 'ogle', 'aksam'];

  const UserPreferences({
    this.mutfaklar = const [],
    this.alerjenler = const [],
    this.diyetler = const [],
    this.secilenOgunler = defaultSlots,
    this.kisiSayisi = 1,
    this.sevmedikleri = const [],
    this.onboardingCompleted = false,
    this.viewMode = 0,
    this.foodNote = '',
    this.preferredMarkets = const [],
  });

  /// Eski ogunPlani string'ini secilenOgunler listesine dönüştürür
  static List<String> migrateOgunPlani(String plan) {
    switch (plan) {
      case 'minimal':
        return const ['kahvalti', 'aksam'];
      case 'yogun':
        return const ['kahvalti', 'ogle', 'aksam', 'ara_ogun'];
      case 'esnek':
        return const ['kahvalti', 'ogle', 'aksam'];
      default: // standart
        return const ['kahvalti', 'ogle', 'aksam'];
    }
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    // Backward compat: yeni alan varsa kullan, yoksa eski ogunPlani'den migrate et
    List<String> ogunler;
    if (map['secilenOgunler'] != null) {
      ogunler = List<String>.from(map['secilenOgunler']);
    } else {
      final plan = map['ogunPlani'] as String? ?? 'standart';
      ogunler = migrateOgunPlani(plan);
    }

    return UserPreferences(
      mutfaklar: List<String>.from(map['mutfaklar'] ?? []),
      alerjenler: List<String>.from(map['alerjenler'] ?? []),
      diyetler: List<String>.from(map['diyetler'] ?? []),
      secilenOgunler: ogunler,
      kisiSayisi: map['kisiSayisi'] as int? ?? 1,
      sevmedikleri: List<String>.from(map['sevmedikleri'] ?? []),
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
      viewMode: map['viewMode'] as int? ?? 0,
      foodNote: map['foodNote'] as String? ?? '',
      preferredMarkets: List<String>.from(map['preferredMarkets'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mutfaklar': mutfaklar,
      'alerjenler': alerjenler,
      'diyetler': diyetler,
      'secilenOgunler': secilenOgunler,
      'kisiSayisi': kisiSayisi,
      'sevmedikleri': sevmedikleri,
      'onboardingCompleted': onboardingCompleted,
      'viewMode': viewMode,
      'foodNote': foodNote,
      'preferredMarkets': preferredMarkets,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  UserPreferences copyWith({
    List<String>? mutfaklar,
    List<String>? alerjenler,
    List<String>? diyetler,
    List<String>? secilenOgunler,
    int? kisiSayisi,
    List<String>? sevmedikleri,
    bool? onboardingCompleted,
    int? viewMode,
    String? foodNote,
    List<String>? preferredMarkets,
  }) {
    return UserPreferences(
      mutfaklar: mutfaklar ?? this.mutfaklar,
      alerjenler: alerjenler ?? this.alerjenler,
      diyetler: diyetler ?? this.diyetler,
      secilenOgunler: secilenOgunler ?? this.secilenOgunler,
      kisiSayisi: kisiSayisi ?? this.kisiSayisi,
      sevmedikleri: sevmedikleri ?? this.sevmedikleri,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      viewMode: viewMode ?? this.viewMode,
      foodNote: foodNote ?? this.foodNote,
      preferredMarkets: preferredMarkets ?? this.preferredMarkets,
    );
  }
}
