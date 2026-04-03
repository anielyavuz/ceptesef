import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'firestore_service.dart';
import 'gemini_service.dart';
import 'remote_logger_service.dart';
import '../models/chef_chat_response.dart';
import '../models/meal_plan.dart';
import '../models/user_preferences.dart';
import 'taste_profile_service.dart';

/// Groq AI chat servisi.
/// API key Firestore system/general dokümanından alınır (groqApiKey alanı).
class GroqService {
  final FirestoreService _firestoreService;

  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _defaultModel = 'llama-3.3-70b-versatile';
  static const double _temperature = 0.3;
  static const int _maxTokens = 1024;
  static const int _maxHistoryMessages = 20;

  String? _apiKey;
  String _model = _defaultModel;

  /// Konuşma geçmişi
  final List<Map<String, String>> _history = [];

  GroqService({required FirestoreService firestoreService})
      : _firestoreService = firestoreService;

  /// Lazy init — Firestore'dan API key ve model adını çeker
  Future<void> _ensureInitialized() async {
    if (_apiKey != null) return;

    final config = await _firestoreService.getAppConfig();
    _apiKey = config.groqApiKey;
    if (config.groqModelName.isNotEmpty) {
      _model = config.groqModelName;
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Groq API key Firestore\'da tanımlı değil (groqApiKey)');
    }
  }

  /// Tek soru gönderir, yanıt + kullanım bilgisi döner.
  ///
  /// [prompt] — kullanıcının mesajı
  /// [system] — sistem talimatı (opsiyonel)
  /// [maxTokens] — maksimum yanıt token sayısı
  Future<GroqResponse> ask(
    String prompt, {
    String system = 'Sen yardımcı bir asistansın.',
    int maxTokens = _maxTokens,
  }) async {
    await _ensureInitialized();

    // Mesaj dizisini oluştur
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
    ];

    // Kullanıcı mesajını geçmişe ekle
    _history.add({'role': 'user', 'content': prompt});

    // Son N mesajı al
    final recentHistory = _history.length > _maxHistoryMessages
        ? _history.sublist(_history.length - _maxHistoryMessages)
        : _history;
    messages.addAll(recentHistory);

    // API isteği
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (response.statusCode != 200) {
      RemoteLoggerService.error('groq_api_error',
        error: 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
      throw GroqApiException(
        'Groq API hatası: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq boş yanıt döndü');
    }

    final reply =
        choices[0]['message']['content'] as String? ?? '';

    // Asistan yanıtını geçmişe ekle
    _history.add({'role': 'assistant', 'content': reply});

    // Kullanım bilgisi
    final usage = data['usage'] as Map<String, dynamic>? ?? {};
    final headers = response.headers;

    final groqUsage = GroqUsage(
      promptTokens: usage['prompt_tokens'] as int? ?? 0,
      completionTokens: usage['completion_tokens'] as int? ?? 0,
      totalTokens: usage['total_tokens'] as int? ?? 0,
      remainingRequests: _parseInt(headers['x-ratelimit-remaining-requests']),
      limitRequests: _parseInt(headers['x-ratelimit-limit-requests']),
      remainingTokens: _parseInt(headers['x-ratelimit-remaining-tokens']),
      limitTokens: _parseInt(headers['x-ratelimit-limit-tokens']),
      resetRequests: headers['x-ratelimit-reset-requests'],
      resetTokens: headers['x-ratelimit-reset-tokens'],
    );

    debugPrint('╔══ GROQ ══════════════════════');
    debugPrint('║ Tokens: ${groqUsage.totalTokens} '
        '(prompt: ${groqUsage.promptTokens}, completion: ${groqUsage.completionTokens})');
    debugPrint('║ Rate: ${groqUsage.remainingRequests}/${groqUsage.limitRequests} req, '
        '${groqUsage.remainingTokens}/${groqUsage.limitTokens} tok');
    debugPrint('╚═════════════════════════════');

    return GroqResponse(reply: reply, usage: groqUsage);
  }

  /// Şef asistanıyla sohbet — Gemini chatWithChef ile aynı JSON formatında yanıt döner.
  /// Rate limit (429) hatası alırsa GroqApiException fırlatır → caller fallback yapabilir.
  Future<ChefChatResponse> chatWithChef({
    required String userMessage,
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
- Pişirme yöntemi farklıysa (haşlanmış vs ızgara) farklır.

MALZEME ADLARI:
- Marketten alınabilir sade isimler yaz, parantez açıklama EKLEME.
- "tavuk göğüs fileto" yaz, "tavuk göğsü (1 adet)" yazma.
- "dana kıyma" yaz, "kıyma" yazma. Spesifik ol.

YANITI SADECE JSON OLARAK VER, AÇIKLAMA EKLEME.
Sohbet: {"type":"chat","message":"yanıt metni"}
Tarif: {"type":"recipe","message":"kısa tanıtım","recipe":{"id":"slug","yemek_adi":"Ad","ogun_tipi":"ana_yemek","mutfaklar":["turk"],"alerjenler":[],"diyetler":[],"zorluk":"orta","kalori":350,"malzemeler":["1 adet soğan"],"yapilis":["Doğrayın."],"hazirlanma_suresi_dk":10,"pisirme_suresi_dk":20,"toplam_sure_dk":30,"kisi_sayisi":${preferences.kisiSayisi}}}
''';

    // Groq'un kendi history mekanizmasını kullan
    _history.add({'role': 'user', 'content': userMessage});

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];
    final recentHistory = _history.length > _maxHistoryMessages
        ? _history.sublist(_history.length - _maxHistoryMessages)
        : _history;
    messages.addAll(recentHistory);

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': 2048,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      // Rate limit veya hata — history'den son eklenen user mesajını geri al
      _history.removeLast();
      RemoteLoggerService.error('groq_chat_error',
        error: 'HTTP ${response.statusCode}',
      );
      throw GroqApiException(
        'Groq API hatası: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      _history.removeLast();
      throw Exception('Groq boş yanıt döndü');
    }

    final reply = choices[0]['message']['content'] as String? ?? '';
    _history.add({'role': 'assistant', 'content': reply});

    // Rate limit bilgisi logla
    final usage = data['usage'] as Map<String, dynamic>? ?? {};
    final headers = response.headers;
    debugPrint('╔══ GROQ CHAT ═════════════════');
    debugPrint('║ Tokens: ${usage['total_tokens']} '
        '(prompt: ${usage['prompt_tokens']}, completion: ${usage['completion_tokens']})');
    debugPrint('║ Rate: ${headers['x-ratelimit-remaining-requests']}/${headers['x-ratelimit-limit-requests']} req, '
        '${headers['x-ratelimit-remaining-tokens']}/${headers['x-ratelimit-limit-tokens']} tok');
    debugPrint('╚══════════════════════════════');

    // JSON parse
    final chatMap = GeminiService.safeJsonDecode(reply);
    return ChefChatResponse.fromMap(chatMap);
  }

  /// Haftalık yemek planı üretir — Gemini ile aynı JSON formatında.
  /// Rate limit (429) veya hata alırsa GroqApiException fırlatır → caller fallback yapabilir.
  Future<MealPlan> generateMealPlan(
    UserPreferences preferences, {
    List<Recipe> cachedRecipes = const [],
    DateTime? startDate,
    int? selectedDayCount,
  }) async {
    await _ensureInitialized();

    final systemPrompt =
        await rootBundle.loadString('assets/gemini/system_prompt.md');

    final userInput = _buildMealPlanInput(preferences,
        startDate: startDate, overrideDayCount: selectedDayCount);

    // Cache section
    String cacheSection = '';
    if (cachedRecipes.isNotEmpty) {
      // Öğün planına göre slot sayısı
      final slotsPerDay = preferences.secilenOgunler.length;
      final effectiveStart = startDate ?? DateTime.now();
      final dayCount = selectedDayCount ??
          ((DateTime.sunday - effectiveStart.weekday) % 7 + 1);
      final totalSlots = slotsPerDay * dayCount;
      final minNewRecipes = (totalSlots * 0.25).ceil();
      final maxFromCache = totalSlots - minNewRecipes;
      final usableFromCache = cachedRecipes.take(maxFromCache).toList();
      final slotsForGemini = totalSlots - usableFromCache.length;

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
    }

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': '$userInput$cacheSection'},
    ];

    debugPrint('╔══ GROQ MEAL PLAN ════════════');
    debugPrint('║ Model: $_model');
    debugPrint('║ Day count: $selectedDayCount');
    debugPrint('╚══════════════════════════════');

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': _temperature,
        'max_tokens': 8192,
        'response_format': {'type': 'json_object'},
      }),
    );

    if (response.statusCode != 200) {
      RemoteLoggerService.error('groq_meal_plan_error',
        error: 'HTTP ${response.statusCode}: ${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
      throw GroqApiException(
        'Groq API hatası: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq boş yanıt döndü');
    }

    final reply = choices[0]['message']['content'] as String? ?? '';

    // Rate limit bilgisi logla
    final usage = data['usage'] as Map<String, dynamic>? ?? {};
    final headers = response.headers;
    debugPrint('╔══ GROQ MEAL PLAN DONE ═══════');
    debugPrint('║ Tokens: ${usage['total_tokens']} '
        '(prompt: ${usage['prompt_tokens']}, completion: ${usage['completion_tokens']})');
    debugPrint('║ Rate: ${headers['x-ratelimit-remaining-requests']}/${headers['x-ratelimit-limit-requests']} req');
    debugPrint('╚══════════════════════════════');

    return MealPlan.fromGeminiResponse(reply);
  }

  /// GeminiService._buildPreferencesJson ile aynı formatta input üretir
  String _buildMealPlanInput(UserPreferences preferences,
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

    final now = DateTime.now();
    final DateTime startDay = startDate ?? DateTime(now.year, now.month, now.day);
    final daysFromMonday = (startDay.weekday - DateTime.monday) % 7;
    final monday = startDay.subtract(Duration(days: daysFromMonday));
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

  String _currentSeason(DateTime now) {
    final month = now.month;
    if (month >= 3 && month <= 5) return 'ilkbahar';
    if (month >= 6 && month <= 8) return 'yaz';
    if (month >= 9 && month <= 11) return 'sonbahar';
    return 'kış';
  }

  /// Konuşma geçmişini sıfırlar
  void reset() {
    _history.clear();
  }

  /// Mevcut geçmiş uzunluğu
  int get historyLength => _history.length;

  int? _parseInt(String? value) {
    if (value == null) return null;
    return int.tryParse(value);
  }
}

/// Groq API yanıtı
class GroqResponse {
  final String reply;
  final GroqUsage usage;

  const GroqResponse({required this.reply, required this.usage});
}

/// Groq API kullanım + rate limit bilgisi
class GroqUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int? remainingRequests;
  final int? limitRequests;
  final int? remainingTokens;
  final int? limitTokens;
  final String? resetRequests;
  final String? resetTokens;

  const GroqUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.remainingRequests,
    this.limitRequests,
    this.remainingTokens,
    this.limitTokens,
    this.resetRequests,
    this.resetTokens,
  });
}

/// Groq API hata sınıfı
class GroqApiException implements Exception {
  final String message;
  final int statusCode;

  const GroqApiException(this.message, {required this.statusCode});

  @override
  String toString() => 'GroqApiException($statusCode): $message';
}
