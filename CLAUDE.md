

# 🧠 BEYİN — Zorunlu Bilgi Tabanı Kuralları

> **Bu kurallar her oturumda geçerlidir. Atlanmaz.**

## Oturum Başlangıcı
1. Brain vault'tan bu projeyle ilgili notları ara: `search_notes(query="ceptesef")`
2. Shared pattern'leri kontrol et: `list_notes(folder="knowledge/shared")`
3. `top-of-mind` notunu oku: `read_note(path="00-home/top-of-mind.md")`

## Çalışma Sırası
- Bir sorunla karşılaşınca **önce vault'ta ara** — daha önce çözülmüş olabilir
- Yeni bir pattern/çözüm/karar keşfedince **vault'a kaydet** (`create_note`)
- Cepteşef'e özel → `knowledge/ceptesef/`
- Ortak (Flutter/Firebase/genel) → `knowledge/shared/`

## İşlem Sonu Checkpoint (Zorunlu)
- Her özellik/görev tamamlandığında **otomatik olarak** Brain vault'a checkpoint yaz
- `create_note(path="knowledge/ceptesef/checkpoint-YYYY-MM-DD.md")` ile kaydet
- Checkpoint içeriği: yapılan değişiklikler, değişen dosyalar, bug fix'ler, kullanıcı geri bildirimleri
- `top-of-mind` notunu güncelle (tamamlanan maddeler + yeni öncelikler)
- **Build yapıldıysa** versiyon numarasını checkpoint'e ekle

## Oturum Sonu
- Bu oturumda öğrenilen yeni bilgileri vault'a kaydet
- `top-of-mind` notunu güncelle (varsa yeni öncelikler)

---

# Cepte Şef

## Proje Hakkında
Kişisel tercihlere, alerjilere ve beğenilere göre haftalık yemek planları öneren akıllı mutfak asistanı.

