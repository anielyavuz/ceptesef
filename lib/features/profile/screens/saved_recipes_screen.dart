import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/cuisine_labels.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../../core/utils/image_crop_util.dart';
import '../../meal_plan/screens/recipe_detail_screen.dart';

/// Kaydedilen tarifler arsivi — filtreleme + yildiz favori + secim modu + silme.
class SavedRecipesScreen extends StatefulWidget {
  const SavedRecipesScreen({super.key});

  @override
  State<SavedRecipesScreen> createState() => _SavedRecipesScreenState();
}

class _SavedRecipesScreenState extends State<SavedRecipesScreen> {
  List<Recipe>? _recipes;
  Map<String, bool> _stars = {};
  bool _isLoading = true;

  // Gruplandirma modu: 'date' (varsayilan), 'duration', 'cuisine'
  String _groupBy = 'date';

  // Secim modu
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  // Etiketler
  List<RecipeTag> _tags = [];
  String? _selectedTagId; // null = tümü

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('saved_recipes');
    RemoteLoggerService.info('saved_recipes_opened', screen: 'saved_recipes');
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = context.read<FirestoreService>();
      final results = await Future.wait([
        firestore.getSavedRecipes(user.uid),
        firestore.getSavedRecipeStars(user.uid),
        firestore.getRecipeTags(user.uid),
      ]);
      if (mounted) {
        setState(() {
          _recipes = results[0] as List<Recipe>;
          _stars = results[1] as Map<String, bool>;
          _tags = results[2] as List<RecipeTag>;
          _isLoading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('saved_recipes_load_failed',
          error: e, screen: 'saved_recipes');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _recipeDocId(Recipe r) => r.id.isNotEmpty ? r.id : r.yemekAdi;

  /// Yildiz toggle
  Future<void> _toggleStar(Recipe recipe) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _recipeDocId(recipe);
    final current = _stars[docId] == true;
    final newVal = !current;

    setState(() => _stars[docId] = newVal);

    HapticFeedback.lightImpact();

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newVal ? l10n.savedStarAdded : l10n.savedStarRemoved),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
        backgroundColor: newVal ? AppColors.secondary : AppColors.charcoal,
      ),
    );

