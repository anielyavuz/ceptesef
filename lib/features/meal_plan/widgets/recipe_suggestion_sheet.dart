import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/groq_service.dart';
import '../../../core/models/chef_chat_response.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/recipe_cache_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../../core/services/taste_profile_service.dart';
import '../screens/recipe_detail_screen.dart';

/// Yemek önerisi chatbot — konuşma akışlı, mesaj geçmişi korunan.
/// [targetDayIndex] ve [targetSlotKey] verilirse, önerilen tarif doğrudan
/// o slota eklenir (ana ekrandan "Yemek Ekle" akışı).
class RecipeSuggestionSheet extends StatefulWidget {
  final int? targetDayIndex;
  final String? targetSlotKey;
  final String? targetSlotLabel;
  /// 0 = haftalık, 1 = günlük — genel açılışta kullanılır
  final int viewMode;

  const RecipeSuggestionSheet({
    super.key,
    this.targetDayIndex,
    this.targetSlotKey,
    this.targetSlotLabel,
    this.viewMode = 0,
  });

  /// Genel açılış (FAB'dan)
  static Future<bool?> show(BuildContext context, {int viewMode = 0}) {
    // Sheet kapanınca klavyeyi kapat
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeSuggestionSheet(viewMode: viewMode),
    ).whenComplete(() => FocusManager.instance.primaryFocus?.unfocus());
  }

  /// Hedef slot belirli açılış (ana ekrandan "Yemek Ekle")
  static Future<bool?> showForSlot(
    BuildContext context, {
    required int dayIndex,
    required String slotKey,
    required String slotLabel,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeSuggestionSheet(
        targetDayIndex: dayIndex,
        targetSlotKey: slotKey,
        targetSlotLabel: slotLabel,
      ),
    ).whenComplete(() => FocusManager.instance.primaryFocus?.unfocus());
  }

  @override
  State<RecipeSuggestionSheet> createState() => _RecipeSuggestionSheetState();
}

// Chat mesaj tipleri
enum _MsgType { bot, user, recipe, loading, error, quickActions }

class _ChatMessage {
  final _MsgType type;
  final String? text;
  final Recipe? recipe;

  const _ChatMessage({required this.type, this.text, this.recipe});
}

// Hızlı seçenek verileri
class _QuickOption {
  final String emoji;
  final String label;
  const _QuickOption(this.emoji, this.label);
}

final _quickOptions = [
  const _QuickOption('⚡', 'Hızlıca Bir Şeyler'),
  const _QuickOption('🔥', 'Düşük Kalori'),
  const _QuickOption('💪', 'Yüksek Protein'),
  const _QuickOption('🥗', 'Hafif bir salata'),
  const _QuickOption('🍝', 'Makarna'),
  const _QuickOption('🥘', 'Çorba'),
];

final _followUpOptions = [
  const _QuickOption('🔄', 'Başka öner'),
  const _QuickOption('🌶️', 'Daha baharatlı'),
  const _QuickOption('🥬', 'Daha hafif'),
  const _QuickOption('⚡', 'Daha hızlı'),
];

