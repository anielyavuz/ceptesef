import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/groq_service.dart';
import '../../../core/services/recipe_cache_service.dart';
import '../../../core/services/remote_logger_service.dart';
import 'meal_plan_preview_screen.dart';

/// Gemini ile haftalık yemek planı üretirken gösterilen ekran.
/// Lottie animasyonu + durum metni.
class MealPlanGenerationScreen extends StatefulWidget {
  final String uid;
  final UserPreferences preferences;
  final DateTime? startDate;
  final bool returnToHome;
  final List<int>? selectedDayIndices; // Seçili gün indeksleri (null = tüm hafta)
  final MealPlan? existingPlan; // Mevcut plan (kısmi güncelleme için)
  final Map<String, Map<String, List<String>>>? manualEntries; // Manuel plan girişleri (enrich modu)

  const MealPlanGenerationScreen({
    super.key,
    required this.uid,
    required this.preferences,
    this.startDate,
    this.returnToHome = false,
    this.selectedDayIndices,
    this.existingPlan,
    this.manualEntries,
  });

  @override
  State<MealPlanGenerationScreen> createState() =>
      _MealPlanGenerationScreenState();
}

class _MealPlanGenerationScreenState extends State<MealPlanGenerationScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    RemoteLoggerService.setScreen('meal_plan_generation');
    RemoteLoggerService.info(
        widget.manualEntries != null
            ? 'manual_plan_enrichment_started'
            : 'meal_plan_generation_started',
        screen: 'meal_plan_generation');
    _generate();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final stopwatch = Stopwatch()..start();

    try {
      final geminiService = context.read<GeminiService>();
      final cacheService = context.read<RecipeCacheService>();

      MealPlan generatedPlan;
      String usedProvider;

      if (widget.manualEntries != null) {
        // Manuel plan modu — önce Groq, hata alırsa Gemini fallback
        RemoteLoggerService.info('manual_plan_enrich_started',
            screen: 'meal_plan_generation',
            extra: {'entries_count': widget.manualEntries!.length});

        try {
          final groq = context.read<GroqService>();
          generatedPlan = await groq.enrichManualPlan(
            widget.preferences,
            widget.manualEntries!,
            startDate: widget.startDate,
          );
          usedProvider = 'groq_enrich';
        } catch (e) {
          debugPrint('⚠️ Groq enrich hata, Gemini fallback: $e');
          RemoteLoggerService.warning('groq_enrich_fallback',
              screen: 'meal_plan_generation');
          generatedPlan = await geminiService.enrichManualPlan(
            widget.preferences,
            widget.manualEntries!,
            startDate: widget.startDate,
          );
          usedProvider = 'gemini_enrich';
        }
      } else {
        // Normal AI üretim modu
        // 1. Cache'den uygun tarifleri çek
        final cachedRecipes =
            await cacheService.getMatchingRecipes(widget.preferences);

        RemoteLoggerService.info(
          'cache_recipes_loaded',
          screen: 'meal_plan_generation',
          extra: {'cached_count': cachedRecipes.length},
        );

        // 2. Önce Groq dene, rate limit veya hata alırsa Gemini'ye fallback
        usedProvider = 'groq';

        try {
          final groq = context.read<GroqService>();
          generatedPlan = await groq.generateMealPlan(
            widget.preferences,
            cachedRecipes: cachedRecipes,
            startDate: widget.startDate,
            selectedDayCount: widget.selectedDayIndices?.length,
          );
          RemoteLoggerService.info('meal_plan_provider_used',
              screen: 'meal_plan_generation', extra: {'provider': 'groq'});
        } on GroqApiException catch (e) {
          debugPrint('⚠️ Groq hata (${e.statusCode}), Gemini fallback...');
          RemoteLoggerService.warning(
              'groq_meal_plan_fallback_${e.statusCode}',
              screen: 'meal_plan_generation');
          generatedPlan = await geminiService.generateMealPlan(
            widget.preferences,
            cachedRecipes: cachedRecipes,
            startDate: widget.startDate,
            selectedDayCount: widget.selectedDayIndices?.length,
          );
          usedProvider = 'gemini';
        } catch (e) {
          debugPrint('⚠️ Groq genel hata, Gemini fallback: $e');
          RemoteLoggerService.warning('groq_meal_plan_fallback_error',
              screen: 'meal_plan_generation');
          generatedPlan = await geminiService.generateMealPlan(
            widget.preferences,
            cachedRecipes: cachedRecipes,
            startDate: widget.startDate,
            selectedDayCount: widget.selectedDayIndices?.length,
          );
          usedProvider = 'gemini';
        }
      }
      debugPrint('🤖 Meal plan provider: $usedProvider');

      // 3. Seçili günler varsa tarihleri düzelt / mevcut planla birleştir
      MealPlan finalPlan;
      List<int>? affectedDays;
      final indices = widget.selectedDayIndices;

      try {
        debugPrint('MERGE: indices=$indices, existingPlan=${widget.existingPlan != null}, genDays=${generatedPlan.gunler.length}');
      } catch (_) {}

      if (indices != null && indices.isNotEmpty) {
        // Seçili günler var — doğru tarih/isimleri hesapla
        const gunAdlari = ['Pazartesi', 'Sali', 'Carsamba', 'Persembe', 'Cuma', 'Cumartesi', 'Pazar'];
        final refDate = widget.startDate ?? DateTime.now();
        final daysFromMon = (refDate.weekday - DateTime.monday) % 7;
        final monday = refDate.subtract(Duration(days: daysFromMon));
        final weekStart = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

        // Mevcut planı 7 (veya 14) günlük şablona genişlet
        final maxIdx = indices.reduce((a, b) => a > b ? a : b);
        final totalDays = maxIdx >= 7 ? 14 : 7;

        // Mevcut günleri map'e çevir (tarih → MealDay)
        final existingMap = <String, MealDay>{};
        if (widget.existingPlan != null) {
          for (final d in widget.existingPlan!.gunler) {
            existingMap[d.gun] = d;
          }
        }

        // 7 günlük şablon oluştur, mevcut günleri koru
        final mergedGunler = List.generate(totalDays, (i) {
          final date = monday.add(Duration(days: i));
          final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          // Mevcut planda bu tarih varsa onu kullan
          if (existingMap.containsKey(dateStr)) {
            return existingMap[dateStr]!;
          }
          return MealDay(
            gun: dateStr,
            gunAdi: gunAdlari[i % 7],
            ogunler: const {},
          );
        });

        // Seçili günlere üretilen planı yerleştir
        affectedDays = indices;
        for (var i = 0; i < indices.length; i++) {
          final idx = indices[i];
          if (idx < mergedGunler.length && i < generatedPlan.gunler.length) {
            mergedGunler[idx] = MealDay(
              gun: mergedGunler[idx].gun,
              gunAdi: mergedGunler[idx].gunAdi,
              ogunler: generatedPlan.gunler[i].ogunler,
            );
          }
        }

        // Boş günleri temizle — sadece öğünü olan günleri tut
        final nonEmptyDays = mergedGunler.where((d) => d.ogunler.isNotEmpty).toList();

        finalPlan = MealPlan(
          haftaBaslangic: widget.existingPlan?.haftaBaslangic ?? weekStart,
          secilenOgunler: generatedPlan.secilenOgunler,
          gunler: nonEmptyDays,
        );
      } else {
        // Gün seçimi yok — üretilen planı direkt kullan
        finalPlan = generatedPlan;
      }

      try {
        debugPrint('FINAL: ${finalPlan.haftaBaslangic}, days=${finalPlan.gunler.length}');
        for (final d in finalPlan.gunler) {
          debugPrint('  ${d.gunAdi} (${d.gun}) - ${d.ogunler.keys.join(",")}');
        }
      } catch (_) {}

      // 4. Yeni üretilen tarifleri cache'e yaz (fire-and-forget)
      cacheService.cacheRecipesFromPlan(finalPlan);

      stopwatch.stop();
      RemoteLoggerService.info(
        'meal_plan_generated',
        screen: 'meal_plan_generation',
        extra: {
          'duration_ms': stopwatch.elapsedMilliseconds,
          'selected_days': affectedDays?.length ?? finalPlan.gunler.length,
        },
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MealPlanPreviewScreen(
            uid: widget.uid,
            preferences: widget.preferences,
            mealPlan: finalPlan,
            returnToHome: widget.returnToHome,
            affectedDayIndices: affectedDays,
          ),
        ),
      );
    } catch (e) {
      stopwatch.stop();
      RemoteLoggerService.error(
        'meal_plan_generation_failed',
        error: e,
        screen: 'meal_plan_generation',
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.returnToHome
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.charcoal.withValues(alpha: 0.5),
                ),
              )
            : null,
        actions: [
          if (!widget.returnToHome)
            IconButton(
              onPressed: () => context.read<AuthService>().signOut(),
              icon: const Icon(Icons.logout_rounded),
              tooltip: l10n.signOut,
              style: IconButton.styleFrom(
                foregroundColor: AppColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading) ...[
                  // Lottie animasyonu
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.manualEntries != null
                        ? l10n.manualPlanEnriching
                        : l10n.mealPlanGeneratingTitle,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.mealPlanGeneratingSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.6),
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Lütfen bu ekranı kapatmayın',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_hasError) ...[
                  // Hata durumu
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.mealPlanGeneratingError,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.4),
                          ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: FilledButton.icon(
                      onPressed: _generate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.mealPlanRetry),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
