import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/taste_profile_service.dart';
import '../../../core/services/remote_logger_service.dart';

/// Öğün ekleme kaynak seçici + kaydedilenlerden seçme sheet'i.
///
/// İki mod:
/// - [_showSaved] false → kaynak seçici (AI / Kaydedilenlerden)
/// - [_showSaved] true  → kaydedilen tarifler listesi + arama
///
/// Döndürür:
/// - `null`  → iptal
/// - `false` → AI seçildi (çağıran AI sheet'i açar)
/// - `true`  → kaydedilen tarif eklendi, plan yenilenmeli
class AddMealSourceSheet extends StatefulWidget {
  final int dayIndex;
  final String slotKey;
  final String slotLabel;

  const AddMealSourceSheet({
    super.key,
    required this.dayIndex,
    required this.slotKey,
    required this.slotLabel,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int dayIndex,
    required String slotKey,
    required String slotLabel,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMealSourceSheet(
        dayIndex: dayIndex,
        slotKey: slotKey,
        slotLabel: slotLabel,
      ),
    );
  }

  @override
  State<AddMealSourceSheet> createState() => _AddMealSourceSheetState();
}

class _AddMealSourceSheetState extends State<AddMealSourceSheet> {
  bool _showSaved = false;
  List<Recipe>? _savedRecipes;
  bool _loading = false;
  bool _adding = false;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final recipes =
        await context.read<FirestoreService>().getSavedRecipes(uid);
    if (mounted) setState(() { _savedRecipes = recipes; _loading = false; });
  }

  Future<void> _selectRecipe(Recipe recipe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestore = context.read<FirestoreService>();
    final l10n = AppLocalizations.of(context);

    setState(() => _adding = true);

    final plan = await firestore.getCurrentMealPlan(uid);
    if (plan == null || !mounted) { setState(() => _adding = false); return; }

    final existingList = plan.gunler[widget.dayIndex].ogunler[widget.slotKey];

    if (existingList != null && existingList.isNotEmpty) {
      setState(() => _adding = false);
      final existingNames = existingList.map((r) => r.yemekAdi).join(', ');
      final action = await _showReplaceDialog(existingNames, l10n);
      if (action == null || action == 'cancel' || !mounted) return;

      setState(() => _adding = true);

      if (action == 'add') {
        await firestore.updateMealSlot(uid, plan, widget.dayIndex, widget.slotKey, [...existingList, recipe]);
      } else {
        await firestore.updateMealSlot(uid, plan, widget.dayIndex, widget.slotKey, [recipe]);
      }
    } else {
      await firestore.updateMealSlot(uid, plan, widget.dayIndex, widget.slotKey, [recipe]);
    }

    if (!mounted) return;
    context.read<TasteProfileService>().logRecipeAction(uid, recipe, 'added_to_plan');
    RemoteLoggerService.userAction('saved_recipe_added_to_slot',
        screen: 'add_meal_source', details: {'recipe': recipe.yemekAdi});

    if (mounted) Navigator.of(context).pop(true);
  }

  Future<String?> _showReplaceDialog(String existingName, AppLocalizations l10n) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
      child: _showSaved
          ? _SavedRecipesPicker(
              key: const ValueKey('saved'),
              recipes: _savedRecipes,
              loading: _loading,
              adding: _adding,
              search: _search,
              searchController: _searchController,
              slotLabel: widget.slotLabel,
              onBack: () => setState(() {
                _showSaved = false;
                _search = '';
                _searchController.clear();
              }),
              onSearchChanged: (v) => setState(() => _search = v),
              onSelect: _selectRecipe,
            )
          : _SourcePicker(
              key: const ValueKey('source'),
              slotLabel: widget.slotLabel,
              onAI: () => Navigator.of(context).pop(false),
              onSaved: () {
                setState(() => _showSaved = true);
                _loadSaved();
              },
            ),
    );
  }
}

// ─── Kaynak Seçici ─────────────────────────────────────────

class _SourcePicker extends StatelessWidget {
  final String slotLabel;
  final VoidCallback onAI;
  final VoidCallback onSaved;

  const _SourcePicker({
    super.key,
    required this.slotLabel,
    required this.onAI,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Başlık
          Text(
            l10n.addMealSourceTitle,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            slotLabel,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.charcoal.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 24),
          // AI seçeneği
          _SourceCard(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF6B4EFF),
            iconBg: const Color(0xFFF0EDFF),
            title: l10n.addMealSourceAI,
            description: l10n.addMealSourceAIDesc,
            onTap: onAI,
          ),
          const SizedBox(height: 12),
          // Kaydedilenler seçeneği
          _SourceCard(
            icon: Icons.bookmark_rounded,
            iconColor: AppColors.primary,
            iconBg: AppColors.primary.withValues(alpha: 0.1),
            title: l10n.addMealSourceSaved,
            description: l10n.addMealSourceSavedDesc,
            onTap: onSaved,
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _SourceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.charcoal.withValues(alpha: 0.25),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Kaydedilenler Listesi ──────────────────────────────────

class _SavedRecipesPicker extends StatelessWidget {
  final List<Recipe>? recipes;
  final bool loading;
  final bool adding;
  final String search;
  final TextEditingController searchController;
  final String slotLabel;
  final VoidCallback onBack;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Recipe> onSelect;

  const _SavedRecipesPicker({
    super.key,
    required this.recipes,
    required this.loading,
    required this.adding,
    required this.search,
    required this.searchController,
    required this.slotLabel,
    required this.onBack,
    required this.onSearchChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filtered = (recipes ?? []).where((r) {
      if (search.isEmpty) return true;
      return r.yemekAdi.toLowerCase().contains(search.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  color: AppColors.charcoal,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.addMealSourceSaved,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      Text(
                        slotLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.charcoal.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Arama
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n.addMealSourceSavedSearch,
                hintStyle: TextStyle(
                  color: AppColors.charcoal.withValues(alpha: 0.35),
                  fontSize: 14,
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.charcoal.withValues(alpha: 0.35), size: 20),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          // Liste
          Expanded(
            child: _buildList(context, l10n, filtered),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildList(
      BuildContext context, AppLocalizations l10n, List<Recipe> filtered) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (adding) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (recipes != null && recipes!.isEmpty) {
      return Center(
        child: Text(
          l10n.addMealSourceSavedEmpty,
          style: TextStyle(
            color: AppColors.charcoal.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '🔍 "$search" için sonuç bulunamadı',
          style: TextStyle(
            color: AppColors.charcoal.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final recipe = filtered[index];
        return _RecipeListTile(recipe: recipe, onTap: () => onSelect(recipe));
      },
    );
  }
}

class _RecipeListTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeListTile({required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.yemekAdi,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (recipe.toplamSureDk > 0) ...[
                          Icon(Icons.schedule_rounded,
                              size: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.4)),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.toplamSureDk} dk',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (recipe.kalori > 0) ...[
                          Icon(Icons.local_fire_department_rounded,
                              size: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.4)),
                          const SizedBox(width: 3),
                          Text(
                            '${recipe.kalori} kcal',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Ekle',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