## Teknik Bilgiler
- **Framework:** Flutter (Dart SDK ^3.8.1), Material 3
- **Backend:** Firebase (ceptesef-32545), Cloud Firestore, Firebase Auth, FCM
- **AI:** Google Gemini (API key ve model Firestore'dan alınır)
- **Platformlar:** iOS, Android
- **Paket Adı:** com.turneight.ceptesef
- **Font:** PlusJakartaSans (google_fonts paketi ile)
- **State Management:** Provider
- **i18n:** Flutter gen-l10n (ARB dosyaları, synthetic-package: false)
- **Animasyonlar:** Lottie (`assets/animations/lottie/` altında .json dosyaları)
- **Bildirimler:** FCM Push (data-only) + flutter_local_notifications + In-App Banner
- **Loglama:** RemoteLoggerService → Grafana/Loki (`{app="ceptesef"}`)
- **Bağımlılıklar:** firebase_core, firebase_auth, cloud_firestore, firebase_messaging, flutter_local_notifications, google_generative_ai, provider, google_fonts, lottie, flutter_localizations, intl, cupertino_icons, flutter_launcher_icons, http

## Proje Yapısı
```
lib/
├── main.dart                              # Giriş noktası (Firebase init + runApp)
├── app.dart                               # CepteSefApp (MaterialApp + Provider + l10n)
├── firebase_options.dart                  # Firebase konfigürasyonu (dokunma)
├── core/
│   ├── theme/
│   │   ├── app_colors.dart                # Renk sabitleri (AppColors)
│   │   └── app_theme.dart                 # Tema konfigürasyonu (AppTheme)
│   ├── constants/
│   │   └── firestore_paths.dart           # Firestore koleksiyon/doküman yolları
│   ├── models/
│   │   ├── app_config.dart                # system/general doküman modeli
│   │   ├── app_user.dart                  # Kullanıcı modeli (uid, email, displayName, createdAt)
│   │   └── inbox_notification.dart        # Bildirim modeli (id, type, title, body, read)
│   ├── services/
│   │   ├── auth_service.dart              # Firebase Auth servisi (email login/register/reset/signout)
│   │   ├── firestore_service.dart         # Firestore erişim servisi (config + user CRUD + FCM token)
│   │   ├── gemini_service.dart            # Gemini AI servisi
│   │   ├── notification_service.dart      # FCM Push + foreground listener + banner callback
│   │   ├── inbox_service.dart             # Bildirim inbox CRUD (users/{uid}/notifications)
│   │   ├── remote_logger_service.dart     # Grafana/Loki remote loglama (fire-and-forget)
│   │   └── slack_notification_service.dart # Slack webhook bildirimleri (fire-and-forget)
│   └── widgets/
│       └── in_app_notification_banner.dart # Üstten kayan bildirim overlay
├── l10n/
│   ├── app_en.arb                         # İngilizce çeviri (template)
│   ├── app_tr.arb                         # Türkçe çeviri
│   ├── app_localizations.dart             # (gen-l10n tarafından üretilir)
│   ├── app_localizations_en.dart          # (gen-l10n tarafından üretilir)
│   └── app_localizations_tr.dart          # (gen-l10n tarafından üretilir)
└── features/
    ├── auth/
    │   ├── auth_wrapper.dart              # Auth durumuna göre yönlendirme (login/home)
    │   ├── screens/
    │   │   ├── login_screen.dart          # Giriş yap ekranı
    │   │   ├── register_screen.dart       # Hesap oluştur ekranı
    │   │   └── forgot_password_screen.dart # Şifre sıfırlama ekranı
    │   └── widgets/
    │       ├── auth_text_field.dart        # Özel input alanı (icon + label + validation)
    │       ├── primary_gradient_button.dart # Gradient buton (loading destekli)
    │       └── social_login_button.dart    # Google/Apple sosyal giriş butonu
    ├── inbox/
    │   └── screens/
    │       └── inbox_screen.dart          # Bildirim gelen kutusu (timeline, swipe-to-delete)
    └── home/
        └── screens/
            └── home_screen.dart           # Ana ekran (badge + banner entegrasyonu)
```

## Kimlik Doğrulama (Auth)
- Firebase Authentication ile email/şifre girişi
- `AuthService` — login, register, forgot password, signout metodları
- `AuthWrapper` — `authStateChanges` stream'i ile otomatik yönlendirme
- Kayıt olunca Firestore `users/{uid}` dokümanı oluşturulur (AppUser modeli)
- Google/Apple login henüz aktif değil — butonlar "Yakında" snackbar gösterir
- Auth hataları lokalize edilmiş (ARB key'leri: errorWrongPassword, errorEmailInUse vb.)

## Tasarım Referansları
- Stitch tasarımları `assets/stitch/` altında bulunur
- `stitch_alerji_diyet_filtreleri/giri_yap_yeni/` — Giriş yap tasarımı
- `stitch_alerji_diyet_filtreleri/hesap_olu_tur_yeni/` — Hesap oluştur tasarımı
- `stitch_alerji_diyet_filtreleri/ifremi_unuttum/` — Şifre sıfırlama tasarımı
- Tasarım dili: Yeşil gradient butonlar, rounded input'lar (16px radius), ikon prefixli alanlar, hero bölümü + beyaz kart yapısı

## Çoklu Dil (i18n)
- Flutter gen-l10n kullanılır (`l10n.yaml` ile yapılandırılır)
- ARB dosyaları `lib/l10n/` altında, `synthetic-package: false`
- Şu an desteklenen diller: İngilizce (en), Türkçe (tr)
- Kullanım: `AppLocalizations.of(context).keyName`
- Import: `import '../l10n/app_localizations.dart';` (göreli yol)
- Yeni key eklerken önce `app_en.arb`'ye (template) ekle, sonra `app_tr.arb`'ye
- Yeni dil eklemek için `app_XX.arb` dosyası oluştur ve `flutter gen-l10n` çalıştır

## Gemini AI Entegrasyonu
- API key ve model adı Firestore `system/general` dokümanından alınır
- Alanlar: `geminiApiKey`, `modelName`
- `GeminiService` lazy initialization kullanır (ilk çağrıda Firestore'dan config çeker)
- Provider ile erişilir: `context.read<GeminiService>()`

## Remote Loglama (Grafana/Loki)
- `RemoteLoggerService` — statik sınıf, fire-and-forget, sunucu kapalıysa uygulama etkilenmez
- Endpoint: `https://logs.heymenu.org/loki/api/v1/push`
- Label: `{app="ceptesef"}` — Grafana'da `{app="ceptesef"}` ile filtrelenir
- Bağımlılık: `http` paketi
- Context: `setUserContext()` login sonrası, `clearContext()` logout'ta çağrılır
- Kısayollar: `info()`, `error()`, `warning()`, `userAction()`, `authEvent()`, `notificationEvent()`
- **ÖNEMLİ — Geliştirme Kuralı:** Yeni özellik/ekran/servis eklerken mutlaka log çağrıları ekle:
  - Ekran açılışlarında: `RemoteLoggerService.setScreen('ekran_adi')` + `info('screen_opened')`
  - Kullanıcı aksiyonlarında: `RemoteLoggerService.userAction('aksiyon_adi', screen: '...')`
  - Hata durumlarında: `RemoteLoggerService.error('hata_mesaji', error: e)`
  - Auth olaylarında: `RemoteLoggerService.authEvent('olay')`
- **Hassas veri loglama:** Şifre, token, kişisel bilgi ASLA loglanmaz
- **Yüksek frekanslı loglardan kaçın:** Scroll event, döngü içi log gönderme

## Bildirim Sistemi (Push Notifications)
- **FCM data-only mesajlar** kullanılır (Android foreground'da çalışması için)
- `NotificationService` — FCM izin, token yönetimi, foreground listener
- `InboxService` — `users/{uid}/notifications/` alt koleksiyonunda CRUD
- `InAppNotificationBanner` — üstten kayan overlay (4sn, swipe-to-dismiss)
- Foreground listener `main.dart`'tan erken başlatılır (auth'dan bağımsız)
- FCM token her home yüklemesinde refresh edilir
- Home ekranında badge ile okunmamış bildirim sayısı gösterilir
- Python test scripti: `admin/test_notification.py` (data-only + APNS alert)
- **ÖNEMLİ:** Android'de notification payload'lu mesajlar foreground'da onMessage'a DÜŞMEZ, her zaman data-only kullan

## Slack Bildirim Sistemi
- `SlackNotificationService` — Slack webhook ile fire-and-forget bildirim gönderir
- Webhook URL Firestore `system/general` dokümanındaki `slackInfoURL` alanından alınır (lazy, bir kez)
- Bağımlılık: `http` paketi
- **Mevcut bildirimler:**
  - `notifyNewUser()` — Yeni kullanıcı kayıt olduğunda
  - `notifyAccountDeleted()` — Kullanıcı hesabını sildiğinde
- **Yeni bildirim eklemek için:** `SlackNotificationService`'e statik metod ekle, ilgili yerden çağır

## Firestore Yapısı
- `system/general` — Uygulama konfigürasyonu (geminiApiKey, modelName)
- `users/{uid}` — Kullanıcı dokümanları (email, displayName, createdAt, fcmToken)
- `users/{uid}/notifications/{id}` — Bildirimler (type, title, body, createdAt, read)
- Yol sabitleri `FirestorePaths` sınıfında tanımlı

## Renk Skalası
Tüm renkler `lib/core/theme/app_colors.dart` içinde tanımlıdır. Yeni renk eklerken bu dosyayı kullan.
- Primary: `#48A14D` (Botanical Green)
- PrimaryDark: `#347A38` (Koyu yeşil)
- Secondary: `#F4B942` (Amber/Gold)
- Accent: `#E97451` (Coral)
- Charcoal: `#1A1C19` (Koyu metin)
- Surface: `#F9FBF9` (Arka plan)
- Border: `#E2E8E2` (Kenarlık)
- White: `#FFFFFF` (Beyaz)

## Tema Yapılandırması
`lib/core/theme/app_theme.dart` dosyasında `AppTheme.lightTheme` kullanılır.
- Font: GoogleFonts.plusJakartaSansTextTheme() ile yüklenir
- AppBar: Primary arka plan, beyaz metin, elevation 0
- FAB: Primary arka plan, beyaz ikon
- ElevatedButton: Primary arka plan, beyaz metin
- Scaffold: Surface arka plan rengi

## Launcher Icons
`pubspec.yaml`'da `flutter_launcher_icons` konfigürasyonu tanımlı.
- Kaynak: `assets/system/cepteSef_full.png`
- Adaptive ikon arka plan: `#FFFFFF`
- iOS'ta alpha kaldırılır

## Geliştirme Kuralları
- Renkleri hardcode etme, AppColors sınıfını kullan
- Tema değişiklikleri app_theme.dart üzerinden yapılmalı
- Firebase konfigürasyonu firebase_options.dart'ta, değiştirme
- Yeni sayfalar `lib/features/<feature>/screens/` altında oluşturulmalı
- Feature-specific widget'lar `lib/features/<feature>/widgets/` altında
- Servisler `lib/core/services/` altında
- Modeller `lib/core/models/` altında
- Sabitler `lib/core/constants/` altında
- Türkçe yorum ve dokümantasyon tercih edilir
- Tüm kullanıcıya görünen metinler ARB dosyalarında tanımlanmalı (hardcode metin yok)
- Servisler Provider ile sağlanır, `context.read<Service>()` ile erişilir

## Lottie Animasyonları
Lottie animasyonları `assets/animations/lottie/` altında bulunur.
- `loading.json` — Bekleme/yükleme ekranlarında kullanılacak loading animasyonu
- Kullanım: `Lottie.asset('assets/animations/lottie/loading.json')`
- Yeni animasyon eklerken aynı klasöre `.json` dosyası koy

## Admin / Test Ortamı
- `admin/` klasörü Firebase Admin SDK credential dosyası ve Python test scriptlerini içerir
- Firebase Admin JSON: `admin/ceptesef-32545-firebase-adminsdk-fbsvc-969a83d5b4.json`
- `admin/test_notification.py` — FCM test bildirimi gönderici (`python test_notification.py <email>`)
- Python test scriptleri bu klasör altında yazılır, Firestore verilerini test/seed etmek için kullanılır
- **DİKKAT:** Admin JSON dosyası gizli bilgi içerir, git'e eklenmemeli (.gitignore'a eklenmiş)

## Komutlar
- `flutter pub get` - Bağımlılıkları yükle
- `flutter gen-l10n` - Lokalizasyon dosyalarını üret
- `flutter analyze` - Statik analiz çalıştır
- `flutter run` - Uygulamayı çalıştır
- `flutter build apk` - Android APK oluştur
- `flutter build ios` - iOS build oluştur
- `dart run flutter_launcher_icons` - Launcher ikonlarını oluştur
