import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/gemini_service.dart';
import 'core/services/groq_service.dart';
import 'core/services/inbox_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/recipe_cache_service.dart';
import 'core/services/share_intent_service.dart';
import 'core/services/market_price_service.dart';
import 'core/services/taste_profile_service.dart';
import 'features/auth/auth_wrapper.dart';
import 'main.dart';

/// Global navigator key — share intent ve diğer servisler için
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Uygulama kök widget'ı
/// Provider, lokalizasyon ve tema yapılandırmasını içerir
class CepteSefApp extends StatefulWidget {
  const CepteSefApp({super.key});

  @override
  State<CepteSefApp> createState() => _CepteSefAppState();
}

class _CepteSefAppState extends State<CepteSefApp> {
  late final GeminiService _geminiService;
  late final GroqService _groqService;
  late final ShareIntentService _shareIntentService;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService(firestoreService: globalFirestoreService);
    _groqService = GroqService(firestoreService: globalFirestoreService);
    _shareIntentService = ShareIntentService(
      firestoreService: globalFirestoreService,
      geminiService: _geminiService,
    );
    // Share intent dinleyicisini başlat
    _shareIntentService.init(navigatorKey);
  }

  @override
  void dispose() {
    _shareIntentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final recipeCacheService = RecipeCacheService();
    final tasteProfileService = TasteProfileService();
    final marketPriceService = MarketPriceService(
      firestoreService: globalFirestoreService,
    );

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: globalFirestoreService),
        Provider<GeminiService>.value(value: _geminiService),
        Provider<GroqService>.value(value: _groqService),
        Provider<InboxService>.value(value: globalInboxService),
        Provider<NotificationService>.value(value: globalNotificationService),
        Provider<RecipeCacheService>.value(value: recipeCacheService),
        Provider<TasteProfileService>.value(value: tasteProfileService),
        Provider<MarketPriceService>.value(value: marketPriceService),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Cepte Şef',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('tr'),
        home: const AuthWrapper(),
      ),
    );
  }
}
