import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../constants/firestore_paths.dart';
import '../models/market_price.dart';
import 'firestore_service.dart';
import 'remote_logger_service.dart';

/// Firestore'daki günlük market fiyat verilerini çeken servis.
/// `marketFiyatlar/{YYYYMMDD}` yapısından okur.
/// Groq AI ile akıllı malzeme-ürün eşleştirmesi yapar.
class MarketPriceService {
  final FirebaseFirestore _firestore;
  final FirestoreService _firestoreService;

  // Günlük cache — aynı gün içinde tekrar Firestore'a gitmez
  Map<String, dynamic>? _cachedUrunIndex;
  Map<String, Map<String, dynamic>>? _cachedKategoriData;
  String? _cachedDateId;

  // AI eşleştirme cache — ürün bazlı (yeni ürün eklenirse sadece yenisi için Groq'a gider)
  Map<String, String?>? _cachedAiMatches;

  /// Verinin geldiği gerçek tarih (bugün değilse önceki güne fallback yapılmış demek)
  DateTime? _dataDate;

  // Groq config (lazy init)
  String? _groqApiKey;
  String? _groqModel;

  static const String _groqBaseUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  MarketPriceService({
    FirebaseFirestore? firestore,
    required FirestoreService firestoreService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firestoreService = firestoreService;

  String get _todayDocId => DateFormat('yyyyMMdd').format(DateTime.now());

  /// Verinin geldiği gerçek tarih — UI'da "Son güncelleme X gün önce" için
  DateTime? get dataDate => _dataDate;

  /// Cache'i temizle
  void invalidateCache() {
    _cachedUrunIndex = null;
    _cachedKategoriData = null;
    _cachedDateId = null;
    _cachedAiMatches = null;
    _dataDate = null;
  }

  /// Groq API key ve model adını Firestore'dan çeker (lazy)
  Future<void> _ensureGroqInitialized() async {
    if (_groqApiKey != null) return;
    final config = await _firestoreService.getAppConfig();
    _groqApiKey = config.groqApiKey;
    _groqModel = config.groqModelName.isNotEmpty
        ? config.groqModelName
        : 'llama-3.3-70b-versatile';
  }

  /// Metadata'yı (urunIndex) çek veya cache'den döndür.
  /// Bugünün verisi yoksa en fazla 7 gün geriye giderek en yakın veriyi bulur.
  Future<Map<String, dynamic>?> _getUrunIndex() async {
    if (_cachedDateId != null && _cachedUrunIndex != null) {
      // Cache hâlâ geçerli (aynı oturum içinde tekrar sorgulamaya gerek yok)
      return _cachedUrunIndex;
    }

    try {
      final now = DateTime.now();
      for (int daysBack = 0; daysBack <= 7; daysBack++) {
        final date = now.subtract(Duration(days: daysBack));
        final docId = DateFormat('yyyyMMdd').format(date);

        final metaSnap = await _firestore
            .collection(FirestorePaths.marketFiyatlarCollection)
            .doc(docId)
            .get();

        if (metaSnap.exists && metaSnap.data() != null) {
          final urunIndex =
              metaSnap.data()!['urunIndex'] as Map<String, dynamic>?;
          if (urunIndex != null && urunIndex.isNotEmpty) {
            _cachedUrunIndex = urunIndex;
            _cachedDateId = docId;
            _cachedKategoriData = {};
            _dataDate = date;
            if (daysBack > 0) {
              debugPrint(
                  '║ Bugünün fiyat verisi yok, $daysBack gün önceki veri kullanılıyor ($docId)');
            }
            return _cachedUrunIndex;
          }
        }
      }
      return null;
    } catch (e) {
      RemoteLoggerService.error('market_price_meta_fetch_error', error: e);
      return null;
    }
  }

  /// Tek bir kategori verisini çek veya cache'den döndür
  Future<Map<String, dynamic>?> _getKategoriData(String kategori) async {
    _cachedKategoriData ??= {};

    if (_cachedDateId != null &&
        _cachedKategoriData!.containsKey(kategori)) {
      return _cachedKategoriData![kategori];
    }

    // _cachedDateId, _getUrunIndex tarafından belirlenen gerçek veri tarihidir
    final dateDocId = _cachedDateId ?? _todayDocId;

    try {
      final katSnap = await _firestore
          .collection(FirestorePaths.marketFiyatlarCollection)
          .doc(dateDocId)
          .collection(FirestorePaths.marketKategorilerSubcollection)
          .doc(kategori)
          .get();

      if (!katSnap.exists || katSnap.data() == null) return null;

      final data = katSnap.data()!['urunler'] as Map<String, dynamic>?;
      if (data != null) {
        _cachedKategoriData![kategori] = data;
      }
      return data;
    } catch (e) {
      RemoteLoggerService.error('market_price_kategori_fetch_error',
          error: e);
      return null;
    }
  }

  // ─── Malzeme Adı Temizleme ────────────────────────────

  /// Malzeme adından miktar/birim bilgisini temizler.
  /// "kilo domates" → "domates"
  /// "mini salatalık" → "salatalık"  (mini gibi sıfatları bırak)
  /// "yeşil elma" → "yeşil elma" (renk sıfatı anlamlı, bırak)
  static String _cleanIngredientName(String raw) {
    var name = raw.trim().toLowerCase();

    // 1) Parantez içindeki açıklamaları kaldır: "(yaklaşık 100 gr)", "(1 adet)"
    name = name.replaceAll(RegExp(r'\(.*?\)'), '');

    // 2) Baştaki kesirli sayılar: "1/2 demet" → "demet"
    name = name.replaceFirst(RegExp(r'^\d+[/\.]\d+\s*'), '');

    // 3) Baştaki sayı + birim kalıplarını temizle
    name = name.replaceFirst(
        RegExp(r'^\d+[\.,]?\d*\s*'
            r'(kilo|kg|gr|g|lt|ml|adet|demet|paket|poşet|kutu|şişe|'
            r'kavanoz|bardak|kaşık|dilim|tane|ince dilim|büyük|küçük|'
            r'orta|çay kaşığı|yemek kaşığı|su bardağı|tutam|yaprak|dal|diş)\s*'),
        '');

    // 4) Hâlâ baştaki sayı kaldıysa temizle
    name = name.replaceFirst(RegExp(r'^\d+[\.,]?\d*\s*'), '');

    // 5) Boyut/miktar sıfatlarını kaldır
    name = name.replaceFirst(
        RegExp(r'^(yarım|yarim|çeyrek|küçük|büyük|orta|ince|kalın|taze|'
            r'kucuk|buyuk|kalin)\s+'),
        '');

    // 6) Kalan birim kelimelerini baştansa kaldır (parantez temizliğinden sonra)
    name = name.replaceFirst(
        RegExp(r'^(demet|tutam|dal|diş|dilim|yaprak|adet)\s+'), '');

    return name.trim();
  }

  // ─── Ürün Filtreleme ───────────────────────────────────

  /// Ürün listesinden malzemeye uygun olmayanları filtreler.
  /// "domates" aramasında "Domates Suyu" yerine gerçek domates ürünlerini döndürür.
  /// Dönen tuple: (filtrelenmiş ürünler, sadece işlenmiş mi?)
  static (List<MarketProduct>, bool) _filterRelevantProducts(
    String ingredientName,
    List<MarketProduct> products,
    String kategori,
  ) {
    if (products.length <= 1) return (products, false);

    // Malzeme adındaki anahtar kelime
    final ingredient = ingredientName.toLowerCase();

    // İşlenmiş ürün göstergeleri — title'da bunlar varsa muhtemelen yanlış eşleşme
    const processedSuffixes = [
      // Sıvı/sos türevleri
      'suyu', 'sirkesi', 'salçası', 'sosu', 'şurubu', 'özü',
      'nektarı', 'nektar',
      // Konserve/turşu (Türkçe + ASCII varyantları)
      'turşusu', 'turşu', 'tursu', 'tursuu',
      'konservesi', 'konserve',
      // İşlenmiş form göstergeleri
      'püresi', 'ezmesi', 'reçeli', 'marmelatı',
      'rendelenmiş', 'rendelenmis', 'doğranmış', 'dogranmis',
      'dilimlenmiş', 'dilimlenmis', 'kurutulmuş', 'kurutulmus',
      // Toz/hazır/paket ürünler
      'toz', 'aromalı', 'aromali',
      'hazır', 'hazir', 'instant',
      // İçecek göstergeleri
      'içecek', 'icecek', 'drink',
      // Ambalaj göstergeleri (kavanoz/kutu genelde işlenmiş)
      'kavanoz', 'kutu',
      // Temizlik/kozmetik ürünleri (yanlış kategorilendirme)
      'sabun', 'deterjan', 'şampuan', 'sampuan', 'krem',
      'losyon', 'parfüm', 'parfum', 'çiçeği', 'cicegi',
      'peros', 'yumuşatıcı', 'yumusatici', 'çamaşır', 'camasir',
      'bulaşık', 'bulasik',
    ];

    // Hazır gıda/tatlı markaları — et/tavuk kategorisinde bunlar taze ürün değil
    const processedBrands = [
      'dr. oetker', 'dr.oetker', 'knorr', 'maggi',
      'pınar', 'pinar', 'sadia', 'banvit', 'beşler', 'besler',
      'superfresh', 'dardanel', 'yayla', 'ülker', 'ulker',
      'eti', 'torku', 'cool cook',
    ];

    // TÜM kategorilerde filtre uygula (kozmetik vb. her yerde olabilir)
    // Ama ek skor kuralları sadece taze kategorilerde
    const freshCategories = {
      'sebzeler', 'meyveler', 'et_tavuk', 'balik_deniz', 'yumurta',
    };

    // Taze kategoriler dışında da temizlik/kozmetik filtresi uygula
    final isFreshCategory = freshCategories.contains(kategori);

    final scored = <_ScoredProduct>[];

    for (final product in products) {
      final titleLower = product.title.toLowerCase();
      final weight = (product.weightLabel ?? '').toUpperCase();
      int score = 0;

      // 1) Sıvı ürün penaltı: ML veya LT birimli → muhtemelen suyu/sirkesi/sos
      //    Ama yag, icecekler, sos_sirke gibi doğası gereği sıvı kategorilerde penaltı VERME
      const liquidCategories = {
        'yag', 'icecekler', 'sos_sirke', 'sut_urunleri',
      };
      if ((weight.contains('ML') || weight.contains('LT')) &&
          !liquidCategories.contains(kategori)) {
        score -= 50;
      }

      // 2) İşlenmiş ürün penaltı
      for (final suffix in processedSuffixes) {
        if (titleLower.contains(suffix)) {
          score -= 30;
          break;
        }
      }

      // 3) "Kesim", "Sandviç", "Burger" gibi hazır gıda göstergeleri
      if (titleLower.contains('kesim') ||
          titleLower.contains('sandviç') ||
          titleLower.contains('burger')) {
        score -= 20;
      }

      // 3b) Hazır gıda/tatlı markası → çok güçlü penaltı
      if (product.brand != null && product.brand!.isNotEmpty) {
        final brandLower = product.brand!.toLowerCase();
        final isProcessedBrand =
            processedBrands.any((b) => brandLower.contains(b));
        if (isProcessedBrand) {
          score -= 80; // Dr. Oetker tavuk göğsü tatlısı vs gerçek tavuk
        } else if (isFreshCategory && !brandLower.contains(ingredient)) {
          score -= 15; // Taze kategoride bilinmeyen marka
        }
      }

      // 3c) GR birimli küçük paket + et kategorisi = hazır gıda
      if (isFreshCategory && kategori == 'et_tavuk') {
        final grMatch = RegExp(r'(\d+)\s*gr', caseSensitive: false)
            .firstMatch(weight);
        if (grMatch != null) {
          final grams = int.tryParse(grMatch.group(1)!) ?? 0;
          if (grams < 300) score -= 40; // 129gr tavuk göğsü = tatlı paketi
        }
      }

      // 4) KG birim bonus — taze ürünler genelde kg ile satılır
      if (weight.contains('KG')) {
        score += 20;
      }
      // ADET birim de taze ürün olabilir (ör: "Elma Starking 1 Adet")
      if (weight.contains('ADET')) {
        score += 10;
      }

      // 5) Malzeme adı title'ın başında veya tek başınaysa bonus
      final words = titleLower.split(RegExp(r'\s+'));
      final ingredientWords = ingredient.split(RegExp(r'\s+'));
      final mainIngredient = ingredientWords.last; // "yeşil elma" → "elma"

      // Title tam olarak malzeme adıyla başlıyorsa güçlü bonus
      if (words.isNotEmpty && words.first == mainIngredient) {
        score += 25;
      } else if (words.isNotEmpty && words.first.contains(mainIngredient)) {
        score += 15;
      }

      // 5b) Title sadece malzeme adı + ağırlık/adet ise en güçlü bonus
      final titleWithoutWeight = titleLower
          .replaceAll(RegExp(r'\d+[\.,]?\d*\s*(kg|gr|g|ml|lt|adet)\b'), '')
          .trim();
      if (titleWithoutWeight == mainIngredient ||
          titleWithoutWeight == ingredient) {
        score += 30;
      }

      // 6) Title kısa = daha spesifik ürün
      if (words.length <= 3) {
        score += 5;
      }

      scored.add(_ScoredProduct(product: product, score: score));
    }

    // Score'a göre sırala (yüksek = daha uygun)
    scored.sort((a, b) => b.score.compareTo(a.score));

    // Pozitif veya 0 score'lu ürünler varsa sadece onları döndür
    final relevant = scored.where((s) => s.score >= 0).toList();
    if (relevant.isNotEmpty) {
      debugPrint('║ Filter: "$ingredientName" → '
          '${relevant.length}/${products.length} ürün kaldı '
          '(en iyi: ${relevant.first.product.title})');
      return (relevant.map((s) => s.product).toList(), false);
    }

    // Hepsi negatif score'lu → en yüksek score'luları döndür (en az kötü)
    debugPrint('║ Filter: "$ingredientName" → tümü işlenmiş, '
        'en iyi: ${scored.first.product.title}');
    return (scored.take(3).map((s) => s.product).toList(), true);
  }

  // ─── AI Eşleştirme (Groq — bağımsız HTTP) ────────────

  /// Groq AI ile malzeme adlarını urunIndex key'lerine eşler.
  /// Sohbet geçmişine karıştırmaz, response_format: json_object kullanır.
  Future<Map<String, String?>> _matchWithAI(
    List<String> cleanedNames,
    Map<String, dynamic> urunIndex, {
    List<String> mealContext = const [],
  }) async {
    // Akıllı cache — daha önce eşleştirilmiş ürünleri koru, sadece yeniler için Groq'a git
    final Map<String, String?> cachedResults = {};
    final List<String> uncachedNames = [];

    for (final name in cleanedNames) {
      if (_cachedAiMatches != null && _cachedAiMatches!.containsKey(name)) {
        cachedResults[name] = _cachedAiMatches![name];
      } else {
        uncachedNames.add(name);
      }
    }

    // Tüm ürünler cache'de → direkt dön
    if (uncachedNames.isEmpty) {
      debugPrint('║ AI cache: tümü cache\'de (${cachedResults.length} ürün)');
      return cachedResults;
    }

    debugPrint('║ AI cache: ${cachedResults.length} cache\'de, '
        '${uncachedNames.length} yeni → Groq\'a gidiliyor');

    try {
      await _ensureGroqInitialized();
      if (_groqApiKey == null || _groqApiKey!.isEmpty) return cachedResults;

      final availableKeys = urunIndex.keys.toList()..sort();

      // Ürünleri kategorilere göre grupla (daha okunabilir prompt)
      final Map<String, List<String>> grouped = {};
      for (final key in availableKeys) {
        final kat = urunIndex[key] as String? ?? 'diger';
        grouped.putIfAbsent(kat, () => []).add(key);
      }
      final productBlock = StringBuffer();
      for (final entry in grouped.entries) {
        productBlock.writeln('${entry.key}: ${entry.value.join(", ")}');
      }

      // Sadece yeni (cache'de olmayan) malzemeleri Groq'a gönder
      final asciiNames = uncachedNames.map((n) => _toAscii(n)).toList();

      final systemPrompt =
          'Sen bir Türk marketi alışveriş asistanısın. Verilen alışveriş malzemelerini marketteki ürün listesindeki doğru key ile eşleştiriyorsun. HER ZAMAN taze/çiğ/ham ürün key\'ini tercih et. Yanıtını SADECE JSON olarak ver.';

      // Tarif bağlamı — malzemelerin hangi yemekte kullanılacağı
      final contextBlock = mealContext.isNotEmpty
          ? '\nBu malzemeler şu yemekler için: ${mealContext.join(", ")}\nBu bilgiyi kullanarak taze/pişirmeye uygun ürünleri tercih et.\n'
          : '';

      final userPrompt = '''Alışveriş listemdeki her malzeme için aşağıdaki ürün listesinden en uygun eşleşmeyi bul.
$contextBlock
ÖNEMLİ KURALLAR:
1. HER ZAMAN TAZE/ÇİĞ/HAM ürün key'ini tercih et. İşlenmiş key'leri (suyu, tursu, sosu, salçası, sirkesi, kurutulmus, rendelenmis ekli) ASLA seçme.
2. Listede malzemenin direkt adı varsa (ör: "domates", "salatalik", "tavuk gogsu", "marul"), HER ZAMAN O KEY'İ SEÇ.
3. Eşleşme bulunamazsa null yaz.
4. Yanıttaki key'ler AYNEN ürün listesindeki gibi olmalı.

MALZEMELER:
${asciiNames.map((n) => '- $n').join('\n')}

ÜRÜN LİSTESİ (kategori: ürünler):
$productBlock

JSON YANIT:
{"sonuc": {"malzeme_ascii": "urun_key veya null"}}''';

      final response = await http.post(
        Uri.parse(_groqBaseUrl),
        headers: {
          'Authorization': 'Bearer $_groqApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.1,
          'max_tokens': 1024,
          'response_format': {'type': 'json_object'},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('⚠️ Groq AI HTTP ${response.statusCode}: '
            '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
        return {};
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return {};

      final reply = choices[0]['message']['content'] as String? ?? '';

      // Kullanım bilgisi logla
      final usage = data['usage'] as Map<String, dynamic>? ?? {};
      debugPrint('╔══ GROQ PRICE MATCH ═════════');
      debugPrint('║ Tokens: ${usage['total_tokens']} '
          '(prompt: ${usage['prompt_tokens']}, completion: ${usage['completion_tokens']})');
      debugPrint('║ Raw reply: $reply');
      debugPrint('╚════════════════════════════');

      // JSON parse
      var cleaned = reply.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
      }

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;

      // "sonuc", "eşleşmeler", "eslesmeler" veya direkt map
      final matches = parsed['sonuc'] as Map<String, dynamic>? ??
          parsed['eşleşmeler'] as Map<String, dynamic>? ??
          parsed['eslesmeler'] as Map<String, dynamic>? ??
          parsed;

      // Groq sonuçlarını parse et — sadece uncachedNames için
      final newMatches = <String, String?>{};
      for (final name in uncachedNames) {
        final ascii = _toAscii(name);
        String? matchedValue;
        for (final entry in matches.entries) {
          final entryKey = entry.key.trim().toLowerCase();
          if (entryKey == name || entryKey == ascii) {
            final val = entry.value;
            if (val == null || val == 'null' || val == '') {
              matchedValue = null;
            } else {
              matchedValue = val.toString().trim().toLowerCase();
            }
            break;
          }
        }
        newMatches[name] = matchedValue;
      }

      // Cache'e birleştirerek yaz (eski + yeni)
      _cachedAiMatches ??= {};
      _cachedAiMatches!.addAll(newMatches);

      // Sonuç: cache + yeni
      final result = <String, String?>{};
      result.addAll(cachedResults);
      result.addAll(newMatches);

      debugPrint('╔══ AI MATCHING RESULTS ══════');
      for (final entry in result.entries) {
        debugPrint(
            '║ ${entry.key} → ${entry.value ?? "❌ bulunamadı"}');
      }
      debugPrint('╚════════════════════════════');

      RemoteLoggerService.info('ai_ingredient_matching',
          extra: {
            'total': cleanedNames.length,
            'matched': result.values.where((v) => v != null).length,
          });

      return result;
    } catch (e) {
      RemoteLoggerService.error('ai_matching_error', error: e);
      debugPrint('⚠️ AI eşleştirme hatası, fallback kullanılacak: $e');
      return {};
    }
  }

  // ─── Fiyat Sorgulama ────────────────────────────────────

  /// Birden fazla malzeme için toplu fiyat sorgulama.
  /// Önce Groq AI ile akıllı eşleştirme yapar,
  /// başarısız olursa string-based fallback kullanır.
  Future<List<IngredientPriceResult>> getIngredientPrices(
      List<String> ingredientNames, {
      List<String> mealContext = const [],
      List<String> preferredMarkets = const [],
  }) async {
    final urunIndex = await _getUrunIndex();
    if (urunIndex == null) {
      return ingredientNames
          .map((name) =>
              IngredientPriceResult(ingredientName: name, products: []))
          .toList();
    }

    // 1) Malzeme adlarını temizle (miktar/birim kaldır) + ASCII normalize
    //    Firebase key'leri ASCII (ö→o, ğ→g, ş→s, ç→c, ü→u, ı→i)
    final Map<String, String> rawToClean = {};
    for (final name in ingredientNames) {
      final cleaned = _cleanIngredientName(name);
      rawToClean[name] = cleaned;
    }

    debugPrint('╔══ CLEANED NAMES ═══════════');
    for (final entry in rawToClean.entries) {
      debugPrint('║ "${entry.key}" → "${entry.value}"');
    }
    debugPrint('╚════════════════════════════');

    final cleanedNames = rawToClean.values.toSet().toList();

    // 2) AI eşleştirme dene
    final aiMatches = await _matchWithAI(cleanedNames, urunIndex,
        mealContext: mealContext);
    final useAI = aiMatches.isNotEmpty;

    // 3) Her malzeme için urunIndex key'ini belirle
    final Map<String, String?> ingredientToKey = {};

    for (final name in ingredientNames) {
      final cleaned = rawToClean[name]!;

      String? matchedKey;

      // AI eşleştirmesi dene
      if (useAI && aiMatches.containsKey(cleaned)) {
        final aiKey = aiMatches[cleaned];
        if (aiKey != null && urunIndex.containsKey(aiKey)) {
          matchedKey = aiKey;
        }
      }

      // AI bulamadıysa fallback dene (ASCII normalizasyonlu)
      matchedKey ??= _fallbackMatch(cleaned, urunIndex);

      ingredientToKey[name] = matchedKey;
    }

    // 4) Gerekli kategorileri belirle ve paralel çek
    final Map<String, Set<String>> kategoriToIngredients = {};
    for (final name in ingredientNames) {
      final key = ingredientToKey[name];
      if (key == null) continue;
      final kategori = urunIndex[key] as String?;
      if (kategori == null) continue;
      kategoriToIngredients.putIfAbsent(kategori, () => {}).add(name);
    }

    final futures = kategoriToIngredients.keys
        .map((kat) => _getKategoriData(kat))
        .toList();
    final kategoriResults = await Future.wait(futures);

    final Map<String, Map<String, dynamic>> kategoriDataMap = {};
    int idx = 0;
    for (final kat in kategoriToIngredients.keys) {
      if (kategoriResults[idx] != null) {
        kategoriDataMap[kat] = kategoriResults[idx]!;
      }
      idx++;
    }

    // 5) Her malzeme için sonuç oluştur + ürün filtrele
    final results = <IngredientPriceResult>[];
    for (final name in ingredientNames) {
      final matchedKey = ingredientToKey[name];

      if (matchedKey == null) {
        results
            .add(IngredientPriceResult(ingredientName: name, products: []));
        continue;
      }

      final kategori = urunIndex[matchedKey] as String?;
      if (kategori == null || !kategoriDataMap.containsKey(kategori)) {
        results
            .add(IngredientPriceResult(ingredientName: name, products: []));
        continue;
      }

      final urunlerData = kategoriDataMap[kategori]!;
      final urunData = urunlerData[matchedKey] as Map<String, dynamic>?;

      var productsList = urunData == null
          ? <MarketProduct>[]
          : (urunData['products'] as List<dynamic>?)
                  ?.map(
                      (e) => MarketProduct.fromMap(e as Map<String, dynamic>))
                  .toList() ??
              [];

      // Ürünleri filtrele — işlenmiş ürünleri ele
      final cleanedName = rawToClean[name]!;
      final (filtered, onlyProcessed) =
          _filterRelevantProducts(cleanedName, productsList, kategori);

      // Market filtresi uygula — tercih edilen marketler dışındakileri kaldır
      final marketFiltered = preferredMarkets.isEmpty
          ? filtered
          : _applyMarketFilter(filtered, preferredMarkets);

      results.add(IngredientPriceResult(
        ingredientName: name,
        category: kategori,
        products: marketFiltered,
        onlyProcessed: onlyProcessed,
      ));
    }

    return results;
  }

  /// Market filtresi — sadece tercih edilen marketlerin offer'larını bırakır.
  static List<MarketProduct> _applyMarketFilter(
      List<MarketProduct> products, List<String> preferredMarkets) {
    final filtered = <MarketProduct>[];
    for (final product in products) {
      final filteredMarkets = product.markets
          .where((m) => preferredMarkets.contains(m.marketName))
          .toList();
      if (filteredMarkets.isEmpty) continue;
      // Cheapest'ı güncelle
      final cheapest = filteredMarkets.reduce(
          (a, b) => a.price <= b.price ? a : b);
      filtered.add(MarketProduct(
        productId: product.productId,
        title: product.title,
        brand: product.brand,
        imageUrl: product.imageUrl,
        weightLabel: product.weightLabel,
        cheapest: cheapest,
        markets: filteredMarkets,
      ));
    }
    return filtered;
  }

  /// String-based fallback eşleştirme.
  /// Exact match + Türkçe ASCII normalizasyonu kullanır.
  String? _fallbackMatch(String cleaned, Map<String, dynamic> urunIndex) {
    if (urunIndex.containsKey(cleaned)) return cleaned;

    final ascii = _toAscii(cleaned);
    for (final key in urunIndex.keys) {
      if (key == ascii || _toAscii(key) == ascii) {
        return key;
      }
    }

    return null;
  }

  /// Türkçe karakterleri ASCII'ye çevirir
  static String _toAscii(String input) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'C', 'Ğ': 'G', 'İ': 'I', 'Ö': 'O', 'Ş': 'S', 'Ü': 'U',
    };
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(map[char] ?? char);
    }
    return buffer.toString();
  }

  // ─── Tek ürün sorgulama ─────────────────────────────────

  /// Tek bir malzeme adı için fiyat sonucu döndürür.
  Future<IngredientPriceResult?> getIngredientPrice(
      String ingredientName) async {
    final results = await getIngredientPrices([ingredientName]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Ürün index'inde keyword araması yapar (AI kullanmaz).
  /// Dönen liste: eşleşen key'ler ve o key'in kategorisi.
  Future<List<IngredientPriceResult>> searchProducts(
      String keyword, {List<String> preferredMarkets = const []}) async {
    final urunIndex = await _getUrunIndex();
    if (urunIndex == null) return [];

    final normalized = keyword.trim().toLowerCase();
    final ascii = _toAscii(normalized);
    if (ascii.length < 2) return [];

    // Key'lerde arama
    final matchedKeys = <String>[];
    for (final key in urunIndex.keys) {
      if (key.contains(ascii) || ascii.contains(key)) {
        matchedKeys.add(key);
      }
    }

    if (matchedKeys.isEmpty) return [];

    // Kategorileri çek
    final Set<String> categories = {};
    for (final key in matchedKeys) {
      categories.add(urunIndex[key] as String);
    }

    for (final kat in categories) {
      await _getKategoriData(kat);
    }

    // Sonuçları oluştur
    final results = <IngredientPriceResult>[];
    for (final key in matchedKeys.take(10)) {
      final kategori = urunIndex[key] as String;
      final katData = _cachedKategoriData?[kategori];
      if (katData == null) continue;

      final urunData = katData[key] as Map<String, dynamic>?;
      if (urunData == null) continue;

      var productsList = (urunData['products'] as List<dynamic>?)
              ?.map((e) => MarketProduct.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [];

      if (preferredMarkets.isNotEmpty) {
        productsList = _applyMarketFilter(productsList, preferredMarkets);
      }

      if (productsList.isNotEmpty) {
        results.add(IngredientPriceResult(
          ingredientName: key,
          category: kategori,
          products: productsList,
        ));
      }
    }

    return results;
  }

  // ─── Gruplandırma ───────────────────────────────────────

  /// Alışveriş listesindeki ürünleri markete göre akıllı gruplar.
  static List<MarketGroup> groupByOptimalMarket(
      List<IngredientPriceResult> priceResults) {
    final Map<String, List<MarketGroupItem>> marketItems = {};
    final Map<String, String> displayNames = {};

    for (final result in priceResults) {
      if (result.products.isEmpty) continue;

      MarketProduct? cheapestProduct;
      for (final product in result.products) {
        if (cheapestProduct == null ||
            product.cheapest.price < cheapestProduct.cheapest.price) {
          cheapestProduct = product;
        }
      }

      if (cheapestProduct == null) continue;

      final marketKey = cheapestProduct.cheapest.marketName;
      final displayName = cheapestProduct.cheapest.displayName;

      marketItems.putIfAbsent(marketKey, () => []);
      marketItems[marketKey]!.add(MarketGroupItem(
        ingredientName: result.ingredientName,
        productTitle: cheapestProduct.title,
        price: cheapestProduct.cheapest.price,
        unitPrice: cheapestProduct.cheapest.unitPrice,
        imageUrl: cheapestProduct.imageUrl,
        weightLabel: cheapestProduct.weightLabel,
      ));

      displayNames.putIfAbsent(marketKey, () => displayName);
    }

    final groups = marketItems.entries.map((entry) {
      return MarketGroup(
        marketDisplayName:
            displayNames[entry.key] ?? entry.key.toUpperCase(),
        marketName: entry.key,
        items: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.items.length.compareTo(a.items.length));
    return groups;
  }

  /// Tek bir marketten tüm ürünleri alsa toplam ne kadar tutar?
  static Map<String, double> calculateSingleMarketTotals(
      List<IngredientPriceResult> priceResults) {
    final Set<String> allMarkets = {};
    for (final result in priceResults) {
      for (final product in result.products) {
        for (final market in product.markets) {
          allMarkets.add(market.marketName);
        }
      }
    }

    final Map<String, double> totals = {};
    for (final marketName in allMarkets) {
      double total = 0;
      int foundCount = 0;
      for (final result in priceResults) {
        double? cheapestInMarket;
        for (final product in result.products) {
          for (final offer in product.markets) {
            if (offer.marketName == marketName) {
              if (cheapestInMarket == null ||
                  offer.price < cheapestInMarket) {
                cheapestInMarket = offer.price;
              }
            }
          }
        }
        if (cheapestInMarket != null) {
          total += cheapestInMarket;
          foundCount++;
        }
      }
      if (foundCount > 0) {
        totals[marketName] = total;
      }
    }
    return totals;
  }
}

/// Ürün + skor çifti (filtreleme sıralaması için)
class _ScoredProduct {
  final MarketProduct product;
  final int score;
  const _ScoredProduct({required this.product, required this.score});
}
