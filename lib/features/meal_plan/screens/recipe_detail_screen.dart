import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/constants/cuisine_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/taste_profile_service.dart';
import '../../../core/services/remote_logger_service.dart';

/// Tarif detay ekranı — Stitch tasarımına uygun full-page görünüm.
/// Hero gradient, stat kartları, checkbox'lı malzeme, numaralı adımlar.
class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  final bool fromSaved;
  final int? initialRating;

  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.fromSaved = false,
    this.initialRating,
  });

  static void open(BuildContext context, Recipe recipe, {bool fromSaved = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe, fromSaved: fromSaved),
      ),
    );
  }

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late List<bool> _checkedIngredients;
  late List<bool> _checkedSteps;
  late DateTime _openedAt;
  bool _cookLogged = false;
  int? _currentRating;
  bool _isSaved = false;

  // Etiketler
  List<RecipeTag> _allTags = [];
  List<String> _recipeTags = [];

  @override
  void initState() {
    super.initState();
    _checkedIngredients =
        List.filled(widget.recipe.malzemeler.length, false);
    _checkedSteps =
        List.filled(widget.recipe.yapilis.length, false);
    _openedAt = DateTime.now();
    _currentRating = widget.initialRating;
    _recipeTags = List<String>.from(widget.recipe.tags);
    RemoteLoggerService.setScreen('recipe_detail');
    // Tarif ekranında ekran kapanmasın
    WakelockPlus.enable();
    if (widget.fromSaved) _loadTags();
  }

  Future<void> _loadTags() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final firestore = context.read<FirestoreService>();
      final tags = await firestore.getRecipeTags(user.uid);
      if (mounted) setState(() => _allTags = tags);
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _logViewInteraction();
    super.dispose();
  }

  void _logViewInteraction() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final seconds = DateTime.now().difference(_openedAt).inSeconds;
    if (seconds < 2) return; // çok kısa görüntülemeler kaydetme
    context.read<TasteProfileService>().logRecipeAction(
          uid,
          widget.recipe,
          'viewed',
          timeSpentSeconds: seconds,
        );
  }

  Future<void> _deleteSavedRecipe(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.savedDeleteSingleTitle),
        content: Text(l10n.savedDeleteSingleMessage),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.savedDeleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docId = widget.recipe.id.isNotEmpty
        ? widget.recipe.id
        : widget.recipe.yemekAdi;

    try {
      await context.read<FirestoreService>().deleteSavedRecipe(uid, docId);
      if (!mounted) return;
      Navigator.pop(context, true); // true = silindi
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.savedDeleteSuccess(1)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      RemoteLoggerService.userAction('saved_recipe_deleted_from_detail',
          screen: 'recipe_detail');
    } catch (e) {
      RemoteLoggerService.error('saved_recipe_delete_failed',
          error: e, screen: 'recipe_detail');
    }
  }

  Future<void> _saveRecipeToArchive(AppLocalizations l10n) async {
    if (_isSaved) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recipeAlreadySaved),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final firestore = context.read<FirestoreService>();
      final tasteService = context.read<TasteProfileService>();

      await firestore.saveRecipeToArchive(uid, widget.recipe);
      tasteService.logRecipeAction(uid, widget.recipe, 'saved');

      if (!mounted) return;
      setState(() => _isSaved = true);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recipeSavedSuccess),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );

      RemoteLoggerService.userAction('recipe_saved_from_detail',
          screen: 'recipe_detail',
          details: {'recipe': widget.recipe.yemekAdi});
    } catch (e) {
      RemoteLoggerService.error('recipe_save_failed',
          error: e, screen: 'recipe_detail');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.errorGeneral)),
      );
    }
  }

  void _checkCookCompletion() {
    if (_cookLogged) return;
    final totalIng = _checkedIngredients.length;
    final totalSteps = _checkedSteps.length;
    if (totalIng == 0 && totalSteps == 0) return;
    final checkedIng = _checkedIngredients.where((c) => c).length;
    final checkedSteps = _checkedSteps.where((c) => c).length;
    // Malzemelerin %80+ VE adımların tamamı yapılmışsa "pişirildi" say
    final ingDone = totalIng == 0 || checkedIng == totalIng || (totalIng >= 4 && checkedIng / totalIng >= 0.8);
    final stepsDone = totalSteps == 0 || checkedSteps == totalSteps;
    if (ingDone && stepsDone) {
      _cookLogged = true;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      context
          .read<TasteProfileService>()
          .logRecipeAction(uid, widget.recipe, 'cooked');
    }
  }

  void _rateFromDetail(Recipe recipe, int rating) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _currentRating = _currentRating == rating ? null : rating);

    if (_currentRating != null) {
      context
          .read<TasteProfileService>()
          .logRecipeAction(uid, recipe, 'rated', rating: _currentRating!);

      RemoteLoggerService.userAction('recipe_rated',
          screen: 'recipe_detail',
          details: {'recipe': recipe.yemekAdi, 'rating': _currentRating});
    }
  }

  Widget _buildRatingBar(Recipe recipe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          _buildRatingButton(
            emoji: '\u{1F60D}',
            label: 'Bayıldım',
            isSelected: _currentRating == 3,
            color: const Color(0xFFE91E63),
            onTap: () => _rateFromDetail(recipe, 3),
          ),
          const SizedBox(width: 8),
          _buildRatingButton(
            emoji: '\u{1F44D}',
            label: 'Güzel',
            isSelected: _currentRating == 2,
            color: AppColors.primary,
            onTap: () => _rateFromDetail(recipe, 2),
          ),
          const SizedBox(width: 8),
          _buildRatingButton(
            emoji: '\u{1F44E}',
            label: 'Değil',
            isSelected: _currentRating == 1,
            color: const Color(0xFF9E9E9E),
            onTap: () => _rateFromDetail(recipe, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required String emoji,
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : AppColors.charcoal.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final recipe = widget.recipe;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kaydet butonu (kaydedilenlerden açılmadıysa göster)
          if (!widget.fromSaved)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FloatingActionButton.extended(
                heroTag: 'save',
                onPressed: () => _saveRecipeToArchive(l10n),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                elevation: 3,
                icon: Icon(
                  _isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 20,
                ),
                label: Text(l10n.saveRecipeButton),
              ),
            ),
          // Plana Ekle butonu
          FloatingActionButton.extended(
            heroTag: 'addToPlan',
            onPressed: () => _showAddToPlanSheet(l10n),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.calendar_month_rounded, size: 20),
            label: Text(l10n.addToPlan),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Hero app bar
          SliverAppBar(
            expandedHeight: recipe.imageBase64 != null ? 280 : 220,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
              ),
            ),
            actions: [
              if (widget.fromSaved)
                IconButton(
                  onPressed: () => _deleteSavedRecipe(l10n),
                  icon: const Icon(Icons.delete_outline_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: recipe.imageBase64 != null
                  ? _buildImageHero(context, recipe)
                  : _buildGradientHero(context, recipe),
            ),
          ),

          // İçerik
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Rating bar (sadece initialRating varsa goster)
                      if (widget.initialRating != null)
                        _buildRatingBar(recipe),

                      // Stat kartları
                      _buildStatCards(context, recipe, l10n),
                      const SizedBox(height: 28),

                      // Malzemeler
                      if (recipe.malzemeler.isNotEmpty) ...[
                        _buildSectionTitle(
                          context,
                          icon: Icons.shopping_basket_rounded,
                          title: 'Malzemeler',
                          trailing:
                              '${_checkedIngredients.where((c) => c).length}/${recipe.malzemeler.length}',
                        ),
                        const SizedBox(height: 14),
                        _buildIngredients(context, recipe),
                        const SizedBox(height: 28),
                      ],

                      // Yapılış
                      if (recipe.yapilis.isNotEmpty) ...[
                        _buildSectionTitle(
                          context,
                          icon: Icons.menu_book_rounded,
                          title: 'Yapılış',
                          trailing:
                              '${_checkedSteps.where((c) => c).length}/${recipe.yapilis.length}',
                        ),
                        const SizedBox(height: 14),
                        _buildSteps(context, recipe),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Görsel varsa: fotoğraf arka plan + gradient overlay + metin
  Widget _buildImageHero(BuildContext context, Recipe recipe) {
    final imageBytes = base64Decode(recipe.imageBase64!);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildGradientHero(context, recipe),
        ),
        // Alt gradient overlay — metin okunabilirliği için
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.7),
                ],
                stops: const [0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        // İçerik
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBadgeRow(context, recipe, 0.25),
              Text(
                recipe.yemekAdi,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Görsel yoksa: gradient arka plan + dekoratif daireler
  Widget _buildGradientHero(BuildContext context, Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
            const Color(0xFF1B5E20),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBadgeRow(context, recipe, 0.2),
                Text(
                  recipe.yemekAdi,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mutfak badge'leri (sol) + Etiket badge'leri (sağ)
  Widget _buildBadgeRow(BuildContext context, Recipe recipe, double bgAlpha) {
    final hasCuisine = recipe.mutfaklar.isNotEmpty;
    final tagWidgets = _allTags
        .where((t) => _recipeTags.contains(t.id))
        .toList();
    final hasTags = tagWidgets.isNotEmpty;
    final showTags = widget.fromSaved;

    if (!hasCuisine && !showTags) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Sol: Mutfak badge'leri
          if (hasCuisine)
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: recipe.mutfaklar.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: bgAlpha),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      CuisineLabels.label(m),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (!hasCuisine) const Spacer(),
          // Sağ: Etiket badge'leri + ekle butonu
          if (showTags)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...tagWidgets.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tag.color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag.name,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                )),
                // + butonu
                GestureDetector(
                  onTap: _showTagSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: bgAlpha),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_outline_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          hasTags ? '+' : AppLocalizations.of(context).tagEditRecipe,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Etiket atama bottom sheet
  static const _tagColorOptions = [
    0xFF48A14D, // Yeşil
    0xFFE97451, // Coral
    0xFFF4B942, // Amber
    0xFF1565C0, // Mavi
    0xFF6A1B9A, // Mor
    0xFFE65100, // Turuncu
    0xFFD32F2F, // Kırmızı
    0xFF00897B, // Teal
    0xFF5C6BC0, // İndigo
    0xFF8D6E63, // Kahve
  ];

  void _showTagSheet() {
    final l10n = AppLocalizations.of(context);
    final docId = widget.recipe.id.isNotEmpty
        ? widget.recipe.id
        : widget.recipe.yemekAdi;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final selected = Set<String>.from(_recipeTags);
        final nameController = TextEditingController();
        var selectedColor = _tagColorOptions[0];
        var localTags = List<RecipeTag>.from(_allTags);

        return StatefulBuilder(
          builder: (ctx, setSheetState) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.charcoal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    l10n.tagEditRecipe,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // ─── Yeni etiket oluşturma alanı ───
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            hintText: l10n.tagName,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppColors.primary),
                            ),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) return;
                          final firestore = context.read<FirestoreService>();
                          final id = await firestore.createRecipeTag(
                              user.uid, name, selectedColor);
                          final newTag = RecipeTag(
                              id: id, name: name, colorValue: selectedColor);
                          setSheetState(() {
                            localTags.add(newTag);
                            selected.add(id);
                          });
                          // Ana state'i de güncelle
                          setState(() => _allTags = List.from(localTags));
                          nameController.clear();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.tagAdd,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Renk seçici
                  SizedBox(
                    height: 28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _tagColorOptions.length,
                      itemBuilder: (_, i) {
                        final c = _tagColorOptions[i];
                        final isActive = c == selectedColor;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedColor = c),
                          child: Container(
                            width: 24,
                            height: 24,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Color(c),
                              shape: BoxShape.circle,
                              border: isActive
                                  ? Border.all(
                                      color: AppColors.charcoal, width: 2.5)
                                  : null,
                            ),
                            child: isActive
                                ? const Icon(Icons.check_rounded,
                                    size: 12, color: Colors.white)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(),
                  const SizedBox(height: 10),

                  // ─── Mevcut etiketler ───
                  if (localTags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        l10n.tagEmpty,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.charcoal.withValues(alpha: 0.4),
                            ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: localTags.map((tag) {
                        final isActive = selected.contains(tag.id);
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              if (isActive) {
                                selected.remove(tag.id);
                              } else {
                                selected.add(tag.id);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? tag.color
                                  : tag.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? tag.color
                                    : tag.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isActive)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 6),
                                    child: Icon(Icons.check_rounded,
                                        size: 14, color: Colors.white),
                                  ),
                                Text(
                                  tag.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: isActive
                                            ? Colors.white
                                            : tag.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        final firestore = context.read<FirestoreService>();
                        await firestore.updateRecipeTags(
                            user.uid, docId, selected.toList());
                        if (mounted) {
                          setState(() => _recipeTags = selected.toList());
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.tagUpdated),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              duration: const Duration(seconds: 1),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.tagSave,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCards(
      BuildContext context, Recipe recipe, AppLocalizations l10n) {
    return Row(
      children: [
        if (recipe.toplamSureDk > 0)
          Expanded(
            child: _StatCard(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF1565C0),
              label: 'SÜRE',
              value: l10n.mealPlanMinutes(recipe.toplamSureDk),
            ),
          ),
        if (recipe.kalori > 0) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              icon: Icons.local_fire_department_rounded,
              iconColor: const Color(0xFFE65100),
              label: 'KALORİ',
              value: '${recipe.kalori} kcal',
            ),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.signal_cellular_alt_rounded,
            iconColor: _difficultyColor(recipe.zorluk),
            label: 'SEVİYE',
            value: _difficultyLabel(recipe.zorluk, l10n),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
        ),
        const Spacer(),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              trailing,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
      ],
    );
  }

  Widget _buildIngredients(BuildContext context, Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: recipe.malzemeler.asMap().entries.map((entry) {
          final idx = entry.key;
          final ingredient = entry.value;
          final isChecked = _checkedIngredients[idx];

          return InkWell(
            onTap: () {
              setState(() {
                _checkedIngredients[idx] = !isChecked;
                _checkCookCompletion();
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  // Checkbox
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isChecked
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isChecked
                            ? AppColors.primary
                            : AppColors.border,
                        width: 2,
                      ),
                    ),
                    child: isChecked
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Malzeme adı
                  Expanded(
                    child: Text(
                      ingredient,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isChecked
                                    ? AppColors.charcoal
                                        .withValues(alpha: 0.4)
                                    : AppColors.charcoal,
                                decoration: isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                height: 1.3,
                              ),
                    ),
                  ),
                  // Alışveriş sepetine ekle
                  GestureDetector(
                    onTap: () => _showAddToShoppingSheet(ingredient),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                        color: AppColors.charcoal.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Tarifi plana ekle — gün ve öğün seçimi bottom sheet
  Future<void> _showAddToPlanSheet(AppLocalizations l10n) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final firestore = context.read<FirestoreService>();

    final plan = await firestore.getCurrentMealPlan(uid);
    if (!mounted) return;

    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.noPlanAvailable),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final scaffoldMsg = ScaffoldMessenger.of(context);
    final tasteService = context.read<TasteProfileService>();
    final recipe = widget.recipe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _AddToPlanSheet(
        plan: plan,
        recipeName: recipe.yemekAdi,
        onSelect: (dayIndex, slotKey) async {
          final existingList = plan.gunler[dayIndex].ogunler[slotKey];

          if (existingList != null && existingList.isNotEmpty) {
            // Mevcut öğün var — değiştir/ekle/iptal sor
            final existingNames = existingList.map((r) => r.yemekAdi).join(', ');
            final action = await showDialog<String>(
              context: ctx,
              builder: (dCtx) => AlertDialog(
                title: const Text('Bu öğünde tarif var'),
                content: Text('"$existingNames" zaten mevcut. Ne yapmak istersiniz?'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    child: const Text('Listeye ekle'),
                  ),
                ],
              ),
            );
            if (action == null) return;

            Navigator.pop(ctx);
            try {
              if (action == 'add') {
                await firestore.updateMealSlot(uid, plan, dayIndex, slotKey, [...existingList, recipe]);
              } else {
                await firestore.updateMealSlot(uid, plan, dayIndex, slotKey, [recipe]);
              }
              tasteService.logRecipeAction(uid, recipe, 'added_to_plan');
              RemoteLoggerService.userAction('recipe_added_to_plan',
                  screen: 'recipe_detail',
                  details: {'recipe': recipe.yemekAdi, 'day': dayIndex, 'slot': slotKey, 'action': action});
              scaffoldMsg.clearSnackBars();
              scaffoldMsg.showSnackBar(SnackBar(
                content: Text('${l10n.addedToPlan}: ${plan.gunler[dayIndex].gunAdi}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
            } catch (e) {
              RemoteLoggerService.error('add_to_plan_failed',
                  error: e, screen: 'recipe_detail');
            }
          } else {
            // Boş slot — direkt ekle
            Navigator.pop(ctx);
            try {
              await firestore.updateMealSlot(uid, plan, dayIndex, slotKey, [recipe]);
              tasteService.logRecipeAction(uid, recipe, 'added_to_plan');
              RemoteLoggerService.userAction('recipe_added_to_plan',
                  screen: 'recipe_detail',
                  details: {'recipe': recipe.yemekAdi, 'day': dayIndex, 'slot': slotKey});
              scaffoldMsg.clearSnackBars();
              scaffoldMsg.showSnackBar(SnackBar(
                content: Text('${l10n.addedToPlan}: ${plan.gunler[dayIndex].gunAdi}'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 2),
              ));
            } catch (e) {
              RemoteLoggerService.error('add_to_plan_failed',
                  error: e, screen: 'recipe_detail');
            }
          }
        },
      ),
    );
  }

  /// Malzemeyi alışveriş listesine ekle — mevcut listeler veya yeni oluştur
  Future<void> _showAddToShoppingSheet(String ingredient) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);
    final firestore = context.read<FirestoreService>();

    final lists = await firestore.getShoppingLists(uid);

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(l10n.addToShoppingList,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.charcoal)),
            const SizedBox(height: 16),

            // Yeni liste oluştur
            ListTile(
              leading: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
              ),
              title: Text(l10n.createNewList,
                style: const TextStyle(fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                Navigator.pop(ctx);
                final now = DateTime.now();
                final title = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')} Alışveriş';
                final newList = ShoppingList(
                  id: '',
                  title: title,
                  items: [ShoppingItem(name: ingredient, quantity: '')],
                  createdAt: now,
                );
                await firestore.saveShoppingList(uid, newList);
                if (mounted) {
                  scaffoldMessenger.clearSnackBars();
                  scaffoldMessenger.showSnackBar(SnackBar(
                    content: Text('${l10n.addedToList}: $title'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
            ),

            // Mevcut listeler
            if (lists.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...lists.take(5).map((list) => ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 18),
                ),
                title: Text(list.title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text('${list.items.length} ürün',
                  style: TextStyle(fontSize: 12, color: AppColors.charcoal.withValues(alpha: 0.4))),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final updatedItems = [
                    ...list.items,
                    ShoppingItem(name: ingredient, quantity: ''),
                  ];
                  await firestore.updateShoppingListItems(
                    uid, list.id, updatedItems);
                  if (mounted) {
                    scaffoldMessenger.clearSnackBars();
                    scaffoldMessenger.showSnackBar(SnackBar(
                      content: Text('${l10n.addedToList}: ${list.title}'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
              )),
            ],
          ],
        ),
      ),
    );
  }

  /// Adım tıklandığında: o adım ve önceki tüm adımlar tiklensin.
  /// Zaten tikliyse: o adım ve sonraki tüm adımların tikini kaldır.
  void _toggleStep(int idx) {
    setState(() {
      final willCheck = !_checkedSteps[idx];
      if (willCheck) {
        // Bu adım ve önceki tüm adımları tikle
        for (var i = 0; i <= idx; i++) {
          _checkedSteps[i] = true;
        }
      } else {
        // Bu adım ve sonraki tüm adımların tikini kaldır
        for (var i = idx; i < _checkedSteps.length; i++) {
          _checkedSteps[i] = false;
        }
      }
      _checkCookCompletion();
    });
  }

  Widget _buildSteps(BuildContext context, Recipe recipe) {
    return Column(
      children: recipe.yapilis.asMap().entries.map((entry) {
        final idx = entry.key;
        final stepNum = idx + 1;
        final step = entry.value;
        final isLast = stepNum == recipe.yapilis.length;
        final isChecked = _checkedSteps[idx];

        return GestureDetector(
          onTap: () => _toggleStep(idx),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol: numara/check + çizgi
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: isChecked
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.primary, AppColors.primaryDark],
                              ),
                        color: isChecked ? AppColors.primary : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isChecked
                            ? const Icon(Icons.check_rounded,
                                size: 20, color: Colors.white)
                            : Text(
                                '$stepNum',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isChecked
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : AppColors.border,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Sağ: adım kartı
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isChecked
                        ? AppColors.primary.withValues(alpha: 0.04)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isChecked
                        ? Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2))
                        : null,
                    boxShadow: isChecked
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          step,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isChecked
                                    ? AppColors.charcoal.withValues(alpha: 0.5)
                                    : AppColors.charcoal,
                                decoration:
                                    isChecked ? TextDecoration.lineThrough : null,
                                height: 1.6,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isChecked
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isChecked
                                ? AppColors.primary
                                : AppColors.charcoal.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: isChecked
                            ? const Icon(Icons.check_rounded,
                                size: 14, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  fontSize: 10,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Plana Ekle Bottom Sheet ────────────────────────────

class _AddToPlanSheet extends StatefulWidget {
  final MealPlan plan;
  final String recipeName;
  final void Function(int dayIndex, String slotKey) onSelect;

  const _AddToPlanSheet({
    required this.plan,
    required this.recipeName,
    required this.onSelect,
  });

  @override
  State<_AddToPlanSheet> createState() => _AddToPlanSheetState();
}

class _AddToPlanSheetState extends State<_AddToPlanSheet> {
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
            // Gün seçimi
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
            // Öğün seçimi
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
