import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/remote_logger_service.dart';
import 'shopping_detail_screen.dart';

/// Alışveriş listesi ekranı.
/// Kaydedilmiş listeleri gösterir + yeni liste oluşturma akışı.
class ShoppingScreen extends StatefulWidget {
  static final globalKey = GlobalKey<ShoppingScreenState>();

  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => ShoppingScreenState();
}

class ShoppingScreenState extends State<ShoppingScreen> {
  List<ShoppingList>? _savedLists;
  bool _isLoading = true;

  // Çoklu seçim modu
  final Set<String> _selectedListIds = {};
  bool get _isSelecting => _selectedListIds.isNotEmpty;

  // Yeni liste oluşturma modu
  bool _isCreating = false;
  MealPlan? _plan;
  final Set<String> _selectedSlots = {};

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('shopping');
    _loadSavedLists();
  }

  /// Listeyi dışarıdan yenilemek için (tab geçişlerinde)
  void refreshLists() => _loadSavedLists();

  Future<void> _loadSavedLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final lists =
          await context.read<FirestoreService>().getShoppingLists(user.uid);
      if (mounted) {
        setState(() {
          _savedLists = lists;
          _isLoading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('shopping_lists_load_failed',
          error: e, screen: 'shopping');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startCreating() async {
    final l10n = AppLocalizations.of(context);

    final choice = await showModalBottomSheet<String>(
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
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(l10n.shoppingNewList,
              style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.charcoal)),
            const SizedBox(height: 16),
            // Tariflerden oluştur
            _NewListOption(
              icon: Icons.restaurant_menu_rounded,
              title: l10n.shoppingGenerateList,
              subtitle: l10n.shoppingSelectMeals,
              onTap: () => Navigator.pop(ctx, 'meals'),
            ),
            const SizedBox(height: 10),
            // Manuel liste
            _NewListOption(
              icon: Icons.edit_note_rounded,
              title: l10n.shoppingManualList,
              subtitle: l10n.shoppingManualListDesc,
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            SizedBox(height: MediaQuery.of(ctx).viewPadding.bottom),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'manual') {
      await _createManualList();
    } else {
      await _startCreatingFromMeals();
    }
  }

  Future<void> _startCreatingFromMeals() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final plan =
          await context.read<FirestoreService>().getCurrentMealPlan(user.uid);
      if (mounted) {
        setState(() {
          _plan = plan;
          _isCreating = true;
          _isLoading = false;
          _selectedSlots.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createManualList() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final firestore = context.read<FirestoreService>();
    final now = DateTime.now();
    final title =
        '${now.day}.${now.month.toString().padLeft(2, '0')} Alışveriş';

    final list = ShoppingList(
      id: '',
      title: title,
      items: [],
      selectedMeals: [],
      createdAt: now,
    );

    await firestore.saveShoppingList(user.uid, list);

    RemoteLoggerService.userAction('manual_shopping_list_created',
        screen: 'shopping');

    if (!mounted) return;
    await _loadSavedLists();

    // Oluşturulan listeyi hemen aç
    if (_savedLists != null && _savedLists!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShoppingDetailScreen(shoppingList: _savedLists!.first),
        ),
      ).then((_) => _loadSavedLists());
    }
  }

  void _toggleSlot(int dayIndex, String slotKey) {
    final key = '${dayIndex}_$slotKey';
    setState(() {
      if (_selectedSlots.contains(key)) {
        _selectedSlots.remove(key);
      } else {
        _selectedSlots.add(key);
      }
    });
  }

  void _toggleDay(int dayIndex) {
    final day = _plan!.gunler[dayIndex];
    final daySlots = day.ogunler.keys.map((k) => '${dayIndex}_$k').toSet();
    final allSelected = daySlots.every(_selectedSlots.contains);

    setState(() {
      if (allSelected) {
        _selectedSlots.removeAll(daySlots);
      } else {
        _selectedSlots.addAll(daySlots);
      }
    });
  }

  void _selectAll() {
    if (_plan == null) return;
    setState(() {
      _selectedSlots.clear();
      for (var i = 0; i < _plan!.gunler.length; i++) {
        for (final slot in _plan!.gunler[i].ogunler.keys) {
          _selectedSlots.add('${i}_$slot');
        }
      }
    });
  }

  void _deselectAll() => setState(() => _selectedSlots.clear());

  Future<void> _generateAndSave() async {
    if (_plan == null || _selectedSlots.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context);
    final firestore = context.read<FirestoreService>();

    // Malzemeleri topla
    final ingredients = <String, ShoppingItem>{};
    final mealLabels = <String>[];

    for (final key in _selectedSlots) {
      final parts = key.split('_');
      final dayIndex = int.parse(parts[0]);
      final slotKey = parts.sublist(1).join('_');
      final day = _plan!.gunler[dayIndex];
      final recipes = day.ogunler[slotKey];
      if (recipes == null || recipes.isEmpty) continue;

      mealLabels.add('${day.gunAdi} - ${recipes.map((r) => r.yemekAdi).join(', ')}');

      for (final recipe in recipes) {
      for (final malzeme in recipe.malzemeler) {
        final parsed = _parseMalzeme(malzeme);
        final normalizedName = parsed.name.toLowerCase().trim();

        if (ingredients.containsKey(normalizedName)) {
          final existing = ingredients[normalizedName]!;
          if (parsed.quantity.isNotEmpty) {
            ingredients[normalizedName] = ShoppingItem(
              name: parsed.name,
              quantity: existing.quantity.isEmpty
                  ? parsed.quantity
                  : '${existing.quantity} + ${parsed.quantity}',
            );
          }
        } else {
          ingredients[normalizedName] = ShoppingItem(
            name: parsed.name,
            quantity: parsed.quantity,
          );
        }
      }
      }
    }

    final items = ingredients.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    // Başlık oluştur
    final now = DateTime.now();
    final title =
        '${now.day}.${now.month.toString().padLeft(2, '0')} Alışveriş';

    final shoppingList = ShoppingList(
      id: '',
      title: title,
      items: items,
      selectedMeals: mealLabels,
      createdAt: now,
    );

    try {
      await firestore.saveShoppingList(user.uid, shoppingList);

      RemoteLoggerService.userAction('shopping_list_created',
          screen: 'shopping',
          details: {'items': items.length, 'meals': mealLabels.length});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shoppingSaved),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
        ),
      );

      setState(() => _isCreating = false);
      _loadSavedLists();
    } catch (e) {
      RemoteLoggerService.error('shopping_list_save_failed',
          error: e, screen: 'shopping');
    }
  }

  _ParsedIngredient _parseMalzeme(String malzeme) {
    final parts = malzeme.trim().split(' ');
    if (parts.length <= 1) {
      return _ParsedIngredient(quantity: '', name: malzeme);
    }

    final firstIsNumber = RegExp(r'^[\d/.,]+$').hasMatch(parts[0]);
    if (!firstIsNumber) {
      return _ParsedIngredient(quantity: '', name: malzeme);
    }

    const units = {
      'adet', 'su', 'yemek', 'çay', 'tatlı', 'bardak', 'bardağı',
      'kaşığı', 'kaşık', 'tutam', 'demet', 'dilim', 'diş', 'gram',
      'kg', 'ml', 'lt', 'litre', 'paket', 'dal', 'yaprak', 'avuç',
    };

    var splitAt = 1;
    for (var i = 1; i < parts.length; i++) {
      if (units.contains(parts[i].toLowerCase())) {
        splitAt = i + 1;
      } else {
        break;
      }
    }

    final quantity = parts.sublist(0, splitAt).join(' ');
    final name = parts.sublist(splitAt).join(' ');

    if (name.isEmpty) {
      return _ParsedIngredient(quantity: '', name: malzeme);
    }

    return _ParsedIngredient(quantity: quantity, name: name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isCreating
                ? _buildCreator(l10n)
                : _buildSavedLists(l10n),
      ),
    );
  }

  // ─── Kaydedilmiş Listeler ─────────────────────────────

  void _toggleListSelection(String listId) {
    setState(() {
      if (_selectedListIds.contains(listId)) {
        _selectedListIds.remove(listId);
      } else {
        _selectedListIds.add(listId);
      }
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _deleteSelectedLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = context.read<FirestoreService>();

    for (final id in _selectedListIds) {
      await firestore.deleteShoppingList(user.uid, id);
    }

    RemoteLoggerService.userAction('shopping_lists_deleted',
        screen: 'shopping', details: {'count': _selectedListIds.length});

    setState(() => _selectedListIds.clear());
    _loadSavedLists();
  }

  Future<void> _completeSelectedLists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final firestore = context.read<FirestoreService>();
    final lists = _savedLists ?? [];

    for (final id in _selectedListIds) {
      final list = lists.firstWhere((l) => l.id == id, orElse: () => lists.first);
      if (list.id != id) continue;
      final updatedItems = list.items
          .map((e) => ShoppingItem(name: e.name, quantity: e.quantity, checked: true))
          .toList();
      await firestore.updateShoppingListItems(user.uid, id, updatedItems);
    }

    RemoteLoggerService.userAction('shopping_lists_completed',
        screen: 'shopping', details: {'count': _selectedListIds.length});

    setState(() => _selectedListIds.clear());
    _loadSavedLists();
  }

  Widget _buildSavedLists(AppLocalizations l10n) {
    final lists = _savedLists ?? [];

    return Column(
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
          child: Row(
            children: [
              if (_isSelecting) ...[
                GestureDetector(
                  onTap: () => setState(() => _selectedListIds.clear()),
                  child: Icon(Icons.close_rounded,
                      color: AppColors.charcoal.withValues(alpha: 0.6)),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_selectedListIds.length} seçili',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                ),
              ] else ...[
                Text(
                  l10n.shoppingTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                      ),
                ),
              ],
              const Spacer(),
              if (!_isSelecting)
                FilledButton.icon(
                  onPressed: _startCreating,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.shoppingNewList,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Liste
        Expanded(
          child: lists.isEmpty
              ? _buildEmptyLists(l10n)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: lists.length,
                  itemBuilder: (ctx, i) => _buildListCard(lists[i]),
                ),
        ),
        // Seçim modu aksiyonları
        if (_isSelecting) _buildSelectionActions(l10n),
      ],
    );
  }

  Widget _buildSelectionActions(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Tamamla butonu
            Expanded(
              child: FilledButton.icon(
                onPressed: _completeSelectedLists,
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Tamamla',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Sil butonu
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _deleteSelectedLists,
                icon: Icon(Icons.delete_outline_rounded,
                    size: 20, color: Colors.red.shade400),
                label: Text('Sil',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.red.shade400)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLists(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🛒', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              l10n.shoppingEmptyPlan,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _startCreating,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.shoppingNewList),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(ShoppingList list) {
    final progress =
        list.items.isEmpty ? 0.0 : list.checkedCount / list.items.length;
    final dateStr =
        '${list.createdAt.day}.${list.createdAt.month.toString().padLeft(2, '0')}.${list.createdAt.year}';
    final isSelected = _selectedListIds.contains(list.id);

    return GestureDetector(
      onTap: () async {
        if (_isSelecting) {
          _toggleListSelection(list.id);
          return;
        }
        final deleted = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => ShoppingDetailScreen(shoppingList: list),
          ),
        );
        if (deleted == true || mounted) _loadSavedLists();
      },
      onLongPress: () => _toggleListSelection(list.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Seçim modu checkbox
                if (_isSelecting) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: isSelected
                          ? null
                          : Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 10),
                ],
                // İkon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🛒', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        list.title,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr  •  ${list.items.length} malzeme',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                      ),
                    ],
                  ),
                ),
                // İlerleme badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: progress >= 1.0
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.charcoal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${list.checkedCount}/${list.items.length}',
                    style: TextStyle(
                      color: progress >= 1.0
                          ? AppColors.primary
                          : AppColors.charcoal.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.charcoal.withValues(alpha: 0.2)),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.charcoal.withValues(alpha: 0.06),
                color: progress >= 1.0
                    ? AppColors.primary
                    : AppColors.secondary,
                minHeight: 4,
              ),
            ),
            // Öğün etiketleri
            if (list.selectedMeals.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: list.selectedMeals.take(4).map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.split(' - ').last,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Yeni Liste Oluşturma ──────────────────────────────

  Widget _buildCreator(AppLocalizations l10n) {
    if (_plan == null) {
      return _buildEmptyLists(l10n);
    }

    final allCount =
        _plan!.gunler.fold<int>(0, (sum, d) => sum + d.ogunler.length);
    final allSelected = _selectedSlots.length == allCount;

    return Column(
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isCreating = false),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(
                    foregroundColor: AppColors.charcoal),
              ),
              Text(
                l10n.shoppingSelectMeals,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
              ),
              const Spacer(),
              TextButton(
                onPressed: allSelected ? _deselectAll : _selectAll,
                child: Text(
                  allSelected
                      ? l10n.shoppingDeselectAll
                      : l10n.shoppingSelectAll,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Günler
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: _plan!.gunler.length,
            itemBuilder: (ctx, dayIndex) =>
                _buildDayCard(dayIndex, l10n),
          ),
        ),
        // Oluştur butonu
        _buildGenerateButton(l10n),
      ],
    );
  }

  Widget _buildDayCard(int dayIndex, AppLocalizations l10n) {
    final day = _plan!.gunler[dayIndex];
    final daySlots = day.ogunler.keys.map((k) => '${dayIndex}_$k').toSet();
    final selectedCount = daySlots.where(_selectedSlots.contains).length;
    final allSelected = selectedCount == daySlots.length;

    final slots = day.ogunler.entries.toList()
      ..sort((a, b) => _slotOrder(a.key).compareTo(_slotOrder(b.key)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          // Gün başlığı
          InkWell(
            onTap: () => _toggleDay(dayIndex),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: allSelected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: allSelected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : Text(
                              day.gun.split('-').last,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          day.gunAdi,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                        ),
                        Text(
                          '$selectedCount / ${slots.length} öğün seçili',
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
                    ),
                  ),
                  if (selectedCount > 0 && !allSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedCount',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Öğünler
          ...slots.map((entry) {
            final slotKey = entry.key;
            final recipes = entry.value;
            final isSelected =
                _selectedSlots.contains('${dayIndex}_$slotKey');
            final recipeNames = recipes.map((r) => r.yemekAdi).join(', ');
            final totalMalzeme = recipes.fold<int>(0, (s, r) => s + r.malzemeler.length);

            return InkWell(
              onTap: () => _toggleSlot(dayIndex, slotKey),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: AppColors.border, width: 1.5),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(_slotEmoji(slotKey),
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recipeNames,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? AppColors.charcoal
                                        : AppColors.charcoal
                                            .withValues(alpha: 0.5),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (totalMalzeme > 0)
                              Text(
                                '$totalMalzeme malzeme',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.charcoal
                                          .withValues(alpha: 0.35),
                                      fontSize: 11,
                                    ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(AppLocalizations l10n) {
    final hasSelection = _selectedSlots.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: hasSelection ? _generateAndSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.charcoal.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.shopping_cart_outlined, size: 20),
            label: Text(
              hasSelection
                  ? '${l10n.shoppingGenerateList} (${_selectedSlots.length})'
                  : l10n.shoppingNoSelection,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Yardımcılar ────────────────────────────────────────

  static int _slotOrder(String slot) {
    const order = {
      'kahvalti': 0, 'ara_ogun_1': 1, 'ogle': 2,
      'ara_ogun_2': 3, 'ara_ogun': 4, 'aksam': 5,
      'atistirmalik': 6, 'ana_ogun_1': 1, 'ana_ogun_2': 3,
    };
    final base = slot.replaceAll(RegExp(r'_\d+$'), '');
    return order[slot] ?? order[base] ?? 99;
  }

  static String _slotEmoji(String slot) {
    final base = slot.replaceAll(RegExp(r'_\d+$'), '');
    switch (base) {
      case 'kahvalti': return '🌅';
      case 'ogle': return '☀️';
      case 'aksam': return '🌙';
      case 'ara_ogun_1':
      case 'ara_ogun_2':
      case 'ara_ogun':
      case 'atistirmalik': return '🍎';
      default: return '🍽️';
    }
  }
}

class _ParsedIngredient {
  final String quantity;
  final String name;
  const _ParsedIngredient({required this.quantity, required this.name});
}

class _NewListOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NewListOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.charcoal.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                AppColors.charcoal.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.charcoal.withValues(alpha: 0.3), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
