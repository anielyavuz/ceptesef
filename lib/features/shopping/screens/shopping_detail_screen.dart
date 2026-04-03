import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/remote_logger_service.dart';
import 'price_comparison_screen.dart';

/// Kaydedilmiş alışveriş listesi detay ekranı.
class ShoppingDetailScreen extends StatefulWidget {
  final ShoppingList shoppingList;

  const ShoppingDetailScreen({super.key, required this.shoppingList});

  @override
  State<ShoppingDetailScreen> createState() => _ShoppingDetailScreenState();
}

class _ShoppingDetailScreenState extends State<ShoppingDetailScreen> {
  late List<ShoppingItem> _items;
  bool _hasChanges = false;
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('shopping_detail');
    // Deep copy
    _items = widget.shoppingList.items
        .map((e) => ShoppingItem(
            name: e.name, quantity: e.quantity, checked: e.checked))
        .toList();
  }

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index].checked = !_items[index].checked;
      _hasChanges = true;
    });
    HapticFeedback.selectionClick();
  }

  void _addItem() {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    final parsed = _parseInput(text);
    setState(() {
      _items.insert(0, ShoppingItem(name: parsed.name, quantity: parsed.quantity));
      _hasChanges = true;
    });
    _addController.clear();
    _save();
    HapticFeedback.lightImpact();
  }

  void _removeItem(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
      _hasChanges = true;
    });
    _save();
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removed.displayText} ${l10n.shoppingItemDeleted.toLowerCase()}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.charcoal,
        action: SnackBarAction(
          label: 'Geri Al',
          textColor: AppColors.primary,
          onPressed: () {
            setState(() {
              _items.insert(index, removed);
              _hasChanges = true;
            });
            _save();
          },
        ),
      ),
    );
  }

  /// Girilen metni miktar + isim olarak parse eder
  /// "2 kg domates" → quantity: "2 kg", name: "domates"
  /// "domates" → quantity: "", name: "domates"
  _ParsedInput _parseInput(String text) {
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length < 2) return _ParsedInput(name: text, quantity: '');

    // İlk kısım sayısal mı?
    final firstIsNum = RegExp(r'^\d').hasMatch(parts[0]);
    if (!firstIsNum) return _ParsedInput(name: text, quantity: '');

    // Bilinen birimler
    const units = ['kg', 'gr', 'g', 'lt', 'ml', 'adet', 'demet', 'paket',
      'poşet', 'kutu', 'şişe', 'kavanoz', 'bardak', 'kaşık', 'dilim', 'tane'];

    if (parts.length >= 3) {
      final secondIsUnit = units.contains(parts[1].toLowerCase());
      if (secondIsUnit) {
        return _ParsedInput(
          quantity: '${parts[0]} ${parts[1]}',
          name: parts.sublist(2).join(' '),
        );
      }
    }
    return _ParsedInput(
      quantity: parts[0],
      name: parts.sublist(1).join(' '),
    );
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await context.read<FirestoreService>().updateShoppingListItems(
          user.uid, widget.shoppingList.id, _items);
      _hasChanges = false;
    } catch (_) {}
  }

  void _shareList() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 ${widget.shoppingList.title}');
    buffer.writeln('─' * 20);
    for (final item in _items) {
      final check = item.checked ? '✅' : '⬜';
      buffer.writeln('$check ${item.displayText}');
    }
    buffer.writeln();
    buffer.writeln('📱 Cepte Şef ile oluşturuldu');

    SharePlus.instance.share(ShareParams(text: buffer.toString()));

    RemoteLoggerService.userAction('shopping_list_shared',
        screen: 'shopping_detail');
  }

  void _copyList() {
    final buffer = StringBuffer();
    for (final item in _items) {
      buffer.writeln(item.checked ? '✓ ${item.displayText}' : item.displayText);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.shoppingCopied),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _deleteList() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l10n.shoppingDeleteTitle),
        content: Text(l10n.shoppingDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.homeDailyDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.homeDailyDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await context
        .read<FirestoreService>()
        .deleteShoppingList(user.uid, widget.shoppingList.id);

    if (mounted) Navigator.pop(context, true); // true = silindi
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final checkedCount = _items.where((i) => i.checked).length;
    final progress = _items.isEmpty ? 0.0 : checkedCount / _items.length;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (_hasChanges) _save();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.charcoal,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.shoppingList.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text(
                l10n.shoppingItemCount(_items.length),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: _copyList,
              icon: const Icon(Icons.copy_rounded, size: 20),
              tooltip: 'Kopyala',
            ),
            IconButton(
              onPressed: _shareList,
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: 'Paylaş',
            ),
            IconButton(
              onPressed: _deleteList,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              style: IconButton.styleFrom(
                  foregroundColor: Colors.red.withValues(alpha: 0.7)),
              tooltip: 'Sil',
            ),
          ],
        ),
        body: Column(
          children: [
            // İlerleme
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor:
                            AppColors.charcoal.withValues(alpha: 0.06),
                        color: AppColors.primary,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$checkedCount / ${_items.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
            // Seçilen öğünler
            if (widget.shoppingList.selectedMeals.isNotEmpty)
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                  itemCount: widget.shoppingList.selectedMeals.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.shoppingList.selectedMeals[i],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                      ),
                    );
                  },
                ),
              ),
            // Fiyat karşılaştırma butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    RemoteLoggerService.userAction(
                        'price_comparison_tapped',
                        screen: 'shopping_detail');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PriceComparisonScreen(
                          items: _items,
                          mealContext: widget.shoppingList.selectedMeals,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.price_check_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.priceComparisonButton,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.charcoal)),
                              Text(
                                l10n.priceComparisonButtonDesc,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color:
                                AppColors.charcoal.withValues(alpha: 0.25),
                            size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Liste
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: _items.length,
                itemBuilder: (ctx, i) {
                  final item = _items[i];
                  return Dismissible(
                    key: ValueKey('item_${i}_${item.name}'),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) async {
                      _removeItem(i);
                      return false;
                    },
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: Icon(Icons.delete_outline_rounded,
                          color: Colors.red.withValues(alpha: 0.6), size: 22),
                    ),
                    child: InkWell(
                      onTap: () => _toggleItem(i),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 11),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: item.checked
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                                border: item.checked
                                    ? null
                                    : Border.all(
                                        color: AppColors.border, width: 1.5),
                              ),
                              child: item.checked
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                item.displayText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: item.checked
                                          ? AppColors.charcoal
                                              .withValues(alpha: 0.3)
                                          : AppColors.charcoal,
                                      fontWeight: FontWeight.w500,
                                      decoration: item.checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: AppColors.charcoal
                                          .withValues(alpha: 0.3),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Malzeme ekleme input alanı
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 8, 8 + MediaQuery.of(context).viewPadding.bottom),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      focusNode: _addFocusNode,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _addItem(),
                      decoration: InputDecoration(
                        hintText: l10n.shoppingAddItemHint,
                        hintStyle: TextStyle(
                          color: AppColors.charcoal.withValues(alpha: 0.3),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppColors.charcoal.withValues(alpha: 0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _addItem,
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.add_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParsedInput {
  final String name;
  final String quantity;
  const _ParsedInput({required this.name, required this.quantity});
}
