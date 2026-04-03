import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/groq_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../auth/auth_wrapper.dart';
import '../../home/screens/home_screen.dart';
import 'recipe_detail_screen.dart';

/// Gemini'dan dönen haftalık yemek planını ön izleme ekranı.
/// 7 gün tab'lı görünüm + onayla/yeniden oluştur.
class MealPlanPreviewScreen extends StatefulWidget {
  final String uid;
  final UserPreferences preferences;
  final MealPlan mealPlan;
  final bool returnToHome;
  final List<int>? affectedDayIndices; // Değişen günlerin indeksleri (null = tümü)

  const MealPlanPreviewScreen({
    super.key,
    required this.uid,
    required this.preferences,
    required this.mealPlan,
    this.returnToHome = false,
    this.affectedDayIndices,
  });

  @override
  State<MealPlanPreviewScreen> createState() => _MealPlanPreviewScreenState();
}

class _MealPlanPreviewScreenState extends State<MealPlanPreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late MealPlan _mealPlan;
  bool _isSaving = false;
  int? _regeneratingDay; // hangi gün yenileniyor (index)
  String? _replacingRecipeKey; // hangi tarif değiştiriliyor ("dayIdx-slotKey-recipeIdx")

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('meal_plan_preview');
    RemoteLoggerService.info('meal_plan_preview_opened',
        screen: 'meal_plan_preview');
    _mealPlan = widget.mealPlan;

    // İlk tab'ı yeni eklenen/değiştirilen güne ayarla
    int initialTab = 0;
    if (widget.affectedDayIndices != null && widget.affectedDayIndices!.isNotEmpty) {
      // affectedDayIndices haftalık indeks (0=Pzt, 4=Cum vs.)
      // Plan'daki günlerle eşleştir
      final firstAffectedIdx = widget.affectedDayIndices!.first;
      const gunAdlari = ['Pazartesi', 'Sali', 'Carsamba', 'Persembe', 'Cuma', 'Cumartesi', 'Pazar'];
      final targetGunAdi = gunAdlari[firstAffectedIdx % 7];
      for (var i = 0; i < _mealPlan.gunler.length; i++) {
        if (_mealPlan.gunler[i].gunAdi == targetGunAdi) {
          initialTab = i;
          break;
        }
      }
    }

    _tabController = TabController(
      length: _mealPlan.gunler.length,
      initialIndex: initialTab,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmPlan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final firestore = context.read<FirestoreService>();

      // Gelecek hafta planı oluşturuluyorsa mevcut günleri korur (ezmez)
      final now = DateTime.now();
      final daysFromMonday = (now.weekday - DateTime.monday) % 7;
      final thisMonday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysFromMonday));
      final nextMonday = thisMonday.add(const Duration(days: 7));
      final nextMondayStr =
          '${nextMonday.year}-${nextMonday.month.toString().padLeft(2, '0')}-${nextMonday.day.toString().padLeft(2, '0')}';
      final isFutureWeek =
          _mealPlan.haftaBaslangic.compareTo(nextMondayStr) >= 0;

      MealPlan planToSave = _mealPlan;
      if (isFutureWeek) {
        final existing = await firestore.getMealPlanByWeekStart(
            widget.uid, _mealPlan.haftaBaslangic);
        if (existing != null && existing.gunler.isNotEmpty) {
          final existingMap = {for (final d in existing.gunler) d.gun: d};
          final mergedDays = _mealPlan.gunler.map((newDay) {
            return existingMap[newDay.gun] ?? newDay;
          }).toList();
          planToSave = _mealPlan.copyWith(gunler: mergedDays);
        }
      }

      await firestore.saveMealPlan(widget.uid, planToSave);

      RemoteLoggerService.userAction('meal_plan_confirmed',
          screen: 'meal_plan_preview');

      if (!mounted) return;

      if (widget.returnToHome) {
        // Cache'i temizle ki home yükleyince taze veri gelsin
        firestore.invalidateMealPlanCache();
        // Önce geri dön, sonra home'u refresh et
        Navigator.of(context).popUntil((route) => route.isFirst);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          HomeScreen.globalKey.currentState?.refreshMealPlan();
        });
      } else {
        // Onboarding'den geldiyse AuthWrapper'a git
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      RemoteLoggerService.error('meal_plan_save_failed',
          error: e, screen: 'meal_plan_preview');
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorGeneral)),
      );
    }
  }

  /// Yeniden oluştur — opsiyonel kullanıcı isteği ile bottom sheet
  void _showRegenerateSheet(int dayIndex) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(l10n.mealPlanRegenerate,
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Neler daha iyi olsun istersiniz? (opsiyonel)',
                  hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
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
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    Navigator.pop(ctx);
                    _regenerateDay(
                      dayIndex,
                      customInstruction: text.isEmpty ? null : text,
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(l10n.mealPlanRegenerate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _regenerateDay(int dayIndex, {String? customInstruction}) async {
    if (_regeneratingDay != null) return;
    setState(() => _regeneratingDay = dayIndex);

    try {
      final currentDay = _mealPlan.gunler[dayIndex];

      // Diğer günlerdeki tarif adlarını topla (tekrar önleme)
      final otherRecipeNames = <String>[];
      for (var i = 0; i < _mealPlan.gunler.length; i++) {
        if (i == dayIndex) continue;
        for (final recipe in _mealPlan.gunler[i].tumTarifler) {
          otherRecipeNames.add(recipe.yemekAdi);
        }
      }

      final groqService = context.read<GroqService>();
      final geminiService = context.read<GeminiService>();

      MealDay newDay;
      try {
        // Önce Groq dene (hızlı)
        newDay = await groqService.regenerateDay(
          widget.preferences,
          currentDay,
          otherRecipeNames,
          customInstruction: customInstruction,
        );
        RemoteLoggerService.info('regenerate_day_groq_success',
            screen: 'meal_plan_preview');
      } on GroqApiException {
        // Groq başarısız → Gemini fallback
        RemoteLoggerService.info('regenerate_day_groq_fallback_to_gemini',
            screen: 'meal_plan_preview');
        newDay = await geminiService.regenerateDay(
          widget.preferences,
          currentDay,
          otherRecipeNames,
          customInstruction: customInstruction,
        );
      }

      RemoteLoggerService.userAction(
        'meal_plan_day_regenerated',
        screen: 'meal_plan_preview',
        details: {'day': currentDay.gunAdi},
      );

      if (!mounted) return;

      // Günü değiştir
      final updatedGunler = List<MealDay>.from(_mealPlan.gunler);
      updatedGunler[dayIndex] = newDay;
      setState(() {
        _mealPlan = MealPlan(
          haftaBaslangic: _mealPlan.haftaBaslangic,
          secilenOgunler: _mealPlan.secilenOgunler,
          gunler: updatedGunler,
        );
        _regeneratingDay = null;
      });
    } catch (e) {
      RemoteLoggerService.error('meal_plan_day_regenerate_failed',
          error: e, screen: 'meal_plan_preview');
      if (!mounted) return;
      setState(() => _regeneratingDay = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorGeneral)),
      );
    }
  }

  /// Tek bir tarifi değiştir — bottom sheet ile opsiyonel istek al
  void _showChangeRecipeSheet(int dayIndex, String slotKey, int recipeIndex) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final recipe = _mealPlan.gunler[dayIndex].ogunler[slotKey]![recipeIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '${recipe.yemekAdi} yerine...',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.mealPlanChangeRecipeHint,
                  hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
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
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    Navigator.pop(ctx);
                    _changeRecipe(
                      dayIndex, slotKey, recipeIndex,
                      customInstruction: text.isEmpty ? null : text,
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: Text(l10n.mealPlanChangeRecipe),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeRecipe(
    int dayIndex, String slotKey, int recipeIndex, {
    String? customInstruction,
  }) async {
    final key = '$dayIndex-$slotKey-$recipeIndex';
    if (_replacingRecipeKey != null) return;
    setState(() => _replacingRecipeKey = key);

    try {
      final currentRecipe = _mealPlan.gunler[dayIndex].ogunler[slotKey]![recipeIndex];

      // Plandaki diğer tarif adlarını topla (tekrar önleme)
      final otherNames = <String>[];
      for (final day in _mealPlan.gunler) {
        for (final recipes in day.ogunler.values) {
          for (final r in recipes) {
            if (r.yemekAdi != currentRecipe.yemekAdi) {
              otherNames.add(r.yemekAdi);
            }
          }
        }
      }

      final l10n = AppLocalizations.of(context);
      final groqSvc = context.read<GroqService>();
      final geminiSvc = context.read<GeminiService>();

      final slotLabel = _slotLabel(slotKey, l10n);
      final request = StringBuffer();
      request.write('$slotLabel için "${currentRecipe.yemekAdi}" yerine farklı bir tarif öner.');
      request.write(' Şu tarifleri önerme (zaten planda var): ${otherNames.join(", ")}.');
      if (customInstruction != null) {
        request.write(' Kullanıcı isteği: $customInstruction');
      }

      Recipe newRecipe;
      try {
        newRecipe = await groqSvc.suggestRecipe(
          userRequest: request.toString(),
          preferences: widget.preferences,
        );
        RemoteLoggerService.info('suggest_recipe_groq_success',
            screen: 'meal_plan_preview');
      } on GroqApiException {
        RemoteLoggerService.info('suggest_recipe_groq_fallback_to_gemini',
            screen: 'meal_plan_preview');
        newRecipe = await geminiSvc.suggestRecipe(
          userRequest: request.toString(),
          preferences: widget.preferences,
        );
      }

      RemoteLoggerService.userAction(
        'recipe_changed_in_preview',
        screen: 'meal_plan_preview',
        details: {
          'old': currentRecipe.yemekAdi,
          'new': newRecipe.yemekAdi,
          'slot': slotKey,
        },
      );

      if (!mounted) return;

      // Tarifi değiştir
      final updatedGunler = List<MealDay>.from(_mealPlan.gunler);
      final updatedOgunler = Map<String, List<Recipe>>.from(
        updatedGunler[dayIndex].ogunler.map(
          (k, v) => MapEntry(k, List<Recipe>.from(v)),
        ),
      );
      updatedOgunler[slotKey]![recipeIndex] = newRecipe;
      updatedGunler[dayIndex] = MealDay(
        gun: updatedGunler[dayIndex].gun,
        gunAdi: updatedGunler[dayIndex].gunAdi,
        ogunler: updatedOgunler,
      );

      setState(() {
        _mealPlan = MealPlan(
          haftaBaslangic: _mealPlan.haftaBaslangic,
          secilenOgunler: _mealPlan.secilenOgunler,
          gunler: updatedGunler,
        );
        _replacingRecipeKey = null;
      });
    } catch (e) {
      RemoteLoggerService.error('recipe_change_failed',
          error: e, screen: 'meal_plan_preview');
      if (!mounted) return;
      setState(() => _replacingRecipeKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).errorGeneral)),
      );
    }
  }

  String _slotLabel(String slot, AppLocalizations l10n) {
    switch (slot) {
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
        return l10n.slotAnaOgun;
      default:
        return slot;
    }
  }

  IconData _slotIcon(String slot) {
    switch (slot) {
      case 'kahvalti':
        return Icons.wb_sunny_rounded;
      case 'ogle':
        return Icons.light_mode_rounded;
      case 'aksam':
        return Icons.nightlight_round;
      case 'ara_ogun_1':
      case 'ara_ogun_2':
      case 'ara_ogun':
        return Icons.coffee_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  static String _shortDayName(String gunAdi) {
    const kisaltmalar = {
      'Pazartesi': 'Pzt',
      'Sali': 'Sal',
      'Salı': 'Sal',
      'Carsamba': 'Çar',
      'Çarşamba': 'Çar',
      'Persembe': 'Per',
      'Perşembe': 'Per',
      'Cuma': 'Cum',
      'Cumartesi': 'Cmt',
      'Pazar': 'Paz',
    };
    return kisaltmalar[gunAdi] ?? (gunAdi.length > 3 ? gunAdi.substring(0, 3) : gunAdi);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.cancel,
          style: IconButton.styleFrom(
            foregroundColor: AppColors.charcoal,
          ),
        ),
        title: Text(
          l10n.mealPlanPreviewTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          // Gün tab'ları
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.charcoal.withValues(alpha: 0.6),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              unselectedLabelStyle:
                  Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              padding: const EdgeInsets.all(4),
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              dividerHeight: 0,
              tabs: _mealPlan.gunler.asMap().entries.map((entry) {
                final idx = entry.key;
                final day = entry.value;
                final isAffected = widget.affectedDayIndices == null ||
                    widget.affectedDayIndices!.contains(idx);
                final isRegenerating = _regeneratingDay == idx;
                final label = _shortDayName(day.gunAdi);
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAffected && widget.affectedDayIndices != null) ...[
                        Container(
                          width: 6, height: 6,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      Text(label),
                      if (!isRegenerating) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _showRegenerateSheet(idx),
                          child: Icon(
                            Icons.refresh_rounded,
                            size: 14,
                            color: _tabController.index == idx
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.primary.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                      if (isRegenerating) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _tabController.index == idx
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Öğün içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_mealPlan.gunler.length, (i) {
                return _buildDayView(context, _mealPlan.gunler[i], i, l10n);
              }),
            ),
          ),
          // Alt buton
          Container(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomPadding + 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _confirmPlan,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.mealPlanConfirm,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(
      BuildContext context, MealDay day, int dayIndex, AppLocalizations l10n) {
    final slots = day.ogunler.entries.toList();
    final isRegenerating = _regeneratingDay == dayIndex;

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          itemCount: slots.length,
          itemBuilder: (context, index) {
        final slot = slots[index];
        final recipes = slot.value;
        final slotName = _slotLabel(slot.key, l10n);
        final slotIcon = _slotIcon(slot.key);
        final totalKalori = recipes.fold(0, (s, r) => s + r.kalori);
        final totalSure = recipes.fold(0, (s, r) => s + r.toplamSureDk);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst: slot label + toplam kalori + toplam süre
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(slotIcon, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          slotName,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (totalKalori > 0) ...[
                    Icon(Icons.local_fire_department_rounded,
                        size: 14, color: const Color(0xFFE65100)),
                    const SizedBox(width: 3),
                    Text(
                      '$totalKalori kcal',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFE65100),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (totalSure > 0)
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14,
                            color: AppColors.charcoal.withValues(alpha: 0.4)),
                        const SizedBox(width: 3),
                        Text(
                          l10n.mealPlanMinutes(totalSure),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.5),
                                  ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Her tarif ayrı satır
              ...List.generate(recipes.length, (ri) {
                final recipe = recipes[ri];
                final recipeKey = '$dayIndex-${slot.key}-$ri';
                final isReplacing = _replacingRecipeKey == recipeKey;
                return Padding(
                  padding: EdgeInsets.only(top: ri > 0 ? 10 : 0),
                  child: GestureDetector(
                    onTap: () => RecipeDetailScreen.open(context, recipe),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ri > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Divider(
                              height: 1,
                              color: AppColors.border.withValues(alpha: 0.4),
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                recipes.length > 1
                                    ? '${ri + 1}. ${recipe.yemekAdi}'
                                    : recipe.yemekAdi,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.charcoal,
                                    ),
                              ),
                            ),
                            if (isReplacing)
                              const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              GestureDetector(
                                onTap: () => _showChangeRecipeSheet(
                                    dayIndex, slot.key, ri),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.swap_horiz_rounded,
                                          size: 14, color: AppColors.accent),
                                      const SizedBox(width: 3),
                                      Text(
                                        l10n.mealPlanChangeRecipe,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AppColors.accent,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _InfoChip(
                              icon: Icons.signal_cellular_alt_rounded,
                              label: recipe.zorluk,
                              color: _difficultyColor(recipe.zorluk),
                            ),
                            _InfoChip(
                              icon: Icons.people_outline_rounded,
                              label: l10n.mealPlanServings(recipe.kisiSayisi),
                              color: AppColors.charcoal.withValues(alpha: 0.5),
                            ),
                            ...recipe.mutfaklar.take(2).map(
                                  (m) => _InfoChip(
                                    icon: Icons.restaurant_rounded,
                                    label: m,
                                    color: AppColors.primary,
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
        ),
        // Lottie loading overlay
        if (isRegenerating)
          Positioned.fill(
            child: Container(
              color: Colors.white.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Lottie.asset(
                      'assets/animations/lottie/loading.json',
                      width: 120,
                      height: 120,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loading,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
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
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
