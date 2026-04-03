import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firestore_service.dart';
import 'inbox_service.dart';
import 'remote_logger_service.dart';

/// Top-level FCM background handler — main.dart'tan çağrılır
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background'da gelen mesajlar burada handle edilir
  // Firestore'a kaydetme işlemi app açılınca yapılacak
}

/// In-app banner göstermek için callback tipi
typedef InAppBannerCallback = void Function(String title, String body);

/// FCM Push Notification servisi
/// - İzin isteme + token alma
/// - Foreground listener
/// - Banner callback + inbox'a kayıt
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirestoreService _firestoreService;
  final InboxService _inboxService;
  bool _isForegroundListenerSetup = false;
  bool _isTokenRefreshListenerSetup = false;

  /// UI katmanından set edilir — banner göstermek için
  InAppBannerCallback? onShowBanner;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const _fcmChannelId = 'fcm_default';

  NotificationService({
    required FirestoreService firestoreService,
    required InboxService inboxService,
    FirebaseMessaging? messaging,
  })  : _firestoreService = firestoreService,
        _inboxService = inboxService,
        _messaging = messaging ?? FirebaseMessaging.instance;

  /// İzin iste + token kaydet
  Future<bool> requestPermissionAndSetup() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      RemoteLoggerService.notificationEvent('fcm_permission_granted');
      await refreshFcmToken();
      return true;
    }
    RemoteLoggerService.warning('fcm_permission_denied', screen: 'notification');
    return false;
  }

  /// FCM token'ı yenile ve Firestore'a kaydet
  Future<void> refreshFcmToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final token = await _messaging.getToken();
    if (token != null) {
      try {
        await _firestoreService.saveFcmToken(user.uid, token);
        RemoteLoggerService.notificationEvent('fcm_token_refreshed');
      } catch (_) {}
    }

    // Token değişikliklerini dinle (sadece bir kez)
    if (!_isTokenRefreshListenerSetup) {
      _isTokenRefreshListenerSetup = true;
      _messaging.onTokenRefresh.listen((newToken) async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          try {
            await _firestoreService.saveFcmToken(currentUser.uid, newToken);
          } catch (_) {}
        }
      });
    }
  }

  /// Foreground listener — main.dart'tan ERKEN çağır
  Future<void> setupForegroundListener() async {
    if (_isForegroundListenerSetup) return;
    _isForegroundListenerSetup = true;

    await _initLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Hem notification hem data payload'ı destekle
      final title = message.notification?.title ??
          message.data['title'] as String? ??
          '';
      final body = message.notification?.body ??
          message.data['body'] as String? ??
          '';

      if (title.isEmpty && body.isEmpty) return;

      RemoteLoggerService.notificationEvent('fcm_foreground_received',
          screen: 'foreground');

      // 1. Firestore'a kaydet
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _inboxService.savePushNotification(
          uid: user.uid,
          title: title,
          body: body,
        );
      }

      // 2. In-app banner göster (varsa) yoksa system notification
      if (onShowBanner != null) {
        onShowBanner!(title, body);
      } else {
        _showLocalNotification(title, body);
      }
    });
  }

  /// Local notification plugin'i başlat
  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(initSettings);
  }

  /// System notification göster (banner yoksa fallback)
  Future<void> _showLocalNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      _fcmChannelId,
      'Notifications',
      channelDescription: 'Push notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Android notification channel'ı oluştur (main.dart'tan çağır)
  Future<void> createNotificationChannel() async {
    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _fcmChannelId,
          'Notifications',
          description: 'Push notifications',
          importance: Importance.high,
        ),
      );
    }
  }
}
