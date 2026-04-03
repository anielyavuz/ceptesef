# CLAUDELogger.md — Remote Logger Entegrasyon Rehberi

Bu dosya, HeyMenu'deki Grafana/Loki tabanlı remote logging altyapısını başka bir Flutter uygulamasına entegre etmek için gerekli tüm bilgiyi içerir. Claude Code'a bu dosyayı verdiğinizde, aynı log sistemini yeni uygulamaya adapte edebilir.

## Genel Bakış

- **Hedef**: Grafana Loki'ye HTTP POST ile log göndermek
- **Protokol**: Loki Push API (`/loki/api/v1/push`)
- **Endpoint**: `https://logs.heymenu.org/loki/api/v1/push`
- **Bağımlılık**: Sadece `http` paketi (`pubspec.yaml`'a `http: ^1.1.0` ekle)
- **Mimari**: Tek statik sınıf, dependency injection yok, fire-and-forget

## Dosya: `lib/services/remote_logger_service.dart`

Aşağıdaki dosyayı projeye kopyala ve `'app'` label'ını kendi uygulama adınla değiştir.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RemoteLoggerService {
  // =============================================
  // DEĞİŞTİRİLMESİ GEREKEN DEĞERLER
  // =============================================
  static const String _lokiEndpoint = 'https://logs.heymenu.org/loki/api/v1/push';
  static const String _appName = 'heymenu'; // ← BUNU DEĞİŞTİR (ör: 'yeniuygulama')
  static const bool _isEnabled = true;

  // =============================================
  // CONTEXT (Login sonrası set edilir)
  // =============================================
  static String? _userId;
  static String? _userEmail;
  static String? _cafeId;      // Veya tenant/organization ID
  static String? _cafeName;
  static String? _currentScreen;

  /// Kullanıcı login olduğunda çağır
  static void setUserContext({
    required String userId,
    String? email,
    String? cafeId,
    String? cafeName,
  }) {
    _userId = userId;
    _userEmail = email;
    _cafeId = cafeId;
    _cafeName = cafeName;
  }

  /// Cafe/tenant değiştiğinde çağır
  static void setCafeContext({
    required String cafeId,
    String? cafeName,
  }) {
    _cafeId = cafeId;
    _cafeName = cafeName;
  }

  /// Ekran değiştiğinde çağır
  static void setScreen(String screenName) {
    _currentScreen = screenName;
  }

  /// Logout olduğunda çağır
  static void clearContext() {
    _userId = null;
    _userEmail = null;
    _cafeId = null;
    _cafeName = null;
    _currentScreen = null;
  }

  // =============================================
  // ANA LOG METODU
  // =============================================
  static Future<void> log({
    required String level,       // 'info', 'error', 'warning'
    required String message,
    String? restaurantId,        // Parametre olarak geçilirse context'i override eder
    String? screen,              // Parametre olarak geçilirse context'i override eder
    Map<String, dynamic>? extra, // Ek key-value çiftleri
  }) async {
    if (!_isEnabled || _lokiEndpoint.isEmpty) return;

    final timestamp = DateTime.now().microsecondsSinceEpoch * 1000; // Nanosecond

    final effectiveCafeId = restaurantId ?? _cafeId;
    final effectiveScreen = screen ?? _currentScreen ?? 'unknown';

    // Loki stream labels — Grafana'da filtreleme için
    // NOT: Label değerleri boş olamaz, null ise 'unknown' kullan
    final streamLabels = {
      'app': _appName,
      'level': level,
      'platform': 'flutter',
      'cafe_id': effectiveCafeId ?? 'unknown',
      'user_id': _userId ?? 'unknown',
      'screen': effectiveScreen,
    };

    // JSON body — detaylı bilgiler
    final logData = {
      'msg': message,
      if (_userId != null) 'user_id': _userId,
      if (_userEmail != null) 'user_email': _userEmail,
      if (effectiveCafeId != null) 'cafe_id': effectiveCafeId,
      if (_cafeName != null) 'cafe_name': _cafeName,
      'screen': effectiveScreen,
      ...?extra,
    };
    logData.removeWhere((key, value) => value == null);

    // Loki Push API payload formatı
    final payload = {
      'streams': [
        {
          'stream': streamLabels,
          'values': [
            [timestamp.toString(), jsonEncode(logData)]
          ],
        }
      ]
    };

    try {
      await http.post(
        Uri.parse(_lokiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      // Fire-and-forget: Sunucu kapalıysa uygulamayı etkileme
    }
  }

  // =============================================
  // KISAYOL METODLARI
  // =============================================

  /// Bilgi logu
  static void info(String msg, {String? restaurantId, String? screen}) =>
      log(level: 'info', message: msg, restaurantId: restaurantId, screen: screen);

  /// Hata logu
  static void error(String msg,
          {String? restaurantId, String? screen, dynamic error, StackTrace? stackTrace}) =>
      log(
        level: 'error',
        message: msg,
        restaurantId: restaurantId,
        screen: screen,
        extra: {
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stack_trace': stackTrace.toString(),
        },
      );

  /// Uyarı logu
  static void warning(String msg, {String? restaurantId, String? screen}) =>
      log(level: 'warning', message: msg, restaurantId: restaurantId, screen: screen);

  /// Kullanıcı aksiyonu
  static void userAction(String action,
          {String? restaurantId, String? screen, Map<String, dynamic>? details}) =>
      log(
        level: 'info',
        message: action,
        restaurantId: restaurantId,
        screen: screen,
        extra: {'type': 'user_action', ...?details},
      );

  /// Performans logu
  static void performance(String operation, int durationMs,
          {String? restaurantId, String? screen}) =>
      log(
        level: 'info',
        message: 'Performance: $operation',
        restaurantId: restaurantId,
        screen: screen,
        extra: {'type': 'performance', 'duration_ms': durationMs},
      );
}
```

## Entegrasyon Adımları

### 1. Dosyayı Kopyala
`lib/services/remote_logger_service.dart` dosyasını yeni projeye kopyala.

### 2. App Adını Değiştir
```dart
static const String _appName = 'yeniuygulama'; // ← Kendi app adın
```
Bu değer Grafana'da `{app="yeniuygulama"}` olarak filtrelenecek.

### 3. pubspec.yaml'a Bağımlılık Ekle
```yaml
dependencies:
  http: ^1.1.0
```

### 4. Login Sonrası Context Set Et
```dart
// Kullanıcı login olduktan sonra:
RemoteLoggerService.setUserContext(
  userId: user.uid,
  email: user.email,
  cafeId: userCafeId,       // Opsiyonel — tenant/org ID
  cafeName: userCafeName,   // Opsiyonel
);
```

### 5. Logout'ta Context Temizle
```dart
RemoteLoggerService.clearContext();
```

### 6. Log Gönder
```dart
// Bilgi
RemoteLoggerService.info('Uygulama Açıldı', screen: 'main');

// Hata
RemoteLoggerService.error('Veri Yüklenemedi', screen: 'home_page', error: e, stackTrace: st);

// Uyarı
RemoteLoggerService.warning('Bağlantı Yavaş', screen: 'settings_page');

// Kullanıcı aksiyonu
RemoteLoggerService.userAction('Butona Tıklandı', screen: 'profile_page', details: {'button': 'save'});

// Performans
RemoteLoggerService.performance('veri_yukle', 1200, screen: 'home_page');
```

## Loki Payload Formatı

Her log şu yapıda Loki'ye gönderilir:

```json
{
  "streams": [
    {
      "stream": {
        "app": "yeniuygulama",
        "level": "info",
        "platform": "flutter",
        "cafe_id": "abc123",
        "user_id": "user456",
        "screen": "home_page"
      },
      "values": [
        ["1710000000000000000", "{\"msg\":\"Uygulama Açıldı\",\"user_id\":\"user456\",\"screen\":\"home_page\"}"]
      ]
    }
  ]
}
```

- **`stream`**: Loki label'ları — Grafana'da `{app="yeniuygulama", level="error"}` şeklinde filtrelenir
- **`values[0][0]`**: Nanosecond timestamp (string)
- **`values[0][1]`**: JSON-encoded log body

## Grafana Sorgu Örnekleri (LogQL)

```logql
# Yeni uygulamanın tüm logları
{app="yeniuygulama"}

# Sadece hatalar
{app="yeniuygulama", level="error"}

# Belirli bir ekranın logları
{app="yeniuygulama", screen="home_page"}

# Belirli bir kullanıcının logları
{app="yeniuygulama", user_id="user456"}

# Her iki uygulamayı birlikte görmek
{app=~"heymenu|yeniuygulama"}

# JSON body içinde arama
{app="yeniuygulama"} |= "Veri Yüklenemedi"
```

## Özelleştirme — Uygulamaya Özel Metodlar

Yeni uygulamaya özel log metodları eklemek için `log()` metodunu `extra` parametresiyle genişlet:

```dart
// Örnek: Ödeme eventi
static void paymentEvent(String event, String paymentId, double amount, {String? screen}) =>
    log(
      level: 'info',
      message: event,
      screen: screen,
      extra: {'type': 'payment', 'payment_id': paymentId, 'amount': amount},
    );

// Örnek: Push notification eventi
static void notificationEvent(String event, {String? screen, String? notificationId}) =>
    log(
      level: 'info',
      message: event,
      screen: screen,
      extra: {'type': 'notification', if (notificationId != null) 'notification_id': notificationId},
    );
```

## Önemli Kurallar

1. **Fire-and-forget**: Log gönderimi başarısız olursa sessizce geçilir, uygulama etkilenmez
2. **Label değerleri boş olamaz**: Loki null/empty label kabul etmez, `'unknown'` fallback kullanılır
3. **Hassas veri gönderme**: Şifre, token, kişisel bilgi loglanmamalı
4. **Yüksek frekanslı loglardan kaçın**: Döngü içinde veya scroll event'lerinde log gönderme
5. **Timestamp**: Nanosecond çözünürlükte — `microsecondsSinceEpoch * 1000`
6. **Context önceliği**: Metoda parametre olarak geçilen değerler, `setUserContext`'teki değerleri override eder
