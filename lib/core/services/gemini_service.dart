import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firestore_service.dart';
import '../models/app_config.dart';
import '../models/chef_chat_response.dart';
import '../models/meal_plan.dart';
import '../models/user_preferences.dart';
import 'taste_profile_service.dart';

/// Gemini AI ile iletişim kuran servis sınıfı.
/// API anahtarı ve model adı Firestore'dan alınır.
class GeminiService {
  /// JSON string'i parse eder. Hata durumunda basit temizleme dener.
  static Map<String, dynamic> safeJsonDecode(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } on FormatException {
      // Kontrol karakterlerini temizle
      cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]', multiLine: true), ' ');
      // Çift tırnaklar arası escape edilmemiş tırnakları düzelt
      // Trailing comma temizle
      cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
      return jsonDecode(cleaned) as Map<String, dynamic>;
    }
  }

  final FirestoreService _firestoreService;
  GenerativeModel? _model;
  AppConfig? _config;

  GeminiService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  /// Gemini modelini başlatır (lazy initialization).
  /// Firestore'dan config çekilir, model oluşturulur.
  Future<void> _ensureInitialized() async {
    if (_model != null) return;

    _config = await _firestoreService.getAppConfig();
    _model = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
    );
  }

  /// Gemini'ye metin tabanlı istek gönderir
  Future<String> generateContent(String prompt) async {
    await _ensureInitialized();
    final response = await _model!.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  /// Kullanıcının isteğine göre tek bir tarif önerir.
  /// Chatbot asistan: kullanıcı ne istediğini yazar, Gemini tam tarif döner.
  /// [savedRecipeNames] varsa, kullanıcının kayıtlı tariflerini bilir ve yönlendirir.
  Future<Recipe> suggestRecipe({
    required String userRequest,
    required UserPreferences preferences,
    TasteProfile? tasteProfile,
    List<String>? savedRecipeNames,
  }) async {
    await _ensureInitialized();

    final alerjenler = preferences.alerjenler
        .map((a) => a.startsWith('custom:') ? a.replaceFirst('custom:', '') : a)
        .toList();

    final sevmedikleri = preferences.sevmedikleri
        .map((s) => s.startsWith('custom:') ? s.replaceFirst('custom:', '') : s)
        .toList();

    final tasteBlock = tasteProfile?.toPromptBlock() ?? '';

    final foodNoteBlock = preferences.foodNote.isNotEmpty
        ? '\nKullanıcının yemek alışkanlıkları notu: "${preferences.foodNote}"\nBu notu dikkate alarak öneri yap.\n'
        : '';

    final savedBlock = (savedRecipeNames != null && savedRecipeNames.isNotEmpty)
        ? '\nKullanıcının daha önce kaydettiği tarifler: ${savedRecipeNames.join(', ')}\n'
            'Eğer kullanıcı bu tariflerden BİREBİR aynısını istiyorsa (örn: kayıtlı "Kuzu Külbastı" ve kullanıcı "kuzu külbastı" diyorsa), '
            'o kaydedilen tarifin adını birebir kullanarak JSON döndür.\n'
            'ANCAK kullanıcı farklı bir pişirme yöntemi, farklı bir varyasyon veya ek detay belirtiyorsa '
            '(örn: "haşlanmış kuzu külbastı", "fırında tavuk" vs "ızgara tavuk"), '
            'bu YENİ bir tariftir — kaydedilmiş olanı kullanma, sıfırdan farklı bir tarif üret. '
            'Pişirme yöntemi (haşlama, fırın, ızgara, buğulama, kavurma vb.) farklıysa tarif farklıdır.\n'
        : '';

    final prompt = '''
Kullanıcı şunu istiyor: "$userRequest"

Tercihler:
- Favori mutfaklar (ÖNCELİKLİ OLARAK bu mutfaklardan öner): ${preferences.mutfaklar.isNotEmpty ? preferences.mutfaklar.join(', ') : 'belirtilmemiş'}

Kısıtlamalar:
- Alerjiler (KULLANMA): ${alerjenler.isNotEmpty ? alerjenler.join(', ') : 'yok'}
- Diyetler: ${preferences.diyetler.isNotEmpty ? preferences.diyetler.join(', ') : 'yok'}
- Sevmedikleri: ${sevmedikleri.isNotEmpty ? sevmedikleri.join(', ') : 'yok'}
- Kişi sayısı: ${preferences.kisiSayisi}
$foodNoteBlock${tasteBlock.isNotEmpty ? '\n$tasteBlock' : ''}$savedBlock
Kullanıcının favori mutfak tercihlerini öncelikli tut. Genel bir istek gelirse (örn: "hızlı bir şey", "hafif bir yemek") favori mutfaklardan öner.
SADECE 1 tarif öner. Tam tarif formatında dön (malzeme, yapılış, kalori dahil).
Tarif ${preferences.kisiSayisi} kişiyi doyuracak yeterlilikte olmalı. Malzeme miktarlarını buna göre ayarla. Tek malzemelik basit yemekler (sadece menemen, sadece makarna) yerine doyurucu ve çeşitli tarifler öner.
''';

    final model = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
      systemInstruction: Content.system(
        'Sen bir mutfak asistanısın. Kullanıcının isteğine göre TEK bir tarif öneriyorsun. '
        'Yanıtını SADECE JSON olarak ver, açıklama ekleme. Format: '
        '{"id":"slug","yemek_adi":"Ad","ogun_tipi":"ana_yemek","mutfaklar":["turk"],'
        '"alerjenler":[],"diyetler":[],"zorluk":"orta","kalori":350,'
        '"malzemeler":["1 adet soğan"],"yapilis":["Doğrayın."],'
        '"hazirlanma_suresi_dk":10,"pisirme_suresi_dk":20,"toplam_sure_dk":30,"kisi_sayisi":4}\n'
        'ÖLÇÜ KURALLARI: Ana malzemelerde (et, balık vb.) yuvarlak sayılar kullan (500 gr, 1 kg). '
        'Gram/ml cinsinden ölçülerin yanına parantez içinde ev ölçüsü karşılığı ekle: '
        '"200 gr tereyağı (yaklaşık 1 su bardağı)". Zaten ev ölçüsü olanları çevirme.\n'
        'MALZEME ADLARI: Marketten alınabilir sade isimler kullan. '
        '"tavuk göğsü" DEĞİL "tavuk göğüs fileto", '
        '"kıyma" DEĞİL "dana kıyma" gibi spesifik yaz. '
        'Parantez içi açıklama EKLEME ("(1 adet)", "(yaklaşık 100 gr)" gibi). '
        'Doğru: "500 gr tavuk göğüs fileto". Yanlış: "150 gr tavuk göğsü (1 adet)".',
      ),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final response = await model.generateContent([Content.text(prompt)]);
    final jsonStr = response.text ?? '';
    if (jsonStr.isEmpty) throw Exception('Gemini boş yanıt döndü');

    final map = safeJsonDecode(jsonStr);
    return Recipe.fromMap(map);
  }

  /// Sohbet modunda şef asistanıyla konuş.
  /// Gemini ya sohbet yanıtı ya da tarif döndürür.
  /// [conversationHistory] ChatSession tarafından otomatik güncellenir.
  Future<ChefChatResponse> chatWithChef({
    required String userMessage,
    required UserPreferences preferences,
    required List<Content> conversationHistory,
    TasteProfile? tasteProfile,
    List<String>? savedRecipeNames,
  }) async {
    await _ensureInitialized();

    final alerjenler = preferences.alerjenler
        .map((a) => a.startsWith('custom:') ? a.replaceFirst('custom:', '') : a)
        .toList();
    final sevmedikleri = preferences.sevmedikleri
        .map((s) => s.startsWith('custom:') ? s.replaceFirst('custom:', '') : s)
        .toList();
    final tasteBlock = tasteProfile?.toPromptBlock() ?? '';
    final savedBlock = (savedRecipeNames != null && savedRecipeNames.isNotEmpty)
        ? 'Kullanıcının kayıtlı tarifleri: ${savedRecipeNames.take(20).join(', ')}'
        : '';

    final systemPrompt = '''
Sen "Cepte Şef" uygulamasının samimi, sıcak ve yardımsever mutfak asistanısın. Kullanıcıyla doğal bir sohbet yürüt.

İKİ TİP YANIT VEREBİLİRSİN:

1. SOHBET (type: "chat") — Kullanıcı soru soruyor, sohbet ediyor, bir durum anlatıyor, ne istediğinden emin değil veya daha fazla bilgiye ihtiyacın var.
2. TARİF (type: "recipe") — Kullanıcı açıkça bir yemek/tarif istiyor veya konuşma sonucunda tarif verme zamanı geldi.

KARAR KURALLARI:
- "Karnım ağrıyor", "bugün halsizim", "ne yesem bilmiyorum" → type: chat (empati göster, tercih sor, öneri sun)
- "Akşama ne pişirsem?", "bir fikrin var mı?" → type: chat (tercih sor: et mi sebze mi, hafif mi doyurucu mu?)
- "Makarna istiyorum", "tavuklu bir şey yap", "çorba öner" → type: recipe (hemen tarif ver)
- "Evet öyle olsun", "tamam yap" (önceki sohbete yanıt) → type: recipe (konuşmadaki bağlama göre tarif üret)
- Kısa ve net yemek istekleri ("hızlı bir şey", "düşük kalori") → type: recipe

Tarif verdikten sonra kısa bir tanıtım mesajı yaz ve "Başka bir şey ister misin?" gibi sohbeti açık tut.
Sohbet yanıtlarında kısa, samimi ve doğal ol. Emoji kullanabilirsin ama abartma.

KULLANICI BİLGİLERİ:
- Favori mutfaklar: ${preferences.mutfaklar.isNotEmpty ? preferences.mutfaklar.join(', ') : 'belirtilmemiş'}
- Alerjiler (KULLANMA): ${alerjenler.isNotEmpty ? alerjenler.join(', ') : 'yok'}
- Diyetler: ${preferences.diyetler.isNotEmpty ? preferences.diyetler.join(', ') : 'yok'}
- Sevmedikleri: ${sevmedikleri.isNotEmpty ? sevmedikleri.join(', ') : 'yok'}
- Kişi sayısı: ${preferences.kisiSayisi}
${tasteBlock.isNotEmpty ? '\n$tasteBlock' : ''}
${savedBlock.isNotEmpty ? '\n$savedBlock' : ''}

ÖLÇÜ KURALLARI (tarif verirken):
- Ana malzemelerde yuvarlak sayılar kullan (500 gr, 1 kg).
- Gram/ml ölçülerin yanına parantez içinde ev ölçüsü ekle: "200 gr tereyağı (yaklaşık 1 su bardağı)".
- Pişirme yöntemi farklıysa (haşlanmış vs ızgara) farklı bir tariftir.

MALZEME ADLARI:
- Marketten alınabilir sade isimler kullan.
- "tavuk göğsü" DEĞİL "tavuk göğüs fileto" yaz.
- "kıyma" DEĞİL "dana kıyma" gibi spesifik yaz.
- Parantez içi açıklama EKLEME ("(1 adet)", "(yaklaşık 100 gr)" gibi).

JSON FORMAT (her zaman bu formatta yanıtla):
Sohbet: {"type":"chat","message":"yanıt metni"}
Tarif: {"type":"recipe","message":"kısa tanıtım","recipe":{"id":"slug","yemek_adi":"Ad","ogun_tipi":"ana_yemek","mutfaklar":["turk"],"alerjenler":[],"diyetler":[],"zorluk":"orta","kalori":350,"malzemeler":["1 adet soğan"],"yapilis":["Doğrayın."],"hazirlanma_suresi_dk":10,"pisirme_suresi_dk":20,"toplam_sure_dk":30,"kisi_sayisi":${preferences.kisiSayisi}}}
''';

    final model = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final chat = model.startChat(history: conversationHistory);
    final response = await chat.sendMessage(Content.text(userMessage));
    final jsonStr = response.text ?? '';
    if (jsonStr.isEmpty) throw Exception('Gemini boş yanıt döndü');

    final chatMap = safeJsonDecode(jsonStr);
    return ChefChatResponse.fromMap(chatMap);
  }

  /// Belirli bir günün öğünlerini yeniden üretir.
  /// [customInstruction] verilirse, AI'ya ek yönlendirme olarak eklenir.
  Future<MealDay> regenerateDay(
    UserPreferences preferences,
    MealDay currentDay,
    List<String> otherRecipeNames, {
    String? customInstruction,
  }) async {
    await _ensureInitialized();

    final systemPrompt =
        await rootBundle.loadString('assets/gemini/system_prompt.md');

    final userInput = _buildPreferencesJson(preferences);

    final prompt = '''
$userInput

SADECE şu günü yeniden oluştur: ${currentDay.gunAdi} (${currentDay.gun})
Öğün planı slotları: ${currentDay.ogunler.keys.join(', ')}

Bu tarifler zaten planda var, TEKRARLAMA:
${otherRecipeNames.join(', ')}
${customInstruction != null ? '\nKULLANICI İSTEĞİ: $customInstruction\nBu isteği dikkate alarak tarif öner.\n' : ''}
ÖNEMLİ: Her tarif için malzemeler listesi ve yapılış adımları ZORUNLU. Bunlar olmadan tarif geçersizdir.
Her tarif tam JSON formatında olmalı — şu alanların HEPSİ dolu olmalı:
- "malzemeler": ["miktar birim malzeme", ...] — EN AZ 3 malzeme. Marketten alınabilir sade isimler yaz, parantez açıklama EKLEME. "tavuk göğüs fileto" yaz, "tavuk göğsü (1 adet)" yazma. "dana kıyma" yaz, "kıyma" yazma.
- "yapilis": ["Adım 1.", "Adım 2.", ...] — EN AZ 2 adım
- "kalori": sayı (kişi başı)
- "hazirlanma_suresi_dk", "pisirme_suresi_dk", "toplam_sure_dk": sayı
- "kisi_sayisi": ${preferences.kisiSayisi}
Malzemeler ve yapılış BOŞ OLMAMALI, aksi halde tarif geçersiz sayılır.
Yanıtını SADECE tek bir gün objesi olarak dön:
{"gunler": [<tek gün objesi>]}
''';

    final mealPlanModel = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final response = await mealPlanModel.generateContent([
      Content.text(prompt),
    ]);

    final jsonStr = response.text ?? '';
    if (jsonStr.isEmpty) throw Exception('Gemini boş yanıt döndü');

    final map = safeJsonDecode(jsonStr);
    final gunler = map['gunler'] as List<dynamic>?;
    if (gunler == null || gunler.isEmpty) {
      throw Exception('Gemini geçerli bir gün verisi döndürmedi');
    }

    return MealDay.fromMap(gunler.first as Map<String, dynamic>);
  }

  /// Kalan günleri yeniden üretir (bugünden itibaren).
  /// Geçmiş günlerdeki tarifler korunur, tekrar edilmez.
  Future<List<MealDay>> generateRemainingDays(
    UserPreferences preferences,
    MealPlan currentPlan,
  ) async {
    final pastIndices = currentPlan.pastDayIndices;
    final remainingIndices = currentPlan.remainingDayIndices;
    if (remainingIndices.isEmpty) return [];

    // Geçmiş günlerdeki tarif isimlerini topla (tekrar önleme)
    final pastRecipeNames = <String>[];
    for (final i in pastIndices) {
      for (final recipe in currentPlan.gunler[i].tumTarifler) {
        pastRecipeNames.add(recipe.yemekAdi);
      }
    }

    // Her kalan günü sırayla yenile
    final newDays = <MealDay>[];
    final allRecipeNames = List<String>.from(pastRecipeNames);

    for (final dayIndex in remainingIndices) {
      final currentDay = currentPlan.gunler[dayIndex];
      final newDay = await regenerateDay(
        preferences,
        currentDay,
        allRecipeNames,
      );
      newDays.add(newDay);

      // Yeni günün tariflerini de "tekrarlama" listesine ekle
      for (final recipe in newDay.tumTarifler) {
        allRecipeNames.add(recipe.yemekAdi);
      }
    }

    return newDays;
  }

  /// Kullanıcı tercihlerine göre haftalık yemek planı üretir.
  ///
  /// Hybrid mantık:
  /// 1. Cache'den filtrelere uyan tarifleri al (max slotCount kadar)
  /// 2. Cache yeterliyse: cache'den doldur + Gemini'a sadece %25 yeni tarif ürettir (havuzu besle)
  /// 3. Cache yetersizse: cache'dekiler + Gemini kalanı doldurur
  /// 4. Cache boşsa: Gemini tamamını üretir
  Future<MealPlan> generateMealPlan(
    UserPreferences preferences, {
    List<Recipe> cachedRecipes = const [],
    TasteProfile? tasteProfile,
    DateTime? startDate,
    int? selectedDayCount,
  }) async {
    await _ensureInitialized();

    final systemPrompt =
        await rootBundle.loadString('assets/gemini/system_prompt.md');

    final userInput = _buildPreferencesJson(preferences,
        startDate: startDate, overrideDayCount: selectedDayCount);
    final tasteBlock = tasteProfile?.toPromptBlock() ?? '';

    // Öğün planına göre toplam slot sayısı
    final slotsPerDay = _slotCount(preferences);
    final effectiveStart = startDate ?? DateTime.now();
    final dayCount = selectedDayCount ??
        ((DateTime.sunday - effectiveStart.weekday) % 7 + 1);
    final totalSlots = slotsPerDay * dayCount;

    // Her zaman en az %25 yeni tarif üret (cache'i beslemek için)
    final minNewRecipes = (totalSlots * 0.25).ceil();
    final maxFromCache = totalSlots - minNewRecipes;

    // Cache'den kullanılacak tarifleri seç
    final usableFromCache = cachedRecipes.take(maxFromCache).toList();
    final slotsForGemini = totalSlots - usableFromCache.length;

    debugPrint('╔══ HYBRID PLAN ══════════════════');
    debugPrint('║ Toplam slot: $totalSlots');
    debugPrint('║ Cache\'den: ${usableFromCache.length}');
    debugPrint('║ Gemini üretecek: $slotsForGemini (min yeni: $minNewRecipes)');
    debugPrint('╚═════════════════════════════════');

    // Prompt'u oluştur
    String cacheSection = '';
    if (usableFromCache.isNotEmpty) {
      final cacheList = usableFromCache
          .map((r) => '- ${r.yemekAdi} (${r.ogunTipi}, ${r.zorluk}, ${r.toplamSureDk}dk)')
          .join('\n');
      cacheSection = '''

CACHE'DEN KULLANILACAK TARİFLER (bunları plana yerleştir, metadata'larını koru):
$cacheList

GERİ KALAN $slotsForGemini SLOT İÇİN YENİ TARİFLER ÜRET.
Yukarıdaki cache tariflerini tekrarlama, yeni ve farklı tarifler ekle.
''';
    }

    final mealPlanModel = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
      systemInstruction: Content.system(systemPrompt),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final response = await mealPlanModel.generateContent([
      Content.text('$userInput$cacheSection${tasteBlock.isNotEmpty ? '\n$tasteBlock' : ''}'),
    ]);

    final jsonStr = response.text ?? '';
    if (jsonStr.isEmpty) {
      throw Exception('Gemini boş yanıt döndü');
    }

    return MealPlan.fromGeminiResponse(jsonStr);
  }

  /// Mevsim belirleme
  String _currentSeason(DateTime now) {
    final month = now.month;
    if (month >= 3 && month <= 5) return 'ilkbahar';
    if (month >= 6 && month <= 8) return 'yaz';
    if (month >= 9 && month <= 11) return 'sonbahar';
    return 'kis';
  }

  /// Öğün planına göre günlük slot sayısı
  int _slotCount(UserPreferences preferences) {
    return preferences.secilenOgunler.length;
  }

  /// UserPreferences'ı Gemini'a gönderilecek JSON string'e çevirir.
  /// [startDate] verilirse o tarih haftanın Pazartesi'si olarak kullanılır.
  String _buildPreferencesJson(UserPreferences preferences,
      {DateTime? startDate, int? overrideDayCount}) {
    final standartAlerjenler = preferences.alerjenler
        .where((a) => !a.startsWith('custom:'))
        .toList();
    final customAlerjenler = preferences.alerjenler
        .where((a) => a.startsWith('custom:'))
        .map((a) => a.replaceFirst('custom:', ''))
        .toList();

    final standartSevmedikleri = preferences.sevmedikleri
        .where((s) => !s.startsWith('custom:'))
        .toList();
    final customSevmedikleri = preferences.sevmedikleri
        .where((s) => s.startsWith('custom:'))
        .map((s) => s.replaceFirst('custom:', ''))
        .toList();

    // Planın başlayacağı günü hesapla (bugün veya verilen tarih)
    final now = DateTime.now();
    final DateTime startDay = startDate ?? DateTime(now.year, now.month, now.day);

    // Haftanın Pazartesi'sini bul (plan doc ID'si ve Gemini referansı için)
    final daysFromMonday = (startDay.weekday - DateTime.monday) % 7;
    final monday = startDay.subtract(Duration(days: daysFromMonday));

    // Gün sayısı: override varsa onu kullan, yoksa startDate'ten Pazar'a kadar
    final dayCount = overrideDayCount ??
        ((DateTime.sunday - startDay.weekday) % 7 + 1);

    final haftaBaslangic =
        '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

    final input = {
      'kullanici_tercihleri': {
        'mutfaklar': preferences.mutfaklar,
        'alerjenler': standartAlerjenler,
        if (customAlerjenler.isNotEmpty) 'custom_alerjenler': customAlerjenler,
        'diyetler': preferences.diyetler,
        'secilen_ogunler': preferences.secilenOgunler,
        'kisi_sayisi': preferences.kisiSayisi,
        'sevmedikleri': standartSevmedikleri,
        if (customSevmedikleri.isNotEmpty)
          'custom_sevmedikleri': customSevmedikleri,
        if (preferences.foodNote.isNotEmpty)
          'kullanici_notu': preferences.foodNote,
      },
      'bugunun_tarihi': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'hafta_baslangic': haftaBaslangic,
      'plan_baslangic': '${startDay.year}-${startDay.month.toString().padLeft(2, '0')}-${startDay.day.toString().padLeft(2, '0')}',
      'gun_sayisi': dayCount,
      'mevsim': _currentSeason(now),
      'gun_tipi': now.weekday >= 6 ? 'hafta_sonu' : 'hafta_ici',
    };

    return const JsonEncoder.withIndent('  ').convert(input);
  }

  /// Görselden veya screenshot'tan tarif çıkarır.
  ///
  /// İki senaryoyu destekler:
  /// - Yemek fotoğrafı: yemeği tanır, kendi bilgisiyle eksiksiz tarif üretir.
  /// - Screenshot (Instagram, web vb.): görseldeki tarif metnini okur,
  ///   eksik alanları mutfak uzmanlığıyla tamamlar.
  ///
  /// Dönüş: (Recipe, bounding box map) — bounding box varsa görselden
  /// yemek fotoğrafı kırpılabilir. Koordinatlar 0-1 arası normalize değerler.
  Future<(Recipe, Map<String, double>?)> recipeFromImage(
      Uint8List imageBytes, String mimeType) async {
    await _ensureInitialized();

    final model = GenerativeModel(
      model: _config!.modelName,
      apiKey: _config!.geminiApiKey,
      systemInstruction: Content.system(
        'Sen deneyimli bir mutfak uzmanı ve görsel analiz uzmanısın.\n\n'
        'Sana iki tip görsel gelebilir:\n'
        '1. YEMEK FOTOĞRAFI — Bir yemeğin fotoğrafı. Yemeği tanı, kendi mutfak bilginle tam tarif oluştur.\n'
        '2. SCREENSHOT — Instagram, web sitesi vb. kaynaklardan alınmış tarif içeren ekran görüntüsü. '
        'Görseldeki tüm metni dikkatle oku, tarif bilgilerini çıkar.\n\n'
        'Her iki durumda da şunları mutlaka yap:\n'
        '• Malzeme miktarlarını somut yaz ("2 su bardağı un", "1 çay kaşığı tuz" gibi). '
        'Ana malzemelerde yuvarlak sayılar kullan (500 gr, 1 kg). Gram/ml ölçülerin yanına parantez içinde ev ölçüsü ekle: "200 gr tereyağı (yaklaşık 1 su bardağı)".\n'
        '• Malzeme adlarını marketten alınabilir sade isimlerle yaz. '
        '"tavuk göğüs fileto" yaz, "tavuk göğsü (1 adet)" yazma. "dana kıyma" yaz, "kıyma" yazma. Parantez içi açıklama ekleme.\n'
        '• Yapılış adımlarını net ve sıralı yaz, her adım tek bir işlem olsun\n'
        '• Kaloriyi porsiyon başına kcal olarak tahmin et\n'
        '• Hazırlama ve pişirme sürelerini ayrı ayrı tahmin et\n'
        '• Alerjen tespiti yap — içerdiği standart alerjenler: '
        'gluten, sut, yumurta, fislik, agac_kabuklusu, susam, soya, deniz_urunu, hardal, kereviz\n'
        '• Diyet uygunluğunu belirle — yalnızca gerçekten uyan diyetleri ekle: '
        'vegan, vejetaryen, glutensiz, laktossuz, dusuk_karbonhidrat, yuksek_protein\n'
        '• Zorluk seviyesini adım karmaşıklığına ve tekniklerine göre belirle\n'
        '• Mutfak kategorisini belirle: turk, italyan, fransiz, asya, meksika, ortadogu, amerikan, diger\n'
        '• Öğün tipini belirle: kahvalti, ara_ogun, ana_yemek, tatli, icecek\n\n'
        '• Görselde yemek fotoğrafı varsa konumunu bildir:\n'
        '  - YEMEK FOTOĞRAFI ise: tüm görsel yemek olduğundan gorsel_konum = {"top":0,"left":0,"right":1,"bottom":1}\n'
        '  - SCREENSHOT ise ve içinde yemek fotoğrafı/görseli varsa: '
        'fotoğrafın görsel içindeki konumunu 0-1 arası normalize koordinatlarla bildir '
        '(top, left, right, bottom — örn: {"top":0.05,"left":0.1,"right":0.9,"bottom":0.45})\n'
        '  - SCREENSHOT ise ve yemek fotoğrafı/görseli YOKSA: gorsel_konum = null\n\n'
        'Yanıtını SADECE JSON olarak ver, hiçbir açıklama ekleme.\n'
        'JSON format (tüm alanlar zorunlu, hiçbirini boş bırakma):\n'
        '{"id":"slug-kucuk-harf-tire-ile","yemek_adi":"Tarif Adı",'
        '"ogun_tipi":"ana_yemek","mutfaklar":["turk"],'
        '"alerjenler":["gluten","sut"],"diyetler":[],'
        '"zorluk":"orta","kalori":450,'
        '"malzemeler":["2 su bardağı un","1 adet yumurta","1 çay kaşığı tuz"],'
        '"yapilis":["Unu derin bir kaba eleyin.","Yumurtaları kırıp ekleyin ve yoğurun."],'
        '"hazirlanma_suresi_dk":15,"pisirme_suresi_dk":30,"toplam_sure_dk":45,"kisi_sayisi":4,'
        '"gorsel_konum":{"top":0.0,"left":0.0,"right":1.0,"bottom":0.5}}',
      ),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final response = await model.generateContent([
      Content.multi([
        DataPart(mimeType, imageBytes),
        TextPart(
          'Bu görseli analiz et.\n\n'
          'SCREENSHOT ise: görseldeki tarif metnini kelime kelime oku. '
          'Tüm malzemeleri ve yapılış adımlarını çıkar. '
          'Görselde olmayan ama tarif için gerekli bilgileri (kalori, süre, alerjen, zorluk, mutfak) '
          'mutfak uzmanlığınla tahmin ederek ekle. Hiçbir alanı 0 veya boş bırakma.\n\n'
          'YEMEK FOTOĞRAFI ise: yemeği tanı, adını belirle, '
          'malzeme listesi + yapılış adımları + tüm metadata ile eksiksiz tarif oluştur.\n\n'
          'Kalori mutlaka porsiyon başına gerçekçi bir tahmin olsun. '
          'Toplam süre = hazırlama + pişirme süresi toplamı olsun.',
        ),
      ]),
    ]);

    final jsonStr = response.text ?? '';
    if (jsonStr.isEmpty) throw Exception('Gemini boş yanıt döndü');

    final map = safeJsonDecode(jsonStr);

    // Görsel konum bilgisini çıkar (varsa)
    Map<String, double>? imageRegion;
    final regionData = map['gorsel_konum'];
    if (regionData is Map<String, dynamic>) {
      final top = (regionData['top'] as num?)?.toDouble();
      final left = (regionData['left'] as num?)?.toDouble();
      final right = (regionData['right'] as num?)?.toDouble();
      final bottom = (regionData['bottom'] as num?)?.toDouble();
      if (top != null && left != null && right != null && bottom != null) {
        imageRegion = {
          'top': top.clamp(0.0, 1.0),
          'left': left.clamp(0.0, 1.0),
          'right': right.clamp(0.0, 1.0),
          'bottom': bottom.clamp(0.0, 1.0),
        };
      }
    }
    map.remove('gorsel_konum');

    return (Recipe.fromMap(map), imageRegion);
  }
}