class _RecipeSuggestionSheetState extends State<RecipeSuggestionSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _messages = <_ChatMessage>[];
  final _conversationHistory = <Content>[]; // Gemini ChatSession geçmişi
  bool _isGenerating = false;
  Recipe? _lastRecipe;
  List<String>? _savedRecipeNames; // Kaydedilen tarif isimleri (chatbot farkındalığı)

  bool get _hasTarget =>
      widget.targetDayIndex != null && widget.targetSlotKey != null;

  @override
  void initState() {
    super.initState();
    _loadSavedRecipeNames();
    if (_hasTarget) {
      // Hedef slot var — buna özel açılış mesajı
      _messages.add(_ChatMessage(
        type: _MsgType.bot,
        text:
            '${widget.targetSlotLabel} öğünü için ne eklemek istersiniz? Yazın, size harika bir tarif bulayım! 🍳',
      ));
    } else {
      // Genel açılış
      _messages.add(const _ChatMessage(
        type: _MsgType.bot,
        text: null, // l10n'den çekilecek
      ));
    }
    // Başlangıç hızlı seçenekleri
    _messages.add(const _ChatMessage(type: _MsgType.quickActions));

    // Klavyeyi otomatik aç
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  /// Kaydedilen tarif isimlerini yükle (chatbot farkındalığı için)
  Future<void> _loadSavedRecipeNames() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final firestore = context.read<FirestoreService>();
      final recipes = await firestore.getSavedRecipes(uid);
      _savedRecipeNames = recipes.map((r) => r.yemekAdi).toList();
    } catch (_) {
      // Hata olursa chatbot yine çalışır, sadece tarif isimleri olmadan
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(String text, {bool isFollowUp = false}) async {
    if (text.trim().isEmpty || _isGenerating) return;

    final userText = text.trim();

    // Kullanıcı mesajı ekle
    setState(() {
      _messages.add(_ChatMessage(type: _MsgType.user, text: userText));
      _messages.add(const _ChatMessage(type: _MsgType.loading));
      _isGenerating = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final gemini = context.read<GeminiService>();
      final firestore = context.read<FirestoreService>();
      final cacheService = context.read<RecipeCacheService>();
      final tasteService = context.read<TasteProfileService>();
      final uid = FirebaseAuth.instance.currentUser?.uid;

      UserPreferences prefs = const UserPreferences();
      TasteProfile? tasteProfile;
      if (uid != null) {
        prefs = await firestore.getUserPreferences(uid) ?? prefs;
        tasteProfile = await tasteService.getTasteProfile(uid);
      }

      // Önce Groq dene, rate limit (429) veya hata alırsa Gemini'ye fallback
      final groq = context.read<GroqService>();
      ChefChatResponse response;
      String usedProvider = 'groq';

      try {
        response = await groq.chatWithChef(
          userMessage: userText,
          preferences: prefs,
          tasteProfile: tasteProfile,
          savedRecipeNames: _savedRecipeNames,
        );
        RemoteLoggerService.info('chat_provider_used',
            screen: 'suggestion', extra: {'provider': 'groq'});
      } on GroqApiException catch (e) {
        // Rate limit veya Groq hatası → Gemini fallback
        debugPrint('⚠️ Groq hata (${ e.statusCode}), Gemini fallback...');
        RemoteLoggerService.warning('groq_fallback_to_gemini_${e.statusCode}',
            screen: 'suggestion');
        response = await gemini.chatWithChef(
          userMessage: userText,
          preferences: prefs,
          conversationHistory: _conversationHistory,
          tasteProfile: tasteProfile,
          savedRecipeNames: _savedRecipeNames,
        );
        usedProvider = 'gemini';
      } catch (e) {
        // Groq genel hata (init, network vb.) → Gemini fallback
        debugPrint('⚠️ Groq genel hata, Gemini fallback: $e');
        RemoteLoggerService.warning('groq_fallback_to_gemini_error',
            screen: 'suggestion');
        response = await gemini.chatWithChef(
          userMessage: userText,
          preferences: prefs,
          conversationHistory: _conversationHistory,
          tasteProfile: tasteProfile,
          savedRecipeNames: _savedRecipeNames,
        );
        usedProvider = 'gemini';
      }
      debugPrint('🤖 Chat provider: $usedProvider');

      if (!mounted) return;

      if (response.isRecipe) {
        var recipe = response.recipe!;

        // Kaydedilen tariflerle eşleşme kontrolü
        if (uid != null && _savedRecipeNames != null) {
          final matchName = recipe.yemekAdi.toLowerCase();
          final userReq = userText.toLowerCase();
          final savedMatch = _savedRecipeNames!
              .where((name) => name.toLowerCase() == matchName)
              .firstOrNull;
          if (savedMatch != null) {
            final variations = ['haşlanmış', 'haslama', 'fırında', 'ızgara', 'buğulama',
              'kavurma', 'kızartma', 'tandır', 'güveç', 'sote', 'marine', 'füme'];
            final hasVariation = variations.any((v) => userReq.contains(v) && !matchName.contains(v));
            if (!hasVariation) {
              try {
                final savedRecipes = await firestore.getSavedRecipes(uid);
                final found = savedRecipes.where(
                    (r) => r.yemekAdi.toLowerCase() == matchName).firstOrNull;
                if (found != null) recipe = found;
              } catch (_) {}
            }
          }
        }

        // Cache + arşiv kaydı (fire-and-forget)
        final tempPlan = MealPlan(
          haftaBaslangic: '',
          secilenOgunler: const [],
          gunler: [MealDay(gun: '', gunAdi: '', ogunler: {'temp': [recipe]})],
        );
        cacheService.cacheRecipesFromPlan(tempPlan);
        if (uid != null) {
          firestore.saveRecipeToArchive(uid, recipe);
        }

        RemoteLoggerService.userAction('recipe_suggested',
            screen: 'suggestion', details: {'request': userText});

        setState(() {
          _messages.removeWhere((m) => m.type == _MsgType.loading);
          _messages.add(_ChatMessage(type: _MsgType.bot, text: response.message));
          _messages.add(_ChatMessage(type: _MsgType.recipe, recipe: recipe));
          _messages.add(const _ChatMessage(type: _MsgType.quickActions));
          _lastRecipe = recipe;
          _isGenerating = false;
        });
      } else {
        // Sohbet yanıtı — sadece metin
        RemoteLoggerService.userAction('chef_chat_response',
            screen: 'suggestion', details: {'request': userText});

        setState(() {
          _messages.removeWhere((m) => m.type == _MsgType.loading);
          _messages.add(_ChatMessage(type: _MsgType.bot, text: response.message));
          _isGenerating = false;
        });
      }
      _scrollToBottom();
    } catch (e) {
      RemoteLoggerService.error('chef_chat_failed', error: e);
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.type == _MsgType.loading);
        _messages.add(_ChatMessage(
            type: _MsgType.error, text: 'Bir sorun oluştu, tekrar dener misin?'));
        _isGenerating = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _addToPlan(Recipe recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = context.read<FirestoreService>();
    final l10n = AppLocalizations.of(context);

    // Günlük mod: dayIndex == -1 (hedef belirli) veya genel açılışta viewMode == 1
    final isDailyMode = (_hasTarget && widget.targetDayIndex == -1) ||
        (!_hasTarget && widget.viewMode == 1);

    if (isDailyMode) {
      if (_hasTarget) {
        await _addToDailyPlan(uid, firestore, recipe, l10n);
      } else {
        // Genel açılış + günlük mod: slot seçici göster
        await _addToDailyPlanWithSlotPicker(uid, firestore, recipe, l10n);
      }
      return;
    }

    // Haftalık mod
    final plan = await firestore.getCurrentMealPlan(uid);
    if (plan == null || !mounted) return;

    int dayIndex;
    String slotKey;

    if (_hasTarget) {
      dayIndex = widget.targetDayIndex!;
      slotKey = widget.targetSlotKey!;
    } else {
      final result = await _showDaySlotPicker(context, plan, l10n);
      if (result == null || !mounted) return;
      dayIndex = result.dayIndex;
      slotKey = result.slotKey;
    }
    final existingList = plan.gunler[dayIndex].ogunler[slotKey];

    if (existingList != null && existingList.isNotEmpty) {
      final existingNames = existingList.map((r) => r.yemekAdi).join(', ');
      final action = await _showReplaceDialog(l10n, existingNames);
      if (action == null || action == 'cancel' || !mounted) return;

      final taste = context.read<TasteProfileService>();
      if (action == 'add') {
        await firestore.updateMealSlot(
            uid, plan, dayIndex, slotKey, [...existingList, recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
        RemoteLoggerService.userAction('recipe_appended_to_plan',
            screen: 'suggestion');
      } else {
        for (final r in existingList) {
          taste.logRecipeAction(uid, r, 'replaced');
        }
        await firestore.updateMealSlot(
            uid, plan, dayIndex, slotKey, [recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
        RemoteLoggerService.userAction('recipe_replaced_in_plan',
            screen: 'suggestion');
      }
    } else {
      final taste = context.read<TasteProfileService>();
      await firestore.updateMealSlot(uid, plan, dayIndex, slotKey, [recipe]);
      taste.logRecipeAction(uid, recipe, 'added_to_plan');
      RemoteLoggerService.userAction('recipe_added_to_plan',
          screen: 'suggestion');
    }

    _popWithSnackbar(l10n);
  }

  /// Günlük plana tarif ekle
  Future<void> _addToDailyPlan(
    String uid,
    FirestoreService firestore,
    Recipe recipe,
    AppLocalizations l10n,
  ) async {
    final slotKey = widget.targetSlotKey!;
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
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [...existingList, recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
      } else {
        for (final r in existingList) {
          taste.logRecipeAction(uid, r, 'replaced');
        }
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
      }
    } else {
      await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [recipe]);
      taste.logRecipeAction(uid, recipe, 'added_to_plan');
    }

    RemoteLoggerService.userAction('recipe_added_to_daily',
        screen: 'suggestion', details: {'slot': slotKey});

    if (!mounted) return;
    _popWithSnackbar(l10n);
  }

  /// Genel açılış + günlük mod: slot seçtir ve bugüne ekle
  Future<void> _addToDailyPlanWithSlotPicker(
    String uid,
    FirestoreService firestore,
    Recipe recipe,
    AppLocalizations l10n,
  ) async {
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

    if (!mounted) return;

    // Slot seçici göster
    final slotKey = await _showDailySlotPicker(context, currentDay, l10n);
    if (slotKey == null || !mounted) return;

    final existingList2 = currentDay.ogunler[slotKey];

    if (existingList2 != null && existingList2.isNotEmpty && mounted) {
      final existingNames = existingList2.map((r) => r.yemekAdi).join(', ');
      final action = await _showReplaceDialog(l10n, existingNames);
      if (action == null || action == 'cancel' || !mounted) return;

      if (action == 'add') {
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [...existingList2, recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
      } else {
        for (final r in existingList2) {
          taste.logRecipeAction(uid, r, 'replaced');
        }
        await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [recipe]);
        taste.logRecipeAction(uid, recipe, 'added_to_plan');
      }
    } else {
      await firestore.addDailySlot(uid, todayStr, currentDay, slotKey, [recipe]);
      taste.logRecipeAction(uid, recipe, 'added_to_plan');
    }

    RemoteLoggerService.userAction('recipe_added_to_daily',
        screen: 'suggestion', details: {'slot': slotKey});

    if (!mounted) return;
    _popWithSnackbar(l10n);
  }

  /// Günlük mod slot seçici — sadece öğün seçtir
  Future<String?> _showDailySlotPicker(
      BuildContext context, MealDay currentDay, AppLocalizations l10n) {
    final now = DateTime.now();
    final hour = now.hour;

    // Varsayılan slotları belirle
    final availableSlots = ['kahvalti', 'ogle', 'aksam', 'ara_ogun'];
    var defaultSlot = 'ogle';
    if (hour < 10) {
      defaultSlot = 'kahvalti';
    } else if (hour < 15) {
      defaultSlot = 'ogle';
    } else {
      defaultSlot = 'aksam';
    }
    var selectedSlot = defaultSlot;

    String slotLabel(String slot) {
      switch (slot.replaceAll(RegExp(r'_\d+$'), '')) {
        case 'kahvalti': return l10n.slotKahvalti;
        case 'ogle': return l10n.slotOgle;
        case 'aksam': return l10n.slotAksam;
        case 'ara_ogun': return l10n.slotAraOgun;
        default: return slot;
      }
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(l10n.suggestPickSlot,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: availableSlots
                      .map((s) => ChoiceChip(
                            label: Text(slotLabel(s)),
                            selected: selectedSlot == s,
                            onSelected: (_) => setS(() => selectedSlot = s),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                                color: selectedSlot == s
                                    ? Colors.white
                                    : AppColors.charcoal),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, selectedSlot),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l10n.suggestAddToPlan),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Değiştir / Ekleme Yap dialogu
  Future<String?> _showReplaceDialog(
      AppLocalizations l10n, String existingName) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.suggestReplaceConfirm,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
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
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.suggestAddAlongside,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'replace'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(l10n.suggestReplace,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                style: TextButton.styleFrom(
                  foregroundColor:
                      AppColors.charcoal.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 8),
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

  void _popWithSnackbar(AppLocalizations l10n) {
    if (!mounted) return;
    // Klavyeyi kapat
    FocusManager.instance.primaryFocus?.unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final addedText = l10n.suggestAdded;
    Navigator.pop(context, true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(addedText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, dragController) {
        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(context, l10n),
              // Chat mesajları
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    switch (msg.type) {
                      case _MsgType.bot:
                        return _BotBubble(
                            text: msg.text ?? l10n.suggestDefault);
                      case _MsgType.user:
                        return _UserBubble(text: msg.text ?? '');
                      case _MsgType.recipe:
                        return _RecipeCard(
                          recipe: msg.recipe!,
                          l10n: l10n,
                          addLabel: _hasTarget
                              ? 'Bu Öğüne Ekle'
                              : l10n.suggestAddToPlan,
                          onTap: () =>
                              RecipeDetailScreen.open(context, msg.recipe!),
                          onAddToPlan: () => _addToPlan(msg.recipe!),
                        );
                      case _MsgType.loading:
                        return const _LoadingBubble();
                      case _MsgType.error:
                        return _ErrorBubble(text: msg.text ?? '');
                      case _MsgType.quickActions:
                        final isFollowUp = _lastRecipe != null;
                        return _QuickActions(
                          options: isFollowUp
                              ? _followUpOptions
                              : _quickOptions,
                          onSelected: (label) =>
                              _send(label, isFollowUp: isFollowUp),
                        );
                    }
                  },
                ),
              ),
              // Input bar
              _buildInputBar(context, l10n),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Container(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/system/aiAgentIcon.png',
                    width: 36, height: 36, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Text(
                l10n.suggestTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(_controller.text),
              decoration: InputDecoration(
                hintText: l10n.suggestHint,
                hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                    fontSize: 14),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: _isGenerating ? null : () => _send(_controller.text),
              icon: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            ),
          ),
        ],
      ),
    );
  }

  // Day/Slot picker (önceki mantık korunuyor)
  Future<_DaySlotResult?> _showDaySlotPicker(
      BuildContext context, MealPlan plan, AppLocalizations l10n) async {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    var defaultDayIndex = 0;
    for (var i = 0; i < plan.gunler.length; i++) {
      if (plan.gunler[i].gun.compareTo(todayStr) >= 0) {
        defaultDayIndex = i;
        break;
      }
    }
    final defaultSlots =
        plan.gunler[defaultDayIndex].ogunler.keys.toList();
    var defaultSlot = defaultSlots.isNotEmpty ? defaultSlots.first : 'ogle';
    final hour = now.hour;
    if (hour < 10 && defaultSlots.contains('kahvalti')) {
      defaultSlot = 'kahvalti';
    } else if (hour < 15 && defaultSlots.contains('ogle')) {
      defaultSlot = 'ogle';
    } else if (defaultSlots.contains('aksam')) {
      defaultSlot = 'aksam';
    }

    int selectedDay = defaultDayIndex;
    String selectedSlot = defaultSlot;

    String slotLabel(String slot) {
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
        default:
          return slot;
      }
    }

    return showModalBottomSheet<_DaySlotResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final slots = plan.gunler[selectedDay].ogunler.keys.toList();
          return Container(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(l10n.suggestPickDay,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: plan.gunler.length,
                    itemBuilder: (_, i) {
                      final isSel = selectedDay == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(plan.gunler[i].gunAdi.length > 3
                              ? plan.gunler[i].gunAdi.substring(0, 3)
                              : plan.gunler[i].gunAdi),
                          selected: isSel,
                          onSelected: (_) => setS(() {
                            selectedDay = i;
                            final s =
                                plan.gunler[i].ogunler.keys.toList();
                            if (!s.contains(selectedSlot) &&
                                s.isNotEmpty) {
                              selectedSlot = s.first;
                            }
                          }),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                              color:
                                  isSel ? Colors.white : AppColors.charcoal),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.suggestPickSlot,
                    style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: slots
                      .map((s) => ChoiceChip(
                            label: Text(slotLabel(s)),
                            selected: selectedSlot == s,
                            onSelected: (_) =>
                                setS(() => selectedSlot = s),
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                                color: selectedSlot == s
                                    ? Colors.white
                                    : AppColors.charcoal),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                        ctx, _DaySlotResult(selectedDay, selectedSlot)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(l10n.suggestAddToPlan),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Chat bubble widget'ları ───

class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Image.asset('assets/system/aiAgentIcon.png',
                width: 22, height: 22, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                text,
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.charcoal,
                      height: 1.4,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 48),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  height: 1.4,
                ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset('assets/system/aiAgentIcon.png',
                width: 22, height: 22, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Lottie.asset(
                'assets/animations/lottie/loading.json',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  final String text;
  const _ErrorBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('😔', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(text,
                  style: TextStyle(color: Colors.red.shade700, height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final AppLocalizations l10n;
  final String? addLabel;
  final VoidCallback onTap;
  final VoidCallback onAddToPlan;

  const _RecipeCard({
    required this.recipe,
    required this.l10n,
    this.addLabel,
    required this.onTap,
    required this.onAddToPlan,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.yemekAdi,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (recipe.kalori > 0) ...[
                    Icon(Icons.local_fire_department_rounded,
                        size: 13, color: const Color(0xFFE65100)),
                    const SizedBox(width: 3),
                    Text('${recipe.kalori}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFE65100),
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 10),
                  ],
                  if (recipe.toplamSureDk > 0) ...[
                    Icon(Icons.schedule_rounded,
                        size: 13,
                        color: AppColors.charcoal.withValues(alpha: 0.4)),
                    const SizedBox(width: 3),
                    Text(l10n.mealPlanMinutes(recipe.toplamSureDk),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                AppColors.charcoal.withValues(alpha: 0.5))),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    '${recipe.malzemeler.length} malzeme',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                              color:
                                  AppColors.primary.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Text('Tarife Bak',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: onAddToPlan,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(addLabel ?? l10n.suggestAddToPlan,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final List<_QuickOption> options;
  final ValueChanged<String> onSelected;

  const _QuickActions({required this.options, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: options.length,
          itemBuilder: (_, i) {
            final opt = options[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: Text(opt.emoji, style: const TextStyle(fontSize: 14)),
                label: Text(opt.label),
                onPressed: () => onSelected(opt.label),
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                labelStyle:
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.charcoal,
                          fontWeight: FontWeight.w500,
                        ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DaySlotResult {
  final int dayIndex;
  final String slotKey;
  const _DaySlotResult(this.dayIndex, this.slotKey);
}
