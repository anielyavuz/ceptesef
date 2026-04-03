import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/inbox_service.dart';
import 'core/models/app_config.dart';
import 'core/services/remote_logger_service.dart';

/// FCM background handler (top-level function olmalı)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Global servis instance'ları (main'den erken başlatılması gereken)
late final NotificationService globalNotificationService;
late final InboxService globalInboxService;
late final FirestoreService globalFirestoreService;

/// Global app konfigürasyonu (system/general'den bir kere çekilir)
AppConfig globalAppConfig = const AppConfig(geminiApiKey: '', modelName: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Servisleri oluştur (Provider'a da verilecek)
  globalFirestoreService = FirestoreService();
  globalInboxService = InboxService();
  globalNotificationService = NotificationService(
    firestoreService: globalFirestoreService,
    inboxService: globalInboxService,
  );

  // Notification channel'ı Android'de erken oluştur
  await globalNotificationService.createNotificationChannel();

  // Foreground FCM listener'ı ERKEN başlat (auth'dan bağımsız)
  await globalNotificationService.setupForegroundListener();

  // App config'i çek (google/apple butonları vb.)
  try {
    globalAppConfig = await globalFirestoreService.getAppConfig();
  } catch (_) {
    // Config çekilemezse varsayılan devam eder
  }

  RemoteLoggerService.info('app_started', screen: 'main');

  runApp(const CepteSefApp());
}
