import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'firestore_service.dart';
import 'gemini_service.dart';
import '../utils/image_crop_util.dart';
import 'remote_logger_service.dart';
import '../../features/meal_plan/screens/recipe_detail_screen.dart';

/// Dışarıdan paylaşılan görselleri alıp tarif olarak kaydeden servis.
/// iOS: App Group (UserDefaults) üzerinden ShareExtension ile iletişim kurar.
/// Android: Intent üzerinden gelen görselleri yakalar.
class ShareIntentService with WidgetsBindingObserver {
  final FirestoreService _firestoreService;
  final GeminiService _geminiService;

  static const _channel = MethodChannel('com.turneight.ceptesef/share');
  Timer? _pollTimer;
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _isProcessing = false;

  ShareIntentService({
    required FirestoreService firestoreService,
    required GeminiService geminiService,
  })  : _firestoreService = firestoreService,
        _geminiService = geminiService;

  /// Paylaşım dinleyicisini başlat
  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addObserver(this);

    // Uygulama açıldığında bekleyen paylaşım var mı kontrol et
    _checkPendingShares(navigatorKey);

    // Periyodik kontrol
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkPendingShares(navigatorKey);
    });
  }

  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama foreground'a geldiğinde hemen kontrol et
    if (state == AppLifecycleState.resumed && _navigatorKey != null) {
      _checkPendingShares(_navigatorKey!);
    }
  }

  Future<void> _checkPendingShares(GlobalKey<NavigatorState> navigatorKey) async {
    if (_isProcessing) return;

    try {
      final result = await _channel.invokeMethod<String>('getSharedItems');
      if (result == null || result.isEmpty) return;

      final items = jsonDecode(result) as List<dynamic>;
      if (items.isEmpty) return;

      // Paylaşılan verileri temizle (tekrar işlenmemesi için)
      await _channel.invokeMethod('clearSharedItems');

      // İlk görseli işle
      for (final item in items) {
        final map = item as Map<String, dynamic>;
        if (map['type'] == 'image' && map['path'] != null) {
          _handleSharedImage(map['path'] as String, navigatorKey);
          break;
        }
      }
    } on MissingPluginException {
      // Platform channel henüz kayıtlı değil (Android vb.) — sessizce geç
    } catch (e) {
      RemoteLoggerService.error('share_intent_check_failed',
          error: e, screen: 'share');
    }
  }

  Future<void> _handleSharedImage(
    String filePath,
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    _isProcessing = true;
    RemoteLoggerService.info('share_intent_received',
        screen: 'share', extra: {'path': filePath});

    final navState = navigatorKey.currentState;
    if (navState == null) {
      _isProcessing = false;
      return;
    }
    final context = navState.context;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isProcessing = false;
      _showSnackBar(
          context, _getL10n(context)?.shareLoginRequired ?? 'Lütfen giriş yapın.');
      return;
    }

    try {
      await _analyzeAndSave(context, filePath, user.uid);
    } finally {
      _isProcessing = false;
    }
  }

  /// Görseli analiz et ve kaydedilenlere ekle
  Future<void> _analyzeAndSave(
    BuildContext context,
    String filePath,
    String uid,
  ) async {
    final l10n = _getL10n(context);

    // Loading dialog göster
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  l10n?.shareReceived ?? 'Analiz ediliyor...',
                  style: const TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final file = File(filePath);
      final imageBytes = await file.readAsBytes();

      // MIME tipi belirle
      final ext = filePath.split('.').last.toLowerCase();
      String mimeType;
      switch (ext) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'image/jpeg';
      }

      final (extractedRecipe, imageRegion) =
          await _geminiService.recipeFromImage(imageBytes, mimeType);

      // Görsel varsa kırp ve base64'e çevir
      var recipe = extractedRecipe;
      if (imageRegion != null) {
        try {
          final croppedBase64 =
              await ImageCropUtil.cropAndEncode(imageBytes, imageRegion);
          if (croppedBase64 != null) {
            recipe = recipe.copyWith(imageBase64: croppedBase64);
          }
        } catch (e) {
          RemoteLoggerService.error('image_crop_failed',
              error: e, screen: 'share');
        }
      }

      // Kaydedilenlere ekle
      await _firestoreService.saveRecipeToArchive(uid, recipe);

      RemoteLoggerService.userAction('share_recipe_saved',
          screen: 'share',
          details: {
            'recipe': recipe.yemekAdi,
            'has_image': recipe.imageBase64 != null,
          });

      // Loading kapat
      if (context.mounted) Navigator.of(context).pop();

      // Direkt tarif detay ekranına git
      if (context.mounted) {
        RecipeDetailScreen.open(context, recipe);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.shareSuccess(recipe.yemekAdi) ??
                  '${recipe.yemekAdi} kaydedildi!',
            ),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      RemoteLoggerService.error('share_recipe_failed',
          error: e, screen: 'share');

      // Loading kapat
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        _showSnackBar(
            context, l10n?.shareError ?? 'Görsel analiz edilemedi.');
      }
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  AppLocalizations? _getL10n(BuildContext context) {
    try {
      return AppLocalizations.of(context);
    } catch (_) {
      return null;
    }
  }
}