    try {
      await context
          .read<FirestoreService>()
          .toggleSavedRecipeStar(user.uid, docId, newVal);
    } catch (_) {}
  }

  // ─── Secim modu ────────────────────────────────────────

  void _enterSelectionMode(Recipe recipe) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds.add(_recipeDocId(recipe));
    });
  }

  void _toggleSelection(Recipe recipe) {
    final docId = _recipeDocId(recipe);
    setState(() {
      if (_selectedIds.contains(docId)) {
        _selectedIds.remove(docId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(docId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _deleteSelected() async {
    final l10n = AppLocalizations.of(context);
    final count = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.savedDeleteConfirmTitle),
        content: Text(l10n.savedDeleteConfirmMessage(count)),
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final idsToDelete = _selectedIds.toList();
    final firestore = context.read<FirestoreService>();

    setState(() {
      _recipes?.removeWhere((r) => idsToDelete.contains(_recipeDocId(r)));
      for (final id in idsToDelete) {
        _stars.remove(id);
      }
      _selectionMode = false;
      _selectedIds.clear();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.savedDeleteSuccess(count)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    RemoteLoggerService.userAction('saved_recipes_deleted',
        screen: 'saved_recipes',
        details: {'count': count});

    try {
      await firestore.deleteSavedRecipes(user.uid, idsToDelete);
    } catch (e) {
      RemoteLoggerService.error('saved_recipes_delete_failed',
          error: e, screen: 'saved_recipes');
    }
  }

  // ─── Gruplandirma ─────────────────────────────────────────

  /// Etiket filtresine gore filtrelenmis tarifler
  List<Recipe> get _filteredRecipes {
    if (_recipes == null) return [];
    if (_selectedTagId == null) return _recipes!;
    if (_selectedTagId == '__no_tag__') {
      return _recipes!.where((r) => r.tags.isEmpty).toList();
    }
    return _recipes!.where((r) => r.tags.contains(_selectedTagId)).toList();
  }

  List<Recipe> get _starredRecipes {
    final source = _filteredRecipes;
    return source
        .where((r) => _stars[_recipeDocId(r)] == true)
        .toList();
  }

  /// Tarifleri secili gruplama moduna gore gruplar.
  /// Donen map: grup baslik → tarifler (sira korunur).
  Map<String, List<Recipe>> _groupedRecipes(AppLocalizations l10n) {
    final source = _filteredRecipes;
    if (source.isEmpty) return {};

    switch (_groupBy) {
      case 'duration':
        return _groupByDuration(l10n);
      case 'cuisine':
        return _groupByCuisine();
      default:
        return _groupByDate(l10n);
    }
  }

  Map<String, List<Recipe>> _groupByDate(AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final groups = <String, List<Recipe>>{};
    for (final r in _filteredRecipes) {
      final saved = r.savedAt;
      String key;
      if (saved == null) {
        key = l10n.savedGroupOlder;
      } else {
        final d = DateTime(saved.year, saved.month, saved.day);
        if (d == today || d.isAfter(today)) {
          key = l10n.savedGroupToday;
        } else if (d == yesterday || (d.isAfter(yesterday) && d.isBefore(today))) {
          key = l10n.savedGroupYesterday;
        } else if (d.isAfter(weekAgo)) {
          key = l10n.savedGroupThisWeek;
        } else if (d.isAfter(monthStart) || d == monthStart) {
          key = l10n.savedGroupThisMonth;
        } else {
          key = l10n.savedGroupOlder;
        }
      }
      groups.putIfAbsent(key, () => []).add(r);
    }
    // Sirayi koru: Bugun, Dun, Bu Hafta, Bu Ay, Daha Eski
    final order = [
      l10n.savedGroupToday,
      l10n.savedGroupYesterday,
      l10n.savedGroupThisWeek,
      l10n.savedGroupThisMonth,
      l10n.savedGroupOlder,
    ];
    final sorted = <String, List<Recipe>>{};
    for (final key in order) {
      if (groups.containsKey(key)) sorted[key] = groups[key]!;
    }
    return sorted;
  }

  Map<String, List<Recipe>> _groupByDuration(AppLocalizations l10n) {
    final groups = <String, List<Recipe>>{};
    for (final r in _filteredRecipes) {
      String key;
      if (r.toplamSureDk > 0 && r.toplamSureDk <= 30) {
        key = l10n.savedGroupQuickRecipes;
      } else if (r.toplamSureDk > 30 && r.toplamSureDk <= 60) {
        key = l10n.savedGroupMediumRecipes;
      } else {
        key = l10n.savedGroupLongRecipes;
      }
      groups.putIfAbsent(key, () => []).add(r);
    }
    final order = [
      l10n.savedGroupQuickRecipes,
      l10n.savedGroupMediumRecipes,
      l10n.savedGroupLongRecipes,
    ];
    final sorted = <String, List<Recipe>>{};
    for (final key in order) {
      if (groups.containsKey(key)) sorted[key] = groups[key]!;
    }
    return sorted;
  }

  Map<String, List<Recipe>> _groupByCuisine() {
    final groups = <String, List<Recipe>>{};
    for (final r in _filteredRecipes) {
      if (r.mutfaklar.isEmpty) {
        groups.putIfAbsent('Diğer', () => []).add(r);
      } else {
        for (final c in r.mutfaklar) {
          groups.putIfAbsent(CuisineLabels.label(c), () => []).add(r);
        }
      }
    }
    final sorted = Map.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return sorted;
  }

  /// Tek tarif sil — onay dialogu ile
  Future<void> _deleteSingle(Recipe recipe) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.savedDeleteConfirmTitle),
        content: Text('"${recipe.yemekAdi}" silinsin mi?'),
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _recipeDocId(recipe);
    final firestore = context.read<FirestoreService>();

    setState(() {
      _recipes?.removeWhere((r) => _recipeDocId(r) == docId);
      _stars.remove(docId);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.savedDeleteSuccess(1)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    RemoteLoggerService.userAction('saved_recipe_deleted_single',
        screen: 'saved_recipes', details: {'recipe': recipe.yemekAdi});

    try {
      await firestore.deleteSavedRecipe(user.uid, docId);
    } catch (e) {
      RemoteLoggerService.error('saved_recipe_delete_failed',
          error: e, screen: 'saved_recipes');
    }
  }

  /// Kart tiklandiginda: secim modundaysa toggle, degilse detay ac
  void _onCardTap(Recipe recipe) {
    if (_selectionMode) {
      _toggleSelection(recipe);
    } else {
      _openDetail(recipe);
    }
  }

  Future<void> _openDetail(Recipe recipe) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: recipe, fromSaved: true),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      // Detaydan silindiyse
      final docId = _recipeDocId(recipe);
      setState(() {
        _recipes?.removeWhere((r) => _recipeDocId(r) == docId);
        _stars.remove(docId);
      });
    } else {
      // Etiket değişmiş olabilir — listeyi yenile
      _load();
    }
  }

  // ─── Tarif Tarama (Kamera / Galeri) ──────────────────────

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
      screen: 'saved_recipes',
      details: {'source': source == ImageSource.camera ? 'camera' : 'gallery'},
    );

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
              error: e, screen: 'saved_recipes');
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
        screen: 'saved_recipes',
        details: {
          'recipe': recipe.yemekAdi,
          'has_image': recipe.imageBase64 != null,
        },
      );

      if (!mounted) return;

      // Listeyi yenile
      await _load();

      if (!mounted) return;

      // Başarı snackbar + tarif detayına git
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.homeScanSuccessDesc(recipe.yemekAdi)),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailScreen(recipe: recipe),
        ),
      );
    } catch (e) {
      // Loading varsa kapat
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      RemoteLoggerService.error('scan_recipe_failed',
          error: e, screen: 'saved_recipes');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.homeScanError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: _selectionMode ? _buildSelectionAppBar(l10n) : _buildNormalAppBar(l10n),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _recipes == null || _recipes!.isEmpty
                ? _buildEmpty(l10n)
                : _buildContent(l10n),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(AppLocalizations l10n) {
    return AppBar(
      title: Text(l10n.profileSavedRecipes),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.charcoal,
      elevation: 0,
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: _showScanRecipeSheet,
          icon: const Icon(Icons.photo_camera_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          tooltip: l10n.homeScanRecipe,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(AppLocalizations l10n) {
    return AppBar(
      backgroundColor: AppColors.charcoal,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: _exitSelectionMode,
      ),
      title: Text(l10n.savedSelectMode(_selectedIds.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _selectedIds.isNotEmpty ? _deleteSelected : null,
          tooltip: l10n.savedDeleteSelected,
        ),
      ],
    );
  }

  Widget _buildEmpty(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\u{1F4DA}', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              l10n.profileSavedEmpty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final starred = _starredRecipes;
    final groups = _groupedRecipes(l10n);

    return CustomScrollView(
      slivers: [
        // Yildizli tarifler yatay alani
        if (starred.isNotEmpty && !_selectionMode) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.savedStarred,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${starred.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: starred.length,
                itemBuilder: (ctx, i) => _StarredRecipeChip(
                  recipe: starred[i],
                  onTap: () => _onCardTap(starred[i]),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Divider(height: 24, indent: 20, endIndent: 20),
          ),
        ],

        // Gruplandirma filtre chip'leri
        if (!_selectionMode)
          SliverToBoxAdapter(child: _buildGroupFilters(l10n)),

        // Etiket filtre chip'leri
        if (!_selectionMode && _tags.isNotEmpty)
          SliverToBoxAdapter(child: _buildTagFilters(l10n)),

        // Gruplu grid
        ...groups.entries.expand((entry) => [
          // Grup basligi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${entry.value.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Grup gridi
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final recipe = entry.value[index];
                  final docId = _recipeDocId(recipe);
                  final isStarred = _stars[docId] == true;
                  final isSelected = _selectedIds.contains(docId);
                  // Tarifte bulunan etiketleri bul
                  final rTags = _tags
                      .where((t) => recipe.tags.contains(t.id))
                      .toList();
                  return _RecipeGridCard(
                    recipe: recipe,
                    isStarred: isStarred,
                    isSelected: isSelected,
                    selectionMode: _selectionMode,
                    onTap: () => _onCardTap(recipe),
                    onLongPress: () => _enterSelectionMode(recipe),
                    onStarTap: () => _toggleStar(recipe),
                    onDeleteTap: () => _deleteSingle(recipe),
                    onTagTap: () => _showTagRecipeSheet(recipe),
                    recipeTags: rTags,
                  );
                },
                childCount: entry.value.length,
              ),
            ),
          ),
        ]),

        // Alt bosluk
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildGroupFilters(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _FilterChip(
              label: l10n.savedGroupDate,
              icon: Icons.calendar_today_rounded,
              isSelected: _groupBy == 'date',
              onTap: () => setState(() => _groupBy = 'date'),
            ),
            _FilterChip(
              label: l10n.savedGroupDuration,
              icon: Icons.schedule_rounded,
              isSelected: _groupBy == 'duration',
              onTap: () => setState(() => _groupBy = 'duration'),
            ),
            _FilterChip(
              label: l10n.savedGroupCuisine,
              icon: Icons.restaurant_rounded,
              isSelected: _groupBy == 'cuisine',
              onTap: () => setState(() => _groupBy = 'cuisine'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Etiket Filtreleri ─────────────────────────────────

  Widget _buildTagFilters(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _TagFilterChip(
              label: l10n.tagAll,
              color: AppColors.charcoal,
              isSelected: _selectedTagId == null,
              onTap: () => setState(() => _selectedTagId = null),
            ),
            ..._tags.map((tag) => _TagFilterChip(
              label: tag.name,
              color: tag.color,
              isSelected: _selectedTagId == tag.id,
              onTap: () => setState(() => _selectedTagId = tag.id),
            )),
            _TagFilterChip(
              label: l10n.tagNoTag,
              color: AppColors.charcoal.withValues(alpha: 0.4),
              isSelected: _selectedTagId == '__no_tag__',
              onTap: () => setState(() => _selectedTagId = '__no_tag__'),
            ),
            // Etiket yönet butonu
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => _showManageTagsSheet(l10n),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.settings_rounded, size: 14,
                          color: AppColors.charcoal.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        l10n.tagManage,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.charcoal.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Etiket Yönetimi ──────────────────────────────────

  /// Etiket yönetim bottom sheet — mevcut etiketleri listele + yeni ekle
  void _showManageTagsSheet(AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ManageTagsSheet(
        tags: _tags,
        onCreateTag: (name, colorValue) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final firestore = context.read<FirestoreService>();
          final id = await firestore.createRecipeTag(user.uid, name, colorValue);
          if (mounted) {
            setState(() {
              _tags.add(RecipeTag(id: id, name: name, colorValue: colorValue));
            });
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.tagCreated),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.primary,
              ),
            );
          }
          RemoteLoggerService.userAction('tag_created',
              screen: 'saved_recipes', details: {'name': name});
        },
        onDeleteTag: (tagId) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final firestore = context.read<FirestoreService>();
          await firestore.deleteRecipeTag(user.uid, tagId);
          // Tüm tariflerden bu etiketi kaldır
          if (_recipes != null) {
            for (final recipe in _recipes!) {
              if (recipe.tags.contains(tagId)) {
                final newTags = recipe.tags.where((t) => t != tagId).toList();
                await firestore.updateRecipeTags(
                    user.uid, _recipeDocId(recipe), newTags);
              }
            }
          }
          if (mounted) {
            if (_selectedTagId == tagId) _selectedTagId = null;
            await _load();
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.tagDeleted),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
              ),
            );
          }
          RemoteLoggerService.userAction('tag_deleted',
              screen: 'saved_recipes', details: {'tagId': tagId});
        },
      ),
    );
  }

  /// Tarife etiket atama bottom sheet
  void _showTagRecipeSheet(Recipe recipe) {
    final l10n = AppLocalizations.of(context);
    final docId = _recipeDocId(recipe);
    final currentTags = Set<String>.from(recipe.tags);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AssignTagsSheet(
        tags: _tags,
        selectedTagIds: currentTags,
        onSave: (selectedIds) async {
          Navigator.pop(ctx);
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          final firestore = context.read<FirestoreService>();
          await firestore.updateRecipeTags(user.uid, docId, selectedIds.toList());
          if (mounted) {
            // Lokalde güncelle
            final idx = _recipes?.indexWhere((r) => _recipeDocId(r) == docId);
            if (idx != null && idx >= 0) {
              setState(() {
                _recipes![idx] = _recipes![idx].copyWith(tags: selectedIds.toList());
              });
            }
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.tagUpdated),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 1),
                backgroundColor: AppColors.primary,
              ),
            );
          }
          RemoteLoggerService.userAction('recipe_tags_updated',
              screen: 'saved_recipes',
              details: {'recipe': recipe.yemekAdi, 'tagCount': selectedIds.length});
        },
      ),
    );
  }
}

