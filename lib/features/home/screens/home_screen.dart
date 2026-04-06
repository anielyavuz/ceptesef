import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/in_app_notification_banner.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../../core/utils/image_crop_util.dart';
import '../../../core/services/taste_profile_service.dart';
import '../../inbox/screens/inbox_screen.dart';
import '../../meal_plan/screens/meal_plan_generation_screen.dart';
import '../../meal_plan/screens/manual_meal_plan_screen.dart';
import 'regenerate_loading_screen.dart';
import '../../meal_plan/screens/recipe_detail_screen.dart';
import '../../meal_plan/widgets/recipe_suggestion_sheet.dart';
import '../../meal_plan/widgets/add_meal_source_sheet.dart';
import '../../meal_plan/widgets/day_selection_sheet.dart';

/// Ana ekran — Haftalık plan + Tek seferlik (günlük) mod.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static final GlobalKey<HomeScreenState> globalKey =
      GlobalKey<HomeScreenState>();

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  MealPlan? _mealPlan;
  bool _isLoading = true;
  String _selectedDateStr = '';

  // Mod: 0 = haftalık, 1 = günlük
  int _viewMode = 0;
  int get currentViewMode => _viewMode;
  MealDay? _dailyPlan;
  bool _isDailyLoading = false;
  String _todayStr = '';

  // Haftalık plan yaşam döngüsü
  bool _isPlanExpired = false;
  bool _isRegeneratingRemaining = false;

  // Sonraki hafta desteği
  MealPlan? _nextWeekPlan;

  // Day selector scroll controller
  final _daySelectorController = ScrollController();

  // Rating takibi — recipeId → rating (1=beğenmedi, 2=iyi, 3=bayıldı)
  final _ratedRecipes = <String, int>{};

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('home');
    RemoteLoggerService.info('home_screen_opened', screen: 'home');
    final now = DateTime.now();
    _todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _selectedDateStr = _todayStr;
    _setupNotifications();
    _loadMealPlan();
    _loadNextWeekPlan();
    _loadViewMode();
    _loadRatedRecipes();
    _rebuildTasteProfileIfNeeded();
  }

  Future<void> _loadRatedRecipes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final rated = await context
          .read<TasteProfileService>()
          .getRatedRecipes(user.uid);
      if (mounted && rated.isNotEmpty) {
        setState(() => _ratedRecipes.addAll(rated));
      }
    } catch (_) {}
  }

  // ─── Sonraki Hafta Yardımcıları ────────────────────────

  static String _dateToStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _getNextMonday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysFromMonday = (today.weekday - DateTime.monday) % 7;
    final thisMonday = today.subtract(Duration(days: daysFromMonday));
    return thisMonday.add(const Duration(days: 7));
  }

  Future<void> _loadNextWeekPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final nextMonday = _getNextMonday();
      final weekStartStr = _dateToStr(nextMonday);
      final plan = await context
          .read<FirestoreService>()
          .getMealPlanByWeekStart(user.uid, weekStartStr);
      if (mounted) setState(() => _nextWeekPlan = plan);
    } catch (_) {}
  }

  /// Verilen tarih için MealDay'i döndürür (bu hafta veya sonraki hafta planından)
  MealDay? _getMealDayForDate(String dateStr) {
    final inCurrent =
        _mealPlan?.gunler.where((d) => d.gun == dateStr).firstOrNull;
    if (inCurrent != null) return inCurrent;
    return _nextWeekPlan?.gunler.where((d) => d.gun == dateStr).firstOrNull;
  }

  /// Verilen tarih sonraki haftaya ait mi?
  bool _isNextWeekDate(String dateStr) {
    final nextMonday = _getNextMonday();
    final nextSunday = nextMonday.add(const Duration(days: 6));
    final parts = dateStr.split('-');
    if (parts.length != 3) return false;
    final d = DateTime(
        int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    return !d.isBefore(nextMonday) && !d.isAfter(nextSunday);
  }

  /// Lezzet profilini arka planda yeniden hesapla (fire-and-forget)
  void _rebuildTasteProfileIfNeeded() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Arka planda çalıştır, UI'ı bloklamaz
    context.read<TasteProfileService>().rebuildTasteProfile(user.uid);
  }

  Future<void> _loadViewMode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefs =
          await context.read<FirestoreService>().getUserPreferences(user.uid);
      if (prefs != null && mounted) {
        final saved = prefs.viewMode;
        if (saved != _viewMode) {
          setState(() => _viewMode = saved);
          if (saved == 1) _loadDailyPlan();
        }
      }
    } catch (_) {}
  }

  Future<void> _saveViewMode(int mode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final firestore = context.read<FirestoreService>();
      final prefs = await firestore.getUserPreferences(user.uid);
      if (prefs != null) {
        await firestore.saveUserPreferences(
            user.uid, prefs.copyWith(viewMode: mode));
      }
    } catch (_) {}
  }

  Future<void> _setupNotifications() async {
    final notificationService = context.read<NotificationService>();
    await notificationService.requestPermissionAndSetup();
    await notificationService.refreshFcmToken();

    notificationService.onShowBanner = (title, body) {
      if (!mounted) return;
      InAppNotificationBanner.show(
        context,
        title: title,
        body: body,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InboxScreen()),
        ),
      );
    };
  }

  // ─── Görsel ile Tarif Tarama ─────────────────────────────

  void _showScanRecipeSheet() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.homeScanRecipe,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.homeScanRecipeDesc,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ScanOptionButton(
                    icon: Icons.camera_alt_rounded,
                    label: l10n.homeScanCamera,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndScanImage(ImageSource.camera);
                    },
                  ),
                  _ScanOptionButton(
                    icon: Icons.photo_library_rounded,
                    label: l10n.homeScanGallery,
                    color: AppColors.secondary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndScanImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndScanImage(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    RemoteLoggerService.userAction(
      'scan_recipe_started',
      screen: 'home',
      details: {'source': source == ImageSource.camera ? 'camera' : 'gallery'},
    );

    // Galeri: çoklu görsel seçimi
    if (source == ImageSource.gallery) {
      await _pickAndScanMultiImage();
      return;
    }

    // Kamera: tekli görsel akışı (mevcut davranış)
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      if (!mounted) return;

      // Lottie loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.homeScanAnalyzing,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final imageBytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';

      if (!mounted) return;
      final gemini = context.read<GeminiService>();
      final (extractedRecipe, imageRegion) =
          await gemini.recipeFromImage(imageBytes, mimeType);

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
              error: e, screen: 'home');
        }
      }

      // Loading kapat
      if (mounted) Navigator.pop(context);

      // Kaydedilenler arşivine ekle
      if (!mounted) return;
      final firestore = context.read<FirestoreService>();
      await firestore.saveRecipeToArchive(user.uid, recipe);

      RemoteLoggerService.userAction(
        'scan_recipe_saved',
        screen: 'home',
        details: {
          'recipe': recipe.yemekAdi,
          'has_image': recipe.imageBase64 != null,
        },
      );

      if (!mounted) return;

      // Başarı popup'ı göster
      await _showScanSuccessDialog(recipe);
    } catch (e) {
      // Loading varsa kapat
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      RemoteLoggerService.error('scan_recipe_failed',
          error: e, screen: 'home');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeScanError)),
        );
      }
    }
  }

  /// Galeriden çoklu görsel seçip sırayla tarif tarayan yardımcı metod.
  Future<void> _pickAndScanMultiImage() async {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        limit: 10,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty) return;

      // Tek görsel seçildiyse mevcut tekli akışı kullan
      if (pickedFiles.length == 1) {
        if (!mounted) return;
        _pickAndScanSingleFile(pickedFiles.first);
        return;
      }

      if (!mounted) return;

      final total = pickedFiles.length;
      int successCount = 0;
      int failCount = 0;

      // İlerleme durumunu takip eden ValueNotifier
      final progressNotifier = ValueNotifier<String>(
        l10n.homeScanProgress(1, total),
      );

      // İlerleme dialog'unu göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: progressNotifier,
                    builder: (_, value, __) => Text(
                      value,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final gemini = context.read<GeminiService>();
      final firestore = context.read<FirestoreService>();

      // Görselleri sırayla işle (API rate limit'e dikkat)
      for (int i = 0; i < pickedFiles.length; i++) {
        if (!mounted) break;
        progressNotifier.value = l10n.homeScanProgress(i + 1, total);

        try {
          final file = pickedFiles[i];
          final imageBytes = await file.readAsBytes();
          final mimeType = file.mimeType ?? 'image/jpeg';

          final (extractedRecipe, imageRegion) =
              await gemini.recipeFromImage(imageBytes, mimeType);

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
                  error: e, screen: 'home');
            }
          }

          await firestore.saveRecipeToArchive(user.uid, recipe);

          RemoteLoggerService.userAction(
            'scan_recipe_saved',
            screen: 'home',
            details: {
              'recipe': recipe.yemekAdi,
              'has_image': recipe.imageBase64 != null,
              'batch_index': i + 1,
              'batch_total': total,
            },
          );

          successCount++;
        } catch (e) {
          failCount++;
          RemoteLoggerService.error('scan_recipe_failed',
              error: e,
              screen: 'home');
        }
      }

      // Loading kapat
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      progressNotifier.dispose();

      if (!mounted) return;

      // Sonuç mesajını göster
      final String resultMessage;
      if (failCount == 0) {
        resultMessage = l10n.homeScanMultiSuccess(successCount);
      } else {
        resultMessage =
            l10n.homeScanMultiPartial(successCount, total, failCount);
      }

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultMessage),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
          backgroundColor:
              failCount == 0 ? AppColors.primary : AppColors.accent,
        ),
      );

      RemoteLoggerService.userAction(
        'scan_recipe_multi_completed',
        screen: 'home',
        details: {
          'total': total,
          'success': successCount,
          'failed': failCount,
        },
      );
    } catch (e) {
      // Loading varsa kapat
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      RemoteLoggerService.error('scan_recipe_multi_failed',
          error: e, screen: 'home');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeScanError)),
        );
      }
    }
  }

  /// Tekli dosya tarama (galeriden tek görsel seçildiğinde kullanılır).
  Future<void> _pickAndScanSingleFile(XFile picked) async {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (!mounted) return;

      // Lottie loading göster
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              margin: const EdgeInsets.symmetric(horizontal: 48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.homeScanAnalyzing,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final imageBytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';

      if (!mounted) return;
      final gemini = context.read<GeminiService>();
      final (extractedRecipe, imageRegion) =
          await gemini.recipeFromImage(imageBytes, mimeType);

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
              error: e, screen: 'home');
        }
      }

      // Loading kapat
      if (mounted) Navigator.pop(context);

      // Kaydedilenler arşivine ekle
      if (!mounted) return;
      final firestore = context.read<FirestoreService>();
      await firestore.saveRecipeToArchive(user.uid, recipe);

      RemoteLoggerService.userAction(
        'scan_recipe_saved',
        screen: 'home',
        details: {
          'recipe': recipe.yemekAdi,
          'has_image': recipe.imageBase64 != null,
        },
      );

      if (!mounted) return;

      // Başarı popup'ı göster
      await _showScanSuccessDialog(recipe);
    } catch (e) {
      // Loading varsa kapat
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      RemoteLoggerService.error('scan_recipe_failed',
          error: e, screen: 'home');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeScanError)),
        );
      }
    }
  }

  /// Tarif tarama başarılı — kaydedildi popup + plana ekle önerisi
  Future<void> _showScanSuccessDialog(Recipe recipe) async {
    final l10n = AppLocalizations.of(context);

    final action = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başarı ikonu
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeScanSuccessTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeScanSuccessDesc(recipe.yemekAdi),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.charcoal.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Plana Ekle butonu (primary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'add_to_plan'),
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(l10n.homeScanAddToPlan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tarifi Gör butonu (secondary)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'view'),
                  icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                  label: Text(l10n.homeScanViewRecipe),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.charcoal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppColors.border),
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;

    RemoteLoggerService.userAction(
      'scan_success_dialog_action',
      screen: 'home',
      details: {
        'recipe': recipe.yemekAdi,
        'action': action ?? 'dismissed',
      },
    );

    if (action == 'add_to_plan') {
      _showAddScannedRecipeToPlan(recipe);
    } else if (action == 'view') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    }
  }

  /// Taranan tarifi mevcut plana ekleme — gün ve öğün seçimi
  Future<void> _showAddScannedRecipeToPlan(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context);
    final firestore = context.read<FirestoreService>();

    final plan = await firestore.getCurrentMealPlan(user.uid);
    if (!mounted) return;

    if (plan == null) {
      RemoteLoggerService.info('scan_add_to_plan_no_plan',
          screen: 'home');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.noPlanAvailable),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final scaffoldMsg = ScaffoldMessenger.of(context);
    final tasteService = context.read<TasteProfileService>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ScanAddToPlanSheet(
        plan: plan,
        recipeName: recipe.yemekAdi,
        onSelect: (dayIndex, slotKey) async {
          final existingList = plan.gunler[dayIndex].ogunler[slotKey];

          if (existingList != null && existingList.isNotEmpty) {
            final action = await showDialog<String>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                title: const Text('Bu öğünde tarif var'),
                content: Text(
                    '"${existingList.map((r) => r.yemekAdi).join(', ')}" zaten mevcut. Ne yapmak istersiniz?'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx),
                    child: Text(l10n.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, 'replace'),
                    child: const Text('Değiştir'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dCtx, 'add'),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary),
                    child: const Text('Yeni slot ekle'),
                  ),
                ],
              ),
            );
            if (action == null) return;

            Navigator.pop(ctx);
            try {
              if (action == 'add') {
                // Mevcut listeye ekle
                await firestore.updateMealSlot(
                    user.uid, plan, dayIndex, slotKey, [...existingList, recipe]);
              } else {
                await firestore.updateMealSlot(
                    user.uid, plan, dayIndex, slotKey, [recipe]);
              }
              tasteService.logRecipeAction(user.uid, recipe, 'added_to_plan');
              RemoteLoggerService.userAction('scan_recipe_added_to_plan',
                  screen: 'home',
                  details: {
                    'recipe': recipe.yemekAdi,
                    'day': dayIndex,
                    'slot': slotKey,
                  });
              scaffoldMsg.clearSnackBars();
              scaffoldMsg.showSnackBar(SnackBar(
                content: Text(
                    '${l10n.addedToPlan}: ${plan.gunler[dayIndex].gunAdi}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
              // Planı yenile
              refreshMealPlan();
            } catch (e) {
              RemoteLoggerService.error('scan_add_to_plan_failed',
                  error: e, screen: 'home');
            }
          } else {
            Navigator.pop(ctx);
            try {
              await firestore.updateMealSlot(
                  user.uid, plan, dayIndex, slotKey, [recipe]);
              tasteService.logRecipeAction(user.uid, recipe, 'added_to_plan');
              RemoteLoggerService.userAction('scan_recipe_added_to_plan',
                  screen: 'home',
                  details: {
                    'recipe': recipe.yemekAdi,
                    'day': dayIndex,
                    'slot': slotKey,
                  });
              scaffoldMsg.clearSnackBars();
              scaffoldMsg.showSnackBar(SnackBar(
                content: Text(
                    '${l10n.addedToPlan}: ${plan.gunler[dayIndex].gunAdi}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
              // Planı yenile
              refreshMealPlan();
            } catch (e) {
              RemoteLoggerService.error('scan_add_to_plan_failed',
                  error: e, screen: 'home');
            }
          }
        },
      ),
    );
  }

  /// Plan verilerini Firestore'dan yeniden yükler (dışarıdan erişilebilir)
  Future<void> refreshMealPlan() async {
    await _loadMealPlan();
    await _loadNextWeekPlan();
  }

  Future<void> _loadMealPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final plan =
          await context.read<FirestoreService>().getCurrentMealPlan(user.uid);

      if (mounted) {
        setState(() {
          _mealPlan = plan;
          _isPlanExpired = plan != null && plan.isExpired;
          _isLoading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('meal_plan_load_failed',
          error: e, screen: 'home');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDailyPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDailyLoading = true);
    try {
      final day = await context
          .read<FirestoreService>()
          .getDailyPlan(user.uid, _todayStr);
      if (mounted) {
        setState(() {
          _dailyPlan = day;
          _isDailyLoading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('daily_plan_load_failed',
          error: e, screen: 'home');
      if (mounted) setState(() => _isDailyLoading = false);
    }
  }

  @override
  void dispose() {
    _daySelectorController.dispose();
    context.read<NotificationService>().onShowBanner = null;
    InAppNotificationBanner.dismiss();
    super.dispose();
  }

  // ─── Slot yardımcıları ───────────────────────────────────

  String _shortDayName(String gunAdi) {
    const kisaltmalar = {
      'Pazartesi': 'PZT',
      'Salı': 'SAL',
      'Çarşamba': 'ÇAR',
      'Perşembe': 'PER',
      'Cuma': 'CUM',
      'Cumartesi': 'CMT',
      'Pazar': 'PAZ',
    };
    return kisaltmalar[gunAdi] ?? gunAdi.toUpperCase();
  }

  /// Slot key'den base slot'u çıkarır (ek suffix'i kaldırır)
  /// Örn: 'kahvalti_ek_1' → 'kahvalti', 'ara_ogun_1_ek_2' → 'ara_ogun_1'
  String _baseSlotKey(String slot) {
    final ekMatch = RegExp(r'_ek_\d+$').firstMatch(slot);
    if (ekMatch != null) return slot.substring(0, ekMatch.start);
    return slot;
  }

  /// Slot key bir ek slot mu?
  bool _isExtraSlot(String slot) => RegExp(r'_ek_\d+$').hasMatch(slot);

  int _slotOrder(String slot) {
    final base = _baseSlotKey(slot).replaceAll(RegExp(r'_\d+$'), '');
    const order = {
      'kahvalti': 0,
      'ara_ogun_1': 1,
      'ogle': 2,
      'ara_ogun_2': 3,
      'ara_ogun': 4,
      'aksam': 5,
      'atistirmalik': 6,
      'ana_ogun_1': 1,
      'ana_ogun_2': 3,
    };
    return order[slot] ?? order[base] ?? 99;
  }

  String _slotLabel(String slot, AppLocalizations l10n) {
    final base = _baseSlotKey(slot).replaceAll(RegExp(r'_\d+$'), '');
    switch (base) {
      case 'kahvalti':
        return l10n.slotKahvalti;
      case 'ogle':
        return l10n.slotOgle;
      case 'aksam':
        return l10n.slotAksam;
      case 'ara_ogun_1':
      case 'ara_ogun_2':
      case 'ara_ogun':
        return l10n.slotAraOgun;
      case 'ana_ogun_1':
      case 'ana_ogun_2':
      case 'ana_ogun':
        return l10n.slotAnaOgun;
      case 'atistirmalik':
        return l10n.slotAtistirmalik;
      default:
        return slot;
    }
  }

  String _slotEmoji(String slot) {
    final base = _baseSlotKey(slot).replaceAll(RegExp(r'_\d+$'), '');
    switch (base) {
      case 'kahvalti':
        return '🌅';
      case 'ogle':
        return '☀️';
      case 'aksam':
        return '🌙';
      case 'ara_ogun_1':
      case 'ara_ogun_2':
      case 'ara_ogun':
      case 'atistirmalik':
        return '🍎';
      default:
        return '🍽️';
    }
  }

  String _difficultyLabel(String zorluk, AppLocalizations l10n) {
    switch (zorluk) {
      case 'kolay':
        return l10n.homeDifficultyKolay;
      case 'zor':
        return l10n.homeDifficultyZor;
      default:
        return l10n.homeDifficultyOrta;
    }
  }

  String _cuisineLabel(String id) {
    const labels = {
      'turk': 'Türk Mutfağı',
      'akdeniz': 'Akdeniz',
      'ev_yemekleri': 'Ev Yemekleri',
      'uzak_dogu': 'Uzak Doğu',
      'fit_saglikli': 'Fit & Sağlıklı',
      'dunya': 'Dünya Mutfağı',
      'deniz_urunleri': 'Deniz Ürünleri',
      'sokak_lezzetleri': 'Sokak Lezzetleri',
      'izgara_mangal': 'Izgara & Mangal',
      'italyan': 'İtalyan',
      'meksika': 'Meksika',
      'fast_food': 'Fast Food',
      'vegan': 'Vegan Mutfak',
      'tatlilar': 'Tatlılar',
      'corbalar': 'Çorbalar',
      'salatalar': 'Salatalar',
      'hamur_isleri': 'Hamur İşleri',
      'fransiz': 'Fransız',
      'ortadogu': 'Ortadoğu',
      'tek_tencere': 'Tek Tencere',
      'atistirmaliklar': 'Atıştırmalıklar',
      'bebek_cocuk': 'Bebek & Çocuk',
      'glutensiz': 'Glutensiz',
      'hizli_kahvalti': 'Hızlı Kahvaltı',
      'guney_amerika': 'Güney Amerika',
    };
    return labels[id] ??
        id
            .replaceAll('_', ' ')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
            .join(' ');
  }

  Color _difficultyColor(String zorluk) {
    switch (zorluk) {
      case 'kolay':
        return const Color(0xFF2E7D32);
      case 'zor':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFE65100);
    }
  }

  /// Günlük plan slotları — haftalık plandan bağımsız, tüm öğünler
  List<String> _defaultSlots() {
    return [
      'kahvalti',
      'ara_ogun_1',
      'ogle',
      'ara_ogun_2',
      'aksam',
      'atistirmalik',
    ];
  }

  // ─── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          // Arka plan görseli — hafif transparan
          Positioned.fill(
            child: Opacity(
              opacity: 0.06,
              child: Image.asset(
                'assets/system/Meal_planner_app_202603281444.jpeg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Ana içerik
          SafeArea(
            child: _isLoading
                ? Center(
                    child: Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      width: 150,
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      // Header + bildirim
                      SliverToBoxAdapter(child: _buildHeader(l10n)),
                      // İçerik
                      ..._buildWeeklyContent(l10n),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeWeeklyPlan,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.homeWeeklyPlanSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showScanRecipeSheet,
            icon: const Icon(Icons.document_scanner_rounded),
            style: IconButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
            tooltip: l10n.homeScanRecipe,
          ),
        ],
      ),
    );
  }

  // ─── Mod Seçici (Segmented Control) ──────────────────────

  Widget _buildModeToggle(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 6) / 2; // 6 = padding
          return Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.charcoal.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                // Sliding pill
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _viewMode == 0 ? 0 : tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(19),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Tab labels
                Row(
                  children: [
                    _buildTab(
                      label: l10n.homeWeeklyMode,
                      isSelected: _viewMode == 0,
                      width: tabWidth,
                      onTap: () {
                        if (_viewMode != 0) {
                          RemoteLoggerService.userAction('switch_weekly',
                              screen: 'home');
                          setState(() => _viewMode = 0);
                          _saveViewMode(0);
                        }
                      },
                    ),
                    _buildTab(
                      label: l10n.homeDailyMode,
                      isSelected: _viewMode == 1,
                      width: tabWidth,
                      onTap: () {
                        if (_viewMode != 1) {
                          RemoteLoggerService.userAction('switch_daily',
                              screen: 'home');
                          setState(() => _viewMode = 1);
                          _saveViewMode(1);
                          if (_dailyPlan == null && !_isDailyLoading) {
                            _loadDailyPlan();
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab({
    required String label,
    required bool isSelected,
    required double width,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? AppColors.charcoal
                  : AppColors.charcoal.withValues(alpha: 0.38),
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  // ─── Haftalık mod içeriği ────────────────────────────────

  List<Widget> _buildWeeklyContent(AppLocalizations l10n) {
    if (_mealPlan == null) {
      return [SliverFillRemaining(child: _buildEmptyState(l10n))];
    }

    final plan = _mealPlan!;

    // Plan süresi dolmuşsa — yeni hafta oluşturma state'i
    if (_isPlanExpired) {
      return [SliverToBoxAdapter(child: _buildExpiredState(l10n))];
    }

    final isNextWeek = _isNextWeekDate(_selectedDateStr);
    final mealDay = _getMealDayForDate(_selectedDateStr);

    if (mealDay == null || mealDay.ogunler.isEmpty) {
      // Bu gün için plan yok
      return [
        if (plan.daysRemaining <= 2 && plan.daysRemaining > 0 && !isNextWeek)
          SliverToBoxAdapter(child: _buildCountdownBanner(plan, l10n)),
        SliverToBoxAdapter(child: _buildDaySelector()),
        SliverFillRemaining(child: _buildEmptyDayState(l10n, isNextWeek)),
      ];
    }

    return [
      // Countdown banner (≤2 gün kaldıysa, bu haftadaysa)
      if (plan.daysRemaining <= 2 && plan.daysRemaining > 0 && !isNextWeek)
        SliverToBoxAdapter(child: _buildCountdownBanner(plan, l10n)),
      SliverToBoxAdapter(child: _buildDaySelector()),
      // "Kalan Günleri Yenile" butonu (yalnızca bu haftada)
      if (!isNextWeek &&
          plan.pastDayIndices.isNotEmpty &&
          plan.remainingDayIndices.length >= 2)
        SliverToBoxAdapter(child: _buildRegenerateRemainingButton(l10n)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Container(
            key: ValueKey('weekly_${mealDay.gun}_${mealDay.ogunler.length}'),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: [
                  ...() {
                    final slots = mealDay.ogunler.entries.toList()
                      ..sort((a, b) =>
                          _slotOrder(a.key).compareTo(_slotOrder(b.key)));
                    return List.generate(slots.length, (index) {
                      final entry = slots[index];
                      return _buildMealBlock(
                        context,
                        entry.key,
                        entry.value,
                        l10n,
                        isLast: index == slots.length - 1,
                        isDaily: false,
                        readOnly: false,
                      );
                    });
                  }(),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _navigateToNextWeekPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = context.read<FirestoreService>();
    final prefs = await firestore.getUserPreferences(user.uid) ?? const UserPreferences();
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Expired plan varsa yeni plan için null geç
    final activePlan = (_mealPlan != null && !_isPlanExpired) ? _mealPlan : null;

    // startDate = today → bu haftanın kalan günleri + sonraki hafta görünür
    final selection = await DaySelectionSheet.show(
      context,
      existingPlan: activePlan,
      startDate: today,
      preferences: prefs,
    );
    if (selection == null || !mounted) return;

    final effectivePrefs = selection.updatedPreferences ?? prefs;

    // Tercihler değiştiyse Firestore'a kaydet
    if (selection.updatedPreferences != null) {
      firestore.saveUserPreferences(user.uid, effectivePrefs);
    }

    RemoteLoggerService.userAction('next_week_plan_tapped',
        screen: 'home');

    if (selection.isManual) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualMealPlanScreen(
            uid: user.uid,
            preferences: effectivePrefs,
            selectedDayIndices: selection.selectedIndices,
            startDate: selection.startDate,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealPlanGenerationScreen(
            uid: user.uid,
            preferences: effectivePrefs,
            startDate: selection.startDate,
            returnToHome: true,
            selectedDayIndices: selection.selectedIndices,
            existingPlan: activePlan,
          ),
        ),
      );
    }
    if (mounted) {
      await _loadMealPlan();
      await _loadNextWeekPlan();
    }
  }

  /// Plan süresi dolmuş — yeni hafta oluşturma ekranı
  Widget _buildExpiredState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.calendar_today_rounded,
                  size: 36, color: AppColors.secondary),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.homePlanExpired,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.homePlanExpiredDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FilledButton.icon(
                  onPressed: _navigateToNewPlan,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(l10n.homeNewWeekPlan,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Countdown banner — haftanın sonuna yaklaşıldığında
  Widget _buildCountdownBanner(MealPlan plan, AppLocalizations l10n) {
    final remaining = plan.daysRemaining;
    final text = remaining == 1
        ? l10n.homePlanCountdownTomorrow
        : l10n.homePlanCountdown(remaining);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded,
              size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          GestureDetector(
            onTap: _navigateToNextWeekPlan,
            child: Text(
              l10n.homeNewWeekPlan,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// "Kalan Günleri Yenile" butonu
  Widget _buildRegenerateRemainingButton(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: OutlinedButton.icon(
        onPressed:
            _isRegeneratingRemaining ? null : _regenerateRemainingDays,
        icon: _isRegeneratingRemaining
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : const Icon(Icons.refresh_rounded, size: 16),
        label: Text(_isRegeneratingRemaining
            ? l10n.homeRegeneratingRemaining
            : l10n.homeRegenerateRemaining),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  /// Yeni hafta planı oluşturmak için generation ekranına git
  Future<void> _navigateToNewPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = context.read<FirestoreService>();
    final prefs = await firestore.getUserPreferences(user.uid) ?? const UserPreferences();
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Expired plan varsa yeni plan için null geç
    final activePlan = (_mealPlan != null && !_isPlanExpired) ? _mealPlan : null;

    // Gün seçimi sheet'i göster
    final selection = await DaySelectionSheet.show(
      context,
      existingPlan: activePlan,
      startDate: today,
      preferences: prefs,
    );
    if (selection == null || !mounted) return;

    final effectivePrefs = selection.updatedPreferences ?? prefs;

    // Tercihler değiştiyse Firestore'a kaydet
    if (selection.updatedPreferences != null) {
      firestore.saveUserPreferences(user.uid, effectivePrefs);
    }

    RemoteLoggerService.userAction('new_week_plan_tapped',
        screen: 'home');

    if (selection.isManual) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualMealPlanScreen(
            uid: user.uid,
            preferences: effectivePrefs,
            selectedDayIndices: selection.selectedIndices,
            startDate: selection.startDate,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealPlanGenerationScreen(
            uid: user.uid,
            preferences: effectivePrefs,
            startDate: selection.startDate,
            returnToHome: true,
            selectedDayIndices: selection.selectedIndices,
            existingPlan: activePlan,
          ),
        ),
      );
    }
    // Geri döndüğünde planı yenile
    if (mounted) await _loadMealPlan();
  }

  /// Kalan günleri yeniden oluştur — gün seçimi ile
  Future<void> _regenerateRemainingDays() async {
    // Aynı akışı kullan — gün seçimi + üretim + önizleme
    await _navigateToNewPlan();
  }

  /// Haftalık plan düzenleme bottom sheet
  void _showWeeklyEditSheet(AppLocalizations l10n) {
    final plan = _mealPlan;
    if (plan == null) return;

    final hasPastDays = plan.pastDayIndices.isNotEmpty;
    final hasRemainingDays = plan.remainingDayIndices.length >= 2;
    final dayIndex =
        plan.gunler.indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;
    final selectedDay = plan.gunler[dayIndex];
    final isSelectedDayPast = plan.pastDayIndices.contains(dayIndex);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l10n.homeWeeklyEditTitle,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.charcoal),
            ),
            const SizedBox(height: 16),
            // Bu Günü Yenile (seçili gün gelecekteyse)
            if (!isSelectedDayPast)
              _MealSourceOption(
                icon: Icons.refresh_rounded,
                iconColor: AppColors.primary,
                title: l10n.homeWeeklyEditRegenDay,
                subtitle: '${l10n.homeWeeklyEditRegenDayDesc} (${selectedDay.gunAdi})',
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndRegenerateDay();
                },
              ),
            if (!isSelectedDayPast) const SizedBox(height: 10),
            // Kalan Günleri Yenile (geçmiş gün + kalan gün varsa)
            if (hasPastDays && hasRemainingDays)
              _MealSourceOption(
                icon: Icons.update_rounded,
                iconColor: AppColors.secondary,
                title: l10n.homeWeeklyEditRegenRemaining,
                subtitle: l10n.homeWeeklyEditRegenRemainingDesc,
                onTap: () {
                  Navigator.pop(ctx);
                  _regenerateRemainingDays();
                },
              ),
            if (hasPastDays && hasRemainingDays) const SizedBox(height: 10),
            // Yeni Hafta Planla
            _MealSourceOption(
              icon: Icons.calendar_month_rounded,
              iconColor: const Color(0xFFE53935),
              title: l10n.homeWeeklyEditNewPlan,
              subtitle: l10n.homeWeeklyEditNewPlanDesc,
              onTap: () {
                Navigator.pop(ctx);
                _navigateToNextWeekPlan();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Seçili günü yenileme — önce onay, sonra loading ekranı
  Future<void> _confirmAndRegenerateDay() async {
    if (_mealPlan == null) return;
    final dayIndex =
        _mealPlan!.gunler.indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;
    final selectedDay = _mealPlan!.gunler[dayIndex];
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.refresh_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeWeeklyEditRegenDay,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${selectedDay.gunAdi} için tüm tarifler yenilenecek.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.homeDailyDeleteCancel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Yenile',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    _regenerateSelectedDay();
  }

  /// Seçili günü yeniden oluştur — Loading ekranı ile
  Future<void> _regenerateSelectedDay() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _mealPlan == null) return;

    final plan = _mealPlan!;
    final dayIndex =
        plan.gunler.indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;
    final currentDay = plan.gunler[dayIndex];

    final l10n = AppLocalizations.of(context);
    final firestore = context.read<FirestoreService>();
    final gemini = context.read<GeminiService>();

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegenerateLoadingScreen(
          title: l10n.homeRegeneratingDay,
          subtitle: l10n.homeRegeneratingDaySubtitle,
          task: () async {
            final prefs = await firestore.getUserPreferences(user.uid);
            if (prefs == null) throw Exception('Tercihler yüklenemedi');

            final otherRecipeNames = <String>[];
            for (var i = 0; i < plan.gunler.length; i++) {
              if (i == dayIndex) continue;
              for (final recipe in plan.gunler[i].tumTarifler) {
                otherRecipeNames.add(recipe.yemekAdi);
              }
            }

            final newDay = await gemini.regenerateDay(
              prefs, currentDay, otherRecipeNames,
            );

            final mergedGunler = List<MealDay>.from(plan.gunler);
            mergedGunler[dayIndex] = newDay;

            final updatedPlan = plan.copyWith(gunler: mergedGunler);
            await firestore.saveMealPlan(user.uid, updatedPlan);

            RemoteLoggerService.userAction('day_regenerated',
                screen: 'home', details: {'day': currentDay.gunAdi});
          },
        ),
      ),
    );

    if (!mounted) return;
    if (success == true) {
      await _loadMealPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${currentDay.gunAdi} ${l10n.homeRegenerateSuccess.toLowerCase()}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  /// Tek bir slotu yenile — Loading ekranı ile
  Future<void> _regenerateSlot(String slotKey, Recipe recipe, AppLocalizations l10n, {String? customInstruction}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _mealPlan == null) return;

    final plan = _mealPlan!;
    final dayIndex =
        plan.gunler.indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;
    final currentDay = plan.gunler[dayIndex];

    final firestore = context.read<FirestoreService>();
    final gemini = context.read<GeminiService>();

    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RegenerateLoadingScreen(
          title: l10n.homeRegeneratingSlot,
          subtitle: l10n.homeRegeneratingSlotSubtitle,
          task: () async {
            final prefs = await firestore.getUserPreferences(user.uid);
            if (prefs == null) throw Exception('Tercihler yüklenemedi');

            // Tüm planıdaki diğer tariflerin isimlerini topla
            final otherRecipeNames = <String>[];
            for (var i = 0; i < plan.gunler.length; i++) {
              for (final entry in plan.gunler[i].ogunler.entries) {
                if (i == dayIndex && entry.key == slotKey) continue;
                for (final r in entry.value) {
                  otherRecipeNames.add(r.yemekAdi);
                }
              }
            }

            // Sadece o slotun olduğu bir MealDay oluştur
            final singleSlotDay = MealDay(
              gun: currentDay.gun,
              gunAdi: currentDay.gunAdi,
              ogunler: {slotKey: [recipe]},
            );

            final newDay = await gemini.regenerateDay(
              prefs, singleSlotDay, otherRecipeNames,
              customInstruction: customInstruction,
            );

            // Yeni slotu mevcut güne yerleştir
            final newRecipes = newDay.ogunler[slotKey];
            if (newRecipes == null || newRecipes.isEmpty) {
              throw Exception('Yeni tarif oluşturulamadı');
            }

            await firestore.updateMealSlot(
              user.uid, plan, dayIndex, slotKey, newRecipes,
            );

            RemoteLoggerService.userAction('slot_regenerated',
                screen: 'home',
                details: {
                  'slot': slotKey,
                  'old': recipe.yemekAdi,
                  'new': newRecipes.map((r) => r.yemekAdi).join(', '),
                  if (customInstruction != null) 'instruction': customInstruction,
                });
          },
        ),
      ),
    );

    if (!mounted) return;
    if (success == true) {
      await _loadMealPlan();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeSlotRefreshed(recipe.yemekAdi)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Görsel kart
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/system/Meal_planner_app_202603281444.jpeg',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.homeNoPlan,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.homeNoPlanDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 36),
            // Plan oluştur butonu — gradient
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _navigateToNewPlan,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                  label: Text(l10n.homeCreatePlan),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Tarif tara butonu — secondary
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => _showScanRecipeSheet(),
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(l10n.homeScanRecipe),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  side: BorderSide(
                      color: AppColors.charcoal.withValues(alpha: 0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySelector() {
    const gunAdlari = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysFromMonday = (today.weekday - DateTime.monday) % 7;
    final thisMonday = today.subtract(Duration(days: daysFromMonday));

    final showEditButton =
        _mealPlan != null &&
        !_isPlanExpired &&
        !_isNextWeekDate(_selectedDateStr) &&
        _getMealDayForDate(_selectedDateStr) != null;

    // Seçili güne scroll et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_daySelectorController.hasClients) {
        // Seçili tarihin index'ini bul
        final selectedDate = DateTime.tryParse(_selectedDateStr);
        int selectedIdx = 0;
        if (selectedDate != null) {
          selectedIdx = selectedDate.difference(thisMonday).inDays;
        }
        selectedIdx = selectedIdx.clamp(0, 13);
        // Her buton yaklaşık 70px genişlik + 6px margin
        final editOffset = (showEditButton ? 1 : 0) * 76.0;
        // Seçili günü sola yaslı göster
        final targetOffset = editOffset + selectedIdx * 76.0;
        final maxScroll = _daySelectorController.position.maxScrollExtent;
        _daySelectorController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });

    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 12),
      child: ListView.builder(
        controller: _daySelectorController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14 + (showEditButton ? 1 : 0),
        itemBuilder: (context, index) {
          // İlk eleman: düzenle butonu
          if (showEditButton && index == 0) {
            final l10n = AppLocalizations.of(context);
            return GestureDetector(
              onTap: () => _showWeeklyEditSheet(l10n),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_calendar_rounded,
                        size: 16,
                        color: AppColors.charcoal.withValues(alpha: 0.5)),
                    const SizedBox(width: 4),
                    Text(
                      l10n.homeWeeklyEdit,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }

          final dayIndex = showEditButton ? index - 1 : index;
          final date = thisMonday.add(Duration(days: dayIndex));
          final dateStr = _dateToStr(date);
          final gunAdi = gunAdlari[date.weekday - 1];
          final shortName = _shortDayName(gunAdi);
          final dayNum = dateStr.split('-').last;
          final isSelected = _selectedDateStr == dateStr;
          final isToday = dateStr == _todayStr;
          final isPast = date.isBefore(today);
          final isNextWeek = index >= 7;
          final hasPlan = _getMealDayForDate(dateStr) != null;

          Color bgColor;
          Color textColor;
          Color subTextColor;
          Border? border;
          List<BoxShadow>? shadow;

          if (isSelected) {
            bgColor = isPast
                ? AppColors.charcoal.withValues(alpha: 0.5)
                : AppColors.primary;
            textColor = Colors.white;
            subTextColor = Colors.white.withValues(alpha: 0.7);
            shadow = [
              BoxShadow(
                color: (isPast ? AppColors.charcoal : AppColors.primary)
                    .withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ];
          } else if (isPast) {
            bgColor = AppColors.charcoal.withValues(alpha: 0.04);
            textColor = AppColors.charcoal.withValues(alpha: 0.3);
            subTextColor = AppColors.charcoal.withValues(alpha: 0.2);
            border =
                Border.all(color: AppColors.charcoal.withValues(alpha: 0.08));
          } else if (isNextWeek && hasPlan) {
            // Sonraki hafta, planı var — yeşil kenarlık
            bgColor = Colors.white;
            textColor = AppColors.charcoal;
            subTextColor = AppColors.charcoal.withValues(alpha: 0.45);
            border = Border.all(
                color: AppColors.primary.withValues(alpha: 0.4), width: 1.5);
          } else if (isNextWeek && !hasPlan) {
            // Sonraki hafta, planı yok — soluk
            bgColor = AppColors.charcoal.withValues(alpha: 0.03);
            textColor = AppColors.charcoal.withValues(alpha: 0.45);
            subTextColor = AppColors.charcoal.withValues(alpha: 0.3);
            border =
                Border.all(color: AppColors.border.withValues(alpha: 0.5));
          } else {
            // Bu haftanın gelecek günleri
            bgColor = Colors.white;
            textColor = AppColors.charcoal;
            subTextColor = AppColors.charcoal.withValues(alpha: 0.45);
            border = Border.all(
                color: isToday ? AppColors.primary : AppColors.border,
                width: isToday ? 1.5 : 1);
          }

          return GestureDetector(
            onTap: () => setState(() => _selectedDateStr = dateStr),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: isSelected ? null : border,
                boxShadow: shadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shortName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: subTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    dayNum,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Seçili gün için plan yok — uygun aksiyonları göster
  Widget _buildEmptyDayState(AppLocalizations l10n, bool isNextWeek) {
    // Planı var ama bu gün için öğün yok mu?
    final hasOtherDays = _mealPlan != null && _mealPlan!.gunler.any((d) => d.ogunler.isNotEmpty);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            Text(
              hasOtherDays ? l10n.homeNoPlanForDay : l10n.homeNextWeekNoPlan,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasOtherDays ? l10n.homeNoPlanForDayDesc : l10n.homeNextWeekNoPlanDesc,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: FilledButton.icon(
                  onPressed: isNextWeek ? _navigateToNextWeekPlan : _navigateToNewPlan,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(
                    isNextWeek ? l10n.homeNextWeekGenerate : l10n.homeCreatePlan,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Günlük mod içeriği ──────────────────────────────────

  List<Widget> _buildDailyContent(AppLocalizations l10n) {
    if (_isDailyLoading) {
      return [
        SliverFillRemaining(
          child: Center(
            child: Lottie.asset(
              'assets/animations/lottie/loading.json',
              width: 150,
              height: 150,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ];
    }

    final slots = _defaultSlots();
    final filledSlots = _dailyPlan?.ogunler ?? {};

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                children: () {
                  final items = <Widget>[];
                  // Ek slotları bul (kahvalti_ek_1, ogle_ek_2 gibi)
                  final extraSlots = filledSlots.keys
                      .where((k) => _isExtraSlot(k))
                      .toList()
                    ..sort((a, b) => a.compareTo(b));

                  for (var index = 0; index < slots.length; index++) {
                    final slotKey = slots[index];
                    final recipes = filledSlots[slotKey];

                    // Ana slot'un ek slot'larını topla
                    final extras = extraSlots
                        .where((k) => _baseSlotKey(k) == slotKey)
                        .toList();

                    final hasExtras = extras.isNotEmpty;
                    final isLastDefault = index == slots.length - 1;
                    final isLast = isLastDefault && !hasExtras;

                    if (recipes != null && recipes.isNotEmpty) {
                      items.add(_buildMealBlock(
                        context,
                        slotKey,
                        recipes,
                        l10n,
                        isLast: isLast,
                        isDaily: true,
                      ));
                    } else {
                      items.add(_buildEmptySlot(slotKey, l10n, isLast: isLast));
                    }

                    // Ek slotları ana slot'un hemen ardına ekle
                    for (var ei = 0; ei < extras.length; ei++) {
                      final ekKey = extras[ei];
                      final ekRecipes = filledSlots[ekKey]!;
                      final isLastExtra = isLastDefault && ei == extras.length - 1;
                      items.add(_buildMealBlock(
                        context,
                        ekKey,
                        ekRecipes,
                        l10n,
                        isLast: isLastExtra,
                        isDaily: true,
                      ));
                    }
                  }
                  return items;
                }(),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// Boş slot — grouped kart içinde satır, tıklanınca AI bot açılır
  Widget _buildEmptySlot(String slotKey, AppLocalizations l10n,
      {bool isLast = false}) {
    final slotName = _slotLabel(slotKey, l10n);
    final emoji = _slotEmoji(slotKey);

    return Column(
      children: [
        GestureDetector(
          onTap: () => _openDailyAddMeal(slotKey, l10n),
          child: Container(
            color: AppColors.charcoal.withValues(alpha: 0.02),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  slotName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const Spacer(),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_rounded,
                      size: 15, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  /// Günlük plana yemek ekleme — slot picker + kaynak seçimi
  Future<void> _openDailyAddMeal(String? preselectedSlot, AppLocalizations l10n) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Slot seçimi: preselected varsa direkt, yoksa picker göster
    String? slotKey = preselectedSlot;
    if (slotKey == null) {
      slotKey = await _showDailySlotPicker(l10n);
      if (slotKey == null || !mounted) return;
    }

    final slotLabel = _slotLabel(slotKey, l10n);

    // Kaynak seçimi: Kaydedilenlerden mi, AI ile mi?
    final source = await _showMealSourcePicker(l10n);
    if (source == null || !mounted) return;

    RemoteLoggerService.userAction('daily_add_meal',
        screen: 'home', details: {'slot': slotKey, 'source': source});

    if (source == 'saved') {
      await _pickSavedRecipeForSlot(user.uid, slotKey, slotLabel, l10n);
    } else {
      final changed = await RecipeSuggestionSheet.showForSlot(
        context,
        dayIndex: -1,
        slotKey: slotKey,
        slotLabel: slotLabel,
      );
      if (changed != true || !mounted) return;
      await _loadDailyPlan();
    }
  }

  /// Kaynak seçimi — Kaydedilenlerden mi, AI ile mi?
  Future<String?> _showMealSourcePicker(AppLocalizations l10n) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              l10n.homeDailySourceTitle,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.charcoal),
            ),
            const SizedBox(height: 16),
            // Kaydedilenlerden Seç
            _MealSourceOption(
              icon: Icons.bookmark_rounded,
              iconColor: AppColors.secondary,
              title: l10n.homeDailySourceSaved,
              subtitle: l10n.homeDailySourceSavedDesc,
              onTap: () => Navigator.pop(ctx, 'saved'),
            ),
            const SizedBox(height: 10),
            // AI ile Tarif Al
            _MealSourceOption(
              icon: Icons.auto_awesome_rounded,
              iconColor: AppColors.primary,
              title: l10n.homeDailySourceAI,
              subtitle: l10n.homeDailySourceAIDesc,
              onTap: () => Navigator.pop(ctx, 'ai'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// Kaydedilen tariflerden seçim yaparak slota ekle
  Future<void> _pickSavedRecipeForSlot(
    String uid, String slotKey, String slotLabel, AppLocalizations l10n,
  ) async {
    final firestore = context.read<FirestoreService>();
    final recipes = await firestore.getSavedRecipes(uid);

    if (!mounted) return;

    final selected = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedRecipePickerSheet(
        recipes: recipes,
        slotLabel: slotLabel,
        l10n: l10n,
      ),
    );

    if (selected == null || !mounted) return;

    // Seçilen tarifi slota ekle
    final taste = context.read<TasteProfileService>();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    const gunAdlari = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];
    final gunAdi = gunAdlari[now.weekday - 1];

    var currentDay = await firestore.getDailyPlan(uid, todayStr);
    currentDay ??= MealDay(gun: todayStr, gunAdi: gunAdi, ogunler: {});

    final existingList = currentDay.ogunler[slotKey];

    if (existingList != null && existingList.isNotEmpty && mounted) {
      final existingNames = existingList.map((r) => r.yemekAdi).join(', ');
      final action = await _showReplaceDialog(l10n, existingNames);
      if (action == null || action == 'cancel' || !mounted) return;

      if (action == 'add') {
        // Mevcut listeye ekle
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [...existingList, selected]);
        taste.logRecipeAction(uid, selected, 'added_to_plan');
      } else {
        for (final r in existingList) {
          taste.logRecipeAction(uid, r, 'replaced');
        }
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [selected]);
        taste.logRecipeAction(uid, selected, 'added_to_plan');
      }
    } else {
      await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [selected]);
      taste.logRecipeAction(uid, selected, 'added_to_plan');
    }

    RemoteLoggerService.userAction('saved_recipe_added_to_daily',
        screen: 'home', details: {'slot': slotKey, 'recipe': selected.yemekAdi});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.homeDailySavedAdded(selected.yemekAdi)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );
    await _loadDailyPlan();
  }

  /// Değiştir / Ekleme Yap dialogu (günlük plan kaydedilenler için)
  Future<String?> _showReplaceDialog(AppLocalizations l10n, String existingName) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.suggestReplaceConfirm,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '$existingName zaten bu öğünde mevcut.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'add'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.suggestAddAlongside,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'replace'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.suggestReplace,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.charcoal.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                ),
                child: Text(l10n.suggestCancel,
                    style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Akıllı slot picker — saate göre default öğünü belirler
  Future<String?> _showDailySlotPicker(AppLocalizations l10n) async {
    final slots = _defaultSlots();
    final hour = DateTime.now().hour;

    // Saate göre en yakın sonraki öğünü bul
    String defaultSlot = slots.last;
    if (hour < 10 && slots.contains('kahvalti')) {
      defaultSlot = 'kahvalti';
    } else if (hour < 14 && slots.contains('ogle')) {
      defaultSlot = 'ogle';
    } else if (hour < 12 && slots.contains('ara_ogun_1')) {
      defaultSlot = 'ara_ogun_1';
    } else if (hour < 16 && slots.contains('ara_ogun_2')) {
      defaultSlot = 'ara_ogun_2';
    } else if (slots.contains('aksam')) {
      defaultSlot = 'aksam';
    }
    // Esnek plan
    if (hour < 12 && slots.contains('ana_ogun_1')) {
      defaultSlot = 'ana_ogun_1';
    } else if (hour < 18 && slots.contains('ana_ogun_2')) {
      defaultSlot = 'ana_ogun_2';
    } else if (slots.contains('ara_ogun')) {
      defaultSlot = 'ara_ogun';
    }

    String selected = defaultSlot;
    final filledSlots = _dailyPlan?.ogunler ?? {};

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.homeDailyPickSlot,
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.charcoal),
              ),
              const SizedBox(height: 16),
              // Slot seçenekleri
              ...slots.map((slot) {
                final isSel = selected == slot;
                final isFilled = filledSlots.containsKey(slot);
                final label = _slotLabel(slot, l10n);
                final emoji = _slotEmoji(slot);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => setS(() => selected = slot),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              isSel ? AppColors.primary : AppColors.border,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(emoji,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.charcoal,
                                      ),
                                ),
                                if (isFilled)
                                  Text(
                                    filledSlots[slot]!.map((r) => r.yemekAdi).join(', '),
                                    style: Theme.of(ctx)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.charcoal
                                              .withValues(alpha: 0.4),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSel)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
              // Onayla
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(l10n.homeDailyAddMeal,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Ortak: Yemek Kartı ─────────────────────────────────

  /// Çoklu tarif bloğu — bir öğün slotundaki tüm tarifleri gruplu gösterir
  Widget _buildMealBlock(
    BuildContext context,
    String slotKey,
    List<Recipe> recipes,
    AppLocalizations l10n, {
    bool isLast = false,
    bool isDaily = false,
    bool readOnly = false,
  }) {
    final slotName = _slotLabel(slotKey, l10n);
    final emoji = _slotEmoji(slotKey);
    final canSwipeDelete = !isDaily && !readOnly;
    final totalKalori = recipes.fold(0, (s, r) => s + r.kalori);
    final totalSure = recipes.fold(0, (s, r) => s + r.toplamSureDk);

    Widget cardBody = Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Blok başlığı: emoji + öğün adı + toplam kalori/süre + aksiyon butonları
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                slotName,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              if (totalKalori > 0) ...[
                Icon(Icons.local_fire_department_rounded,
                    size: 13, color: const Color(0xFFE65100)),
                const SizedBox(width: 2),
                Text(
                  '$totalKalori',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: const Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                ),
                const SizedBox(width: 8),
              ],
              if (totalSure > 0) ...[
                Icon(Icons.schedule_rounded,
                    size: 13,
                    color: AppColors.charcoal.withValues(alpha: 0.4)),
                const SizedBox(width: 2),
                Text(
                  l10n.mealPlanMinutes(totalSure),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                ),
              ],
              if (isDaily) ...[
                const SizedBox(width: 6),
                _DailyActionButton(
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.primary,
                  onTap: () => _replaceDailyRecipe(slotKey, l10n),
                ),
                const SizedBox(width: 4),
                _DailyActionButton(
                  icon: Icons.add_rounded,
                  color: AppColors.primary,
                  onTap: () => _addToDailyMeal(slotKey, l10n),
                ),
                const SizedBox(width: 4),
                _DailyActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFE53935),
                  onTap: () => _deleteDailyRecipe(slotKey, recipes, l10n),
                ),
              ] else if (!readOnly) ...[
                const SizedBox(width: 6),
                _DailyActionButton(
                  icon: Icons.refresh_rounded,
                  color: AppColors.primary,
                  onTap: () => _showRefreshDialog(slotKey, recipes, l10n),
                ),
                const SizedBox(width: 4),
                _DailyActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFE53935),
                  onTap: () async {
                    final confirmed = await _confirmWeeklyDelete(recipes, l10n);
                    if (confirmed) _deleteWeeklyRecipe(slotKey, recipes, l10n);
                  },
                ),
                const SizedBox(width: 4),
                _AddToSlotButton(
                  onTap: () => _openAddMealForSlot(slotKey, l10n),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Tarifler — çoklu tarifse ince çerçeve içinde gruplu
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Container(
              decoration: recipes.length > 1
                  ? BoxDecoration(
                      border: Border.all(
                        color: AppColors.border.withValues(alpha: 0.6),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(recipes.length, (i) {
                  final recipe = recipes[i];
                  final isLastRecipe = i == recipes.length - 1;
                  final isMulti = recipes.length > 1;
                  return GestureDetector(
                    onTap: () => RecipeDetailScreen.open(context, recipe),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: isMulti
                          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                          : EdgeInsets.zero,
                      decoration: !isLastRecipe && isMulti
                          ? BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.border.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                            )
                          : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarif adı + sepet ikonu + bireysel kalori
                          Row(
                            children: [
                              // Sepet ikonu — malzemeleri göster
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  _showIngredientsSheet(recipe);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 17,
                                    color: AppColors.primary.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  isMulti
                                      ? '${i + 1}. ${recipe.yemekAdi}'
                                      : recipe.yemekAdi,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.charcoal,
                                        height: 1.3,
                                      ),
                                ),
                              ),
                              if (isMulti && recipe.kalori > 0) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.local_fire_department_rounded,
                                    size: 11, color: const Color(0xFFE65100).withValues(alpha: 0.6)),
                                const SizedBox(width: 1),
                                Text(
                                  '${recipe.kalori}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: const Color(0xFFE65100).withValues(alpha: 0.6),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 10,
                                      ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Chip'ler
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _Chip(
                                label: _difficultyLabel(recipe.zorluk, l10n),
                                color: _difficultyColor(recipe.zorluk),
                              ),
                              ...recipe.mutfaklar.take(2).map(
                                    (m) => _Chip(
                                      label: _cuisineLabel(m),
                                      color: AppColors.primary,
                                    ),
                                  ),
                            ],
                          ),
                          // Rating strip
                          _buildRatingStrip(recipe),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );

    // Haftalık plan kartlarında sola kaydır = sil, sağa kaydır = yenile
    if (canSwipeDelete) {
      cardBody = Dismissible(
        key: ValueKey('${slotKey}_${recipes.map((r) => r.id).join('_')}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            final confirmed = await _confirmWeeklyDelete(recipes, l10n);
            if (confirmed) _deleteWeeklyRecipe(slotKey, recipes, l10n);
          } else {
            _showRefreshDialog(slotKey, recipes, l10n);
          }
          return false;
        },
        background: Container(
          color: AppColors.primary,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
              SizedBox(height: 2),
              Text('Yenile',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ),
        secondaryBackground: Container(
          color: const Color(0xFFE53935),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 26),
              SizedBox(height: 2),
              Text('Sil',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
        ),
        child: cardBody,
      );
    }

    return Column(
      children: [
        cardBody,
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: AppColors.border.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  /// AI yenileme diyaloğu — opsiyonel açıklama girişi veya otomatik yenile
  Future<void> _showRefreshDialog(String slotKey, List<Recipe> recipes, AppLocalizations l10n) async {
    final instructionController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeRefreshDialogTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeRefreshDialogDesc(recipes.map((r) => r.yemekAdi).join(', ')),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Opsiyonel açıklama alanı
              TextField(
                controller: instructionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: l10n.homeRefreshDialogHint,
                  hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.charcoal.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // Otomatik yenile butonu
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, ''),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.homeRefreshAutoButton,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // AI ile açıklamalı yenile
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final text = instructionController.text.trim();
                    Navigator.pop(ctx, text.isEmpty ? '' : text);
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: Text(l10n.homeRefreshWithDescButton,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // İptal
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: Text(l10n.homeDailyDeleteCancel,
                    style: TextStyle(
                      color: AppColors.charcoal.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
    instructionController.dispose();

    if (result == null || !mounted) return; // İptal
    _regenerateSlot(slotKey, recipes.first, l10n, customInstruction: result.isEmpty ? null : result);
  }

  /// Haftalık plan silme onay diyaloğu
  Future<bool> _confirmWeeklyDelete(List<Recipe> recipes, AppLocalizations l10n) async {
    final names = recipes.map((r) => r.yemekAdi).join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE53935), size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeDailyDeleteTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeDailyDeleteMessage(names),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.homeDailyDeleteCancel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.homeDailyDeleteConfirm,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return confirmed == true;
  }

  /// Haftalık plandaki tüm slotu sil
  Future<void> _deleteWeeklyRecipe(
    String slotKey, List<Recipe> recipes, AppLocalizations l10n,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _mealPlan == null) return;

    // Seçili tarihe ait gün indexini bul
    final dayIndex = _mealPlan!.gunler
        .indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;

    try {
      await context.read<FirestoreService>().removeWeeklySlot(
            user.uid, _mealPlan!, dayIndex, slotKey);

      final names = recipes.map((r) => r.yemekAdi).join(', ');
      RemoteLoggerService.userAction('weekly_recipe_deleted',
          screen: 'home',
          details: {'slot': slotKey, 'recipes': names});

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeDailyDeleted(names)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.charcoal,
        ),
      );
      await _loadMealPlan();
    } catch (e) {
      RemoteLoggerService.error('weekly_recipe_delete_failed',
          error: e, screen: 'home');
    }
  }

  /// Günlük plandaki öğün slotunu sil
  Future<void> _deleteDailyRecipe(
    String slotKey, List<Recipe> recipes, AppLocalizations l10n,
  ) async {
    final names = recipes.map((r) => r.yemekAdi).join(', ');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFE53935), size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.homeDailyDeleteTitle,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.homeDailyDeleteMessage(names),
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.charcoal.withValues(alpha: 0.55),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.charcoal,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.homeDailyDeleteCancel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.homeDailyDeleteConfirm,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = context.read<FirestoreService>();
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final currentDay = _dailyPlan;
    if (currentDay == null) return;

    await firestore.removeDailySlot(user.uid, todayStr, currentDay, slotKey);

    RemoteLoggerService.userAction('daily_recipe_deleted',
        screen: 'home', details: {'slot': slotKey, 'recipes': names});

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.homeDailyDeleted(names)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.charcoal,
      ),
    );
    await _loadDailyPlan();
  }

  /// Günlük plandaki tarifi değiştir — kaynak seçici açılır
  Future<void> _replaceDailyRecipe(String slotKey, AppLocalizations l10n) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final slotLabel = _slotLabel(slotKey, l10n);

    // Kaynak seçimi
    final source = await _showMealSourcePicker(l10n);
    if (source == null || !mounted) return;

    RemoteLoggerService.userAction('daily_replace_meal',
        screen: 'home', details: {'slot': slotKey, 'source': source});

    if (source == 'saved') {
      final firestore = context.read<FirestoreService>();
      final recipes = await firestore.getSavedRecipes(user.uid);
      if (!mounted) return;

      final selected = await showModalBottomSheet<Recipe>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _SavedRecipePickerSheet(
          recipes: recipes,
          slotLabel: slotLabel,
          l10n: l10n,
        ),
      );
      if (selected == null || !mounted) return;

      // Direkt değiştir (replace)
      final taste = context.read<TasteProfileService>();
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final currentDay = _dailyPlan;
      if (currentDay == null) return;

      final existingList = currentDay.ogunler[slotKey];
      if (existingList != null) {
        for (final r in existingList) {
          taste.logRecipeAction(user.uid, r, 'replaced');
        }
      }

      await firestore.addDailySlot(user.uid, todayStr, currentDay, slotKey, [selected]);
      taste.logRecipeAction(user.uid, selected, 'added_to_plan');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeDailySavedAdded(selected.yemekAdi)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );
      await _loadDailyPlan();
    } else {
      final changed = await RecipeSuggestionSheet.showForSlot(
        context,
        dayIndex: -1,
        slotKey: slotKey,
        slotLabel: slotLabel,
      );
      if (changed != true || !mounted) return;
      await _loadDailyPlan();
    }
  }

  /// Günlük planda mevcut öğüne ek tarif ekler (listeye eklenir)
  Future<void> _addToDailyMeal(String slotKey, AppLocalizations l10n) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Base slot key'i bul (ek slot'tan geliyorsa orijinalini al)
    final baseKey = _baseSlotKey(slotKey);
    final currentDay = _dailyPlan;
    if (currentDay == null) return;

    final slotLabel = _slotLabel(baseKey, l10n);

    // Kaynak seçimi: Kaydedilenlerden mi, AI ile mi?
    final source = await _showMealSourcePicker(l10n);
    if (source == null || !mounted) return;

    RemoteLoggerService.userAction('daily_add_extra_meal',
        screen: 'home', details: {'baseSlot': baseKey, 'source': source});

    if (source == 'saved') {
      await _pickSavedRecipeForSlot(user.uid, baseKey, slotLabel, l10n);
    } else {
      final changed = await RecipeSuggestionSheet.showForSlot(
        context,
        dayIndex: -1,
        slotKey: baseKey,
        slotLabel: slotLabel,
      );
      if (changed != true || !mounted) return;
      await _loadDailyPlan();
    }
  }

  Widget _buildRatingStrip(Recipe recipe) {
    final recipeKey =
        recipe.id.isNotEmpty ? recipe.id : recipe.yemekAdi;
    final currentRating = _ratedRecipes[recipeKey];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          _RatingButton(
            emoji: '😍',
            label: 'Bayıldım',
            isSelected: currentRating == 3,
            color: const Color(0xFFE91E63),
            onTap: () => _rateRecipe(recipe, 3),
          ),
          const SizedBox(width: 6),
          _RatingButton(
            emoji: '👍',
            label: 'Güzel',
            isSelected: currentRating == 2,
            color: AppColors.primary,
            onTap: () => _rateRecipe(recipe, 2),
          ),
          const SizedBox(width: 6),
          _RatingButton(
            emoji: '👎',
            label: 'Değil',
            isSelected: currentRating == 1,
            color: const Color(0xFF9E9E9E),
            onTap: () => _rateRecipe(recipe, 1),
          ),
        ],
      ),
    );
  }

  // ─── Malzeme → Alışveriş Sepeti Bottom Sheet ──────────

  /// Tarifin malzemelerini bottom sheet'te gösterir.
  /// Her malzemenin yanında sepet butonu ile listeye ekleme yapılabilir.
  void _showIngredientsSheet(Recipe recipe) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);
    final firestore = context.read<FirestoreService>();

    RemoteLoggerService.userAction('ingredients_sheet_opened',
        screen: 'home', details: {'recipe': recipe.yemekAdi});

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _IngredientsSheet(
        recipe: recipe,
        uid: uid,
        firestore: firestore,
        l10n: l10n,
      ),
    );
  }

  void _rateRecipe(Recipe recipe, int rating) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final recipeKey =
        recipe.id.isNotEmpty ? recipe.id : recipe.yemekAdi;

    setState(() => _ratedRecipes[recipeKey] = rating);

    // Fire-and-forget: taste profile'a kaydet
    context
        .read<TasteProfileService>()
        .logRecipeAction(uid, recipe, 'rated', rating: rating);

    RemoteLoggerService.userAction('recipe_rated',
        screen: 'home',
        details: {'recipe': recipe.yemekAdi, 'rating': rating});

    // Kullanıcıya geri bildirim snackbar'ı
    final String message;
    final Color bgColor;
    switch (rating) {
      case 3:
        message = '${recipe.yemekAdi} favorilerine eklendi! 😍';
        bgColor = const Color(0xFFE91E63);
        break;
      case 2:
        message = 'Beğenin kaydedildi, benzerlerini önereceğiz 👍';
        bgColor = AppColors.primary;
        break;
      default:
        message = '${recipe.yemekAdi} artık sana önerilmeyecek 👎';
        bgColor = const Color(0xFF616161);
    }

    _showRatingFeedback(message, bgColor);
  }

  void _showRatingFeedback(String message, Color bgColor) {
    if (!mounted) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RatingSnackOverlay(
        message: message,
        color: bgColor,
        onDismiss: () => entry.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  Future<void> _openAddMealForSlot(
      String slotKey, AppLocalizations l10n) async {
    final plan = _mealPlan;
    if (plan == null) return;

    final dayIndex =
        plan.gunler.indexWhere((d) => d.gun == _selectedDateStr);
    if (dayIndex == -1) return;
    final day = plan.gunler[dayIndex];
    final slotLabel = _slotLabel(slotKey, l10n);
    final fullLabel = '${day.gunAdi} - $slotLabel';

    RemoteLoggerService.userAction('add_meal_to_slot',
        screen: 'home', details: {'day': day.gunAdi, 'slot': slotKey});

    // Kaynak seçici: false → AI, true → kaydedilen tarif eklendi
    final result = await AddMealSourceSheet.show(
      context,
      dayIndex: dayIndex,
      slotKey: slotKey,
      slotLabel: fullLabel,
    );

    if (result == true) {
      // Kaydedilenlerden eklendi, planı yenile
      refreshMealPlan();
    } else if (result == false && mounted) {
      // AI ile ekle seçildi
      final changed = await RecipeSuggestionSheet.showForSlot(
        context,
        dayIndex: dayIndex,
        slotKey: slotKey,
        slotLabel: fullLabel,
      );
      if (changed == true) refreshMealPlan();
    }
  }
}

// ─── Yardımcı widget'lar ──────────────────────────────────

/// Öğün kartının sağ üstündeki "+" butonu
class _AddToSlotButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddToSlotButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 16,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Emoji rating butonu — tek dokunuşluk geri bildirim
class _RatingButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RatingButton({
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AppColors.border.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: TextStyle(fontSize: isSelected ? 16 : 14)),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? color
                          : AppColors.charcoal.withValues(alpha: 0.35),
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: isSelected ? 12 : 11,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay ile gösterilen rating geri bildirim tostu
class _RatingSnackOverlay extends StatefulWidget {
  final String message;
  final Color color;
  final VoidCallback onDismiss;

  const _RatingSnackOverlay({
    required this.message,
    required this.color,
    required this.onDismiss,
  });

  @override
  State<_RatingSnackOverlay> createState() => _RatingSnackOverlayState();
}

class _RatingSnackOverlayState extends State<_RatingSnackOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<double>(begin: 80, end: 0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 90,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Kamera / Galeri seçim butonu
class _ScanOptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ScanOptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ─── Günlük Plan Aksiyon Butonu (Sil / Değiştir) ─────────

class _DailyActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DailyActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

// ─── Kaynak Seçim Kartı ─────────────────────────────────

class _MealSourceOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MealSourceOption({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.5),
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.charcoal.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}

// ─── Kaydedilen Tarif Seçici ─────────────────────────────

class _SavedRecipePickerSheet extends StatelessWidget {
  final List<Recipe> recipes;
  final String slotLabel;
  final AppLocalizations l10n;

  const _SavedRecipePickerSheet({
    required this.recipes,
    required this.slotLabel,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.bookmark_rounded,
                              color: AppColors.secondary, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.homeDailySavedPickerTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.charcoal,
                                    ),
                              ),
                              Text(
                                slotLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // İçerik
              Expanded(
                child: recipes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.homeDailySavedPickerEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.4),
                                ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: recipes.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final recipe = recipes[i];
                          return _SavedRecipeCard(
                            recipe: recipe,
                            l10n: l10n,
                            onTap: () => Navigator.pop(ctx, recipe),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SavedRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _SavedRecipeCard({
    required this.recipe,
    required this.l10n,
    required this.onTap,
  });

  String get _mealTypeEmoji {
    switch (recipe.ogunTipi) {
      case 'kahvalti':
        return '🌅';
      case 'ana_yemek':
        return '🍽️';
      case 'ara_ogun':
      case 'atistirmalik':
        return '🥪';
      case 'tatli':
        return '🍰';
      case 'corba':
        return '🥣';
      case 'salata':
        return '🥗';
      default:
        return '🍳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(_mealTypeEmoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.yemekAdi,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (recipe.kalori > 0) ...[
                        Icon(Icons.local_fire_department_rounded,
                            size: 12, color: const Color(0xFFE65100)),
                        const SizedBox(width: 2),
                        Text('${recipe.kalori}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: const Color(0xFFE65100),
                                    fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                      ],
                      if (recipe.toplamSureDk > 0) ...[
                        Icon(Icons.schedule_rounded,
                            size: 12,
                            color:
                                AppColors.charcoal.withValues(alpha: 0.4)),
                        const SizedBox(width: 2),
                        Text(l10n.mealPlanMinutes(recipe.toplamSureDk),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.5))),
                        const SizedBox(width: 8),
                      ],
                      if (recipe.mutfaklar.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            recipe.mutfaklar.first,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Taranan tarif → plana ekle bottom sheet ────────────────────

class _ScanAddToPlanSheet extends StatefulWidget {
  final MealPlan plan;
  final String recipeName;
  final void Function(int dayIndex, String slotKey) onSelect;

  const _ScanAddToPlanSheet({
    required this.plan,
    required this.recipeName,
    required this.onSelect,
  });

  @override
  State<_ScanAddToPlanSheet> createState() => _ScanAddToPlanSheetState();
}

class _ScanAddToPlanSheetState extends State<_ScanAddToPlanSheet> {
  int? _selectedDay;

  static const _slotKeys = [
    'kahvalti',
    'ogle',
    'aksam',
    'ara_ogun',
    'atistirmalik',
  ];

  String _slotLabel(String slot) {
    switch (slot) {
      case 'kahvalti': return 'Kahvaltı';
      case 'ogle': return 'Öğle';
      case 'aksam': return 'Akşam';
      case 'ara_ogun': return 'Ara Öğün';
      case 'atistirmalik': return 'Atıştırmalık';
      default: return slot;
    }
  }

  String _slotEmoji(String slot) {
    switch (slot) {
      case 'kahvalti': return '\u{1F305}';
      case 'ogle': return '\u{2600}\u{FE0F}';
      case 'aksam': return '\u{1F319}';
      case 'ara_ogun': return '\u{1F34E}';
      case 'atistirmalik': return '\u{1F36A}';
      default: return '\u{1F37D}\u{FE0F}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(l10n.addToPlan,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.charcoal)),
          const SizedBox(height: 4),
          Text(widget.recipeName,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.charcoal.withValues(alpha: 0.5)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),

          if (_selectedDay == null) ...[
            Text(l10n.selectDay,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal.withValues(alpha: 0.5))),
            const SizedBox(height: 12),
            ...widget.plan.gunler.asMap().entries.map((entry) {
              final idx = entry.key;
              final day = entry.value;
              final isPast = widget.plan.pastDayIndices.contains(idx);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  enabled: !isPast,
                  leading: Text(
                    day.gunAdi.isNotEmpty ? day.gunAdi.substring(0, 3) : '${idx + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isPast
                          ? AppColors.charcoal.withValues(alpha: 0.2)
                          : AppColors.primary,
                    ),
                  ),
                  title: Text(day.gun,
                    style: TextStyle(
                      color: isPast
                          ? AppColors.charcoal.withValues(alpha: 0.3)
                          : AppColors.charcoal)),
                  trailing: Icon(Icons.chevron_right_rounded,
                    color: isPast
                        ? AppColors.charcoal.withValues(alpha: 0.1)
                        : AppColors.charcoal.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  onTap: isPast ? null : () => setState(() => _selectedDay = idx),
                ),
              );
            }),
          ] else ...[
            GestureDetector(
              onTap: () => setState(() => _selectedDay = null),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(widget.plan.gunler[_selectedDay!].gunAdi,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.selectMeal,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal.withValues(alpha: 0.5))),
            const SizedBox(height: 12),
            ..._slotKeys.map((slot) {
              final existingList = widget.plan.gunler[_selectedDay!].ogunler[slot];
              final hasExisting = existingList != null && existingList.isNotEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: Text(_slotEmoji(slot), style: const TextStyle(fontSize: 20)),
                  title: Text(_slotLabel(slot),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: hasExisting
                      ? Text(existingList.map((r) => r.yemekAdi).join(', '),
                          style: TextStyle(fontSize: 12,
                            color: AppColors.charcoal.withValues(alpha: 0.4)),
                          maxLines: 1, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Icon(
                    hasExisting ? Icons.swap_horiz_rounded : Icons.add_rounded,
                    color: AppColors.primary, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                  onTap: () => widget.onSelect(_selectedDay!, slot),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ─── Malzeme Listesi Bottom Sheet ────────────────────────

/// Tarifin malzemelerini listeler, her birinin yanında sepete ekleme butonu.
class _IngredientsSheet extends StatefulWidget {
  final Recipe recipe;
  final String uid;
  final FirestoreService firestore;
  final AppLocalizations l10n;

  const _IngredientsSheet({
    required this.recipe,
    required this.uid,
    required this.firestore,
    required this.l10n,
  });

  @override
  State<_IngredientsSheet> createState() => _IngredientsSheetState();
}

class _IngredientsSheetState extends State<_IngredientsSheet> {
  final Set<int> _addedIndices = {};

  @override
  Widget build(BuildContext context) {
    final ingredients = widget.recipe.malzemeler;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_cart_rounded,
                      color: AppColors.primary, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.recipe.yemekAdi,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${ingredients.length} malzeme',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.charcoal
                                .withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                ),
                // Tümünü ekle butonu
                TextButton.icon(
                  onPressed: () => _addAllIngredients(),
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text('Tümünü Ekle',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(
              height: 1, color: AppColors.charcoal.withValues(alpha: 0.06)),
          // Malzeme listesi
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
              itemCount: ingredients.length,
              itemBuilder: (ctx, i) {
                final ingredient = ingredients[i];
                final isAdded = _addedIndices.contains(i);

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  leading: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isAdded
                        ? Icon(Icons.check_circle_rounded,
                            key: const ValueKey('check'),
                            color: AppColors.primary,
                            size: 22)
                        : Icon(Icons.circle_outlined,
                            key: const ValueKey('circle'),
                            color: AppColors.charcoal
                                .withValues(alpha: 0.15),
                            size: 22),
                  ),
                  title: Text(ingredient,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isAdded
                            ? AppColors.charcoal.withValues(alpha: 0.35)
                            : AppColors.charcoal,
                        decoration:
                            isAdded ? TextDecoration.lineThrough : null,
                        decorationColor:
                            AppColors.charcoal.withValues(alpha: 0.3),
                      )),
                  trailing: isAdded
                      ? null
                      : IconButton(
                          onPressed: () => _addIngredient(i, ingredient),
                          icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18),
                          color: AppColors.primary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 36, minHeight: 36),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addIngredient(int index, String ingredient) async {
    HapticFeedback.lightImpact();
    setState(() => _addedIndices.add(index));

    await _addToShoppingList(ingredient);
  }

  Future<void> _addAllIngredients() async {
    HapticFeedback.mediumImpact();
    final ingredients = widget.recipe.malzemeler;
    final toAdd = <String>[];
    for (int i = 0; i < ingredients.length; i++) {
      if (!_addedIndices.contains(i)) {
        toAdd.add(ingredients[i]);
      }
    }
    if (toAdd.isEmpty) return;

    setState(() {
      for (int i = 0; i < ingredients.length; i++) {
        _addedIndices.add(i);
      }
    });

    await _addToShoppingList(null, bulk: toAdd);
  }

  /// Malzemeleri ekleyeceği listeyi seçtiren modal gösterir.
  Future<void> _addToShoppingList(String? ingredient,
      {List<String>? bulk}) async {
    final l10n = widget.l10n;
    final items = bulk != null
        ? bulk.map((b) => ShoppingItem(name: b, quantity: '')).toList()
        : [ShoppingItem(name: ingredient!, quantity: '')];

    final itemCountLabel =
        items.length > 1 ? '${items.length} malzeme' : items.first.name;

    try {
      final lists = await widget.firestore.getShoppingLists(widget.uid);
      if (!mounted) return;

      final scaffoldMessenger = ScaffoldMessenger.of(context);

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(l10n.addToShoppingList,
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal)),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Text(itemCountLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.charcoal.withValues(alpha: 0.4))),
              ),

              // Yeni liste oluştur
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: Text(l10n.createNewList,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final now = DateTime.now();
                  final title =
                      '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} Alışveriş';
                  final newList = ShoppingList(
                    id: '',
                    title: title,
                    items: items,
                    createdAt: now,
                  );
                  await widget.firestore
                      .saveShoppingList(widget.uid, newList);
                  scaffoldMessenger.clearSnackBars();
                  scaffoldMessenger.showSnackBar(SnackBar(
                    content: Text('${l10n.addedToList}: $title'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ));
                },
              ),

              // Mevcut listeler
              if (lists.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...lists.take(5).map((list) => ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color:
                              AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined,
                            color: AppColors.secondary, size: 18),
                      ),
                      title: Text(list.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500)),
                      subtitle: Text('${list.items.length} ürün',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.charcoal
                                  .withValues(alpha: 0.4))),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final updatedItems = [...list.items, ...items];
                        await widget.firestore
                            .updateShoppingListItems(
                                widget.uid, list.id, updatedItems);
                        scaffoldMessenger.clearSnackBars();
                        scaffoldMessenger.showSnackBar(SnackBar(
                          content: Text(
                              '${l10n.addedToList}: ${list.title}'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                    )),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      RemoteLoggerService.error('ingredient_add_error', error: e);
    }
  }
}