// ─── Filtre Chip Widget ──────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? null
                : Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14,
                    color: isSelected ? Colors.white : AppColors.charcoal.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? Colors.white : AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Yildizli Tarif Yatay Chip ──────────────────────────

class _StarredRecipeChip extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _StarredRecipeChip({
    required this.recipe,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Stack(
                children: [
                  recipe.imageBase64 != null
                      ? ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(15)),
                          child: SizedBox.expand(
                            child: Image.memory(
                              base64Decode(recipe.imageBase64!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(_ogunEmoji(recipe.ogunTipi),
                                    style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(_ogunEmoji(recipe.ogunTipi),
                              style: const TextStyle(fontSize: 24)),
                        ),
                  const Positioned(
                    top: 4,
                    right: 6,
                    child: Icon(Icons.star_rounded,
                        size: 14, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.yemekAdi,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                                height: 1.2,
                              ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    if (recipe.toplamSureDk > 0)
                      Text(
                        '${recipe.toplamSureDk} dk',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.charcoal
                                  .withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _ogunEmoji(String ogunTipi) {
    switch (ogunTipi) {
      case 'kahvalti': return '\u{1F305}';
      case 'ara_ogun': return '\u{1F34E}';
      case 'tatli': return '\u{1F370}';
      case 'corba': return '\u{1F35C}';
      default: return '\u{1F37D}\u{FE0F}';
    }
  }
}

// ─── Grid Kart ──────────────────────────────────────────

class _RecipeGridCard extends StatelessWidget {
  final Recipe recipe;
  final bool isStarred;
  final bool isSelected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onStarTap;
  final VoidCallback onDeleteTap;
  final VoidCallback? onTagTap;
  final List<RecipeTag> recipeTags;

  const _RecipeGridCard({
    required this.recipe,
    required this.isStarred,
    required this.isSelected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onStarTap,
    required this.onDeleteTap,
    this.onTagTap,
    this.recipeTags = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cuisineColors = [
      AppColors.primary,
      const Color(0xFFE65100),
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
    ];
    final colorIndex = recipe.yemekAdi.length % cuisineColors.length;

    return GestureDetector(
      onTap: onTap,
      onLongPress: selectionMode ? null : onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 16 : 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ust gorsel veya renk bandi
                recipe.imageBase64 != null
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: Image.memory(
                            base64Decode(recipe.imageBase64!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildColorBand(
                                cuisineColors[colorIndex]),
                          ),
                        ),
                      )
                    : _buildColorBand(cuisineColors[colorIndex]),
                // Icerik
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.yemekAdi,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                    height: 1.2,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (recipe.kalori > 0) ...[
                              Icon(Icons.local_fire_department_rounded,
                                  size: 12, color: const Color(0xFFE65100)),
                              const SizedBox(width: 2),
                              Text(
                                '${recipe.kalori}',
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
                            if (recipe.toplamSureDk > 0) ...[
                              Icon(Icons.schedule_rounded,
                                  size: 12,
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.4)),
                              const SizedBox(width: 2),
                              Text(
                                '${recipe.toplamSureDk} dk',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.charcoal
                                          .withValues(alpha: 0.4),
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (recipe.mutfaklar.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cuisineColors[colorIndex]
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              CuisineLabels.label(recipe.mutfaklar.first),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: cuisineColors[colorIndex],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (recipe.savedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatSavedAt(recipe.savedAt!),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.35),
                                    fontSize: 9,
                                  ),
                            ),
                          ),
                        // Etiketler
                        if (recipeTags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: recipeTags.take(3).map((tag) =>
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: tag.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tag.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: tag.color,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 8,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Sag ust kose: secim modunda checkbox, degilse yildiz butonu
            Positioned(
              top: 4,
              right: 4,
              child: selectionMode
                  ? _buildCheckbox()
                  : _buildStarButton(),
            ),
            // Sol ust kose: silme butonu (secim modunda degil)
            if (!selectionMode)
              Positioned(
                top: 4,
                left: 4,
                child: _buildDeleteButton(),
              ),
            // Sag alt kose: etiket butonu
            if (!selectionMode && onTagTap != null)
              Positioned(
                bottom: 4,
                right: 4,
                child: _buildTagButton(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarButton() {
    return GestureDetector(
      onTap: onStarTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isStarred
              ? AppColors.secondary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: isStarred
              ? AppColors.secondary
              : AppColors.charcoal.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildTagButton() {
    final hasTags = recipeTags.isNotEmpty;
    return GestureDetector(
      onTap: onTagTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hasTags
              ? recipeTags.first.color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          hasTags ? Icons.label_rounded : Icons.label_outline_rounded,
          size: 14,
          color: hasTags
              ? recipeTags.first.color
              : AppColors.charcoal.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return GestureDetector(
      onTap: onDeleteTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 14,
          color: AppColors.charcoal.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildCheckbox() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: isSelected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }

  Widget _buildColorBand(Color color) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.12),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Text(
          _ogunEmoji(recipe.ogunTipi),
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  static String _ogunEmoji(String ogunTipi) {
    switch (ogunTipi) {
      case 'kahvalti': return '\u{1F305}';
      case 'ara_ogun': return '\u{1F34E}';
      case 'tatli': return '\u{1F370}';
      case 'corba': return '\u{1F35C}';
      default: return '\u{1F37D}\u{FE0F}';
    }
  }

  static String _formatSavedAt(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    }
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year) {
      return '$day.$month $hour:$minute';
    }
    return '$day.$month.${dt.year} $hour:$minute';
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

// ─── Etiket Filtre Chip ─────────────────────────────────

class _TagFilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TagFilterChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? Colors.white : AppColors.charcoal,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Etiket Yönetim Bottom Sheet ────────────────────────

class _ManageTagsSheet extends StatefulWidget {
  final List<RecipeTag> tags;
  final Future<void> Function(String name, int colorValue) onCreateTag;
  final Future<void> Function(String tagId) onDeleteTag;

  const _ManageTagsSheet({
    required this.tags,
    required this.onCreateTag,
    required this.onDeleteTag,
  });

  @override
  State<_ManageTagsSheet> createState() => _ManageTagsSheetState();
}

class _ManageTagsSheetState extends State<_ManageTagsSheet> {
  final _nameController = TextEditingController();
  int _selectedColor = 0xFF48A14D; // AppColors.primary

  static const _colorOptions = [
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
              l10n.tagManage,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
            ),
            const SizedBox(height: 16),
            // Yeni etiket oluşturma alanı
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
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
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    final name = _nameController.text.trim();
                    if (name.isEmpty) return;
                    await widget.onCreateTag(name, _selectedColor);
                    _nameController.clear();
                    if (mounted) Navigator.pop(context);
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
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Renk seçici
            SizedBox(
              height: 32,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _colorOptions.length,
                itemBuilder: (ctx, i) {
                  final c = _colorOptions[i];
                  final isActive = c == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: isActive
                            ? Border.all(color: AppColors.charcoal, width: 2.5)
                            : null,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Color(c).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                )
                              ]
                            : null,
                      ),
                      child: isActive
                          ? const Icon(Icons.check_rounded,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            // Mevcut etiketler listesi
            if (widget.tags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l10n.tagEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.4),
                      ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.tags.length,
                  itemBuilder: (ctx, i) {
                    final tag = widget.tags[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: tag.color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      title: Text(
                        tag.name,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 18,
                            color: AppColors.charcoal.withValues(alpha: 0.4)),
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: Text(l10n.tagDelete),
                              content: Text(l10n.tagDeleteConfirm),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dCtx, true),
                                  style: TextButton.styleFrom(
                                      foregroundColor: Colors.red),
                                  child: Text(l10n.tagDelete),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await widget.onDeleteTag(tag.id);
                            if (mounted) Navigator.pop(context);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Tarife Etiket Atama Bottom Sheet ───────────────────

class _AssignTagsSheet extends StatefulWidget {
  final List<RecipeTag> tags;
  final Set<String> selectedTagIds;
  final void Function(Set<String> selectedIds) onSave;

  const _AssignTagsSheet({
    required this.tags,
    required this.selectedTagIds,
    required this.onSave,
  });

  @override
  State<_AssignTagsSheet> createState() => _AssignTagsSheetState();
}

class _AssignTagsSheetState extends State<_AssignTagsSheet> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedTagIds);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
              l10n.tagEditRecipe,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
            ),
            const SizedBox(height: 16),
            if (widget.tags.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  l10n.tagEmpty,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.4),
                      ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.tags.map((tag) {
                  final isActive = _selected.contains(tag.id);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isActive) {
                          _selected.remove(tag.id);
                        } else {
                          _selected.add(tag.id);
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
                onPressed: () => widget.onSave(_selected),
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
    );
  }
}

