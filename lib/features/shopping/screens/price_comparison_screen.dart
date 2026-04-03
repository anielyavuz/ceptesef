import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/models/market_price.dart';
import '../../../core/models/shopping_list.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/market_price_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Fiyat karşılaştırma ve akıllı market gruplandırma ekranı.
class PriceComparisonScreen extends StatefulWidget {
  final List<ShoppingItem> items;
  final List<String> mealContext;

  const PriceComparisonScreen({
    super.key,
    required this.items,
    this.mealContext = const [],
  });

  @override
  State<PriceComparisonScreen> createState() => _PriceComparisonScreenState();
}

enum _ViewMode { optimal, byMarket, byItem }

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  List<IngredientPriceResult> _priceResults = [];
  bool _loading = true;
  String? _error;
  _ViewMode _viewMode = _ViewMode.optimal;
  DateTime? _dataDate;

  // Market filtresi
  List<String> _selectedMarkets = [];
  static const _allMarkets = [
    ('a101', 'A101'),
    ('bim', 'BİM'),
    ('carrefour', 'CarrefourSA'),
    ('hakmar', 'Hakmar'),
    ('migros', 'Migros'),
    ('tarim_kredi', 'Tarım Kredi'),
    ('sok', 'ŞOK'),
  ];

  // Arama
  bool _searchMode = false;
  final _searchController = TextEditingController();
  List<IngredientPriceResult> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('price_comparison');
    RemoteLoggerService.info('price_comparison_opened',
        extra: {'itemCount': widget.items.length});
    _loadMarketPrefs();
    _fetchPrices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMarketPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs =
        await context.read<FirestoreService>().getUserPreferences(uid);
    if (prefs != null && prefs.preferredMarkets.isNotEmpty && mounted) {
      setState(() => _selectedMarkets = List.from(prefs.preferredMarkets));
      _fetchPrices(); // Filtreli yeniden çek
    }
  }

  Future<void> _saveMarketPrefs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final firestore = context.read<FirestoreService>();
    final prefs = await firestore.getUserPreferences(uid);
    if (prefs != null) {
      await firestore.saveUserPreferences(
          uid, prefs.copyWith(preferredMarkets: _selectedMarkets));
    }
  }

  Future<void> _fetchPrices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<MarketPriceService>();
      final uncheckedItems =
          widget.items.where((item) => !item.checked).toList();
      final names = uncheckedItems.map((e) => e.name).toList();
      final results = await service.getIngredientPrices(
        names,
        mealContext: widget.mealContext,
        preferredMarkets: _selectedMarkets,
      );
      if (mounted) {
        setState(() {
          _priceResults = results;
          _dataDate = service.dataDate;
          _loading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('price_comparison_error', error: e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final service = context.read<MarketPriceService>();
      final results = await service.searchProducts(query,
          preferredMarkets: _selectedMarkets);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _searching = false);
    }
  }

  int get _foundCount =>
      _priceResults.where((r) => r.products.isNotEmpty).length;

  double get _optimalTotal {
    final groups = MarketPriceService.groupByOptimalMarket(_priceResults);
    return groups.fold(0, (total, g) => total + g.totalPrice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        title: _searchMode
            ? _buildSearchBar()
            : Text(l10n.priceComparisonTitle,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          // Arama
          IconButton(
            onPressed: () {
              setState(() {
                _searchMode = !_searchMode;
                if (!_searchMode) {
                  _searchController.clear();
                  _searchResults = [];
                }
              });
            },
            icon: Icon(
                _searchMode
                    ? Icons.close_rounded
                    : Icons.search_rounded,
                size: 20,
                color: AppColors.charcoal.withValues(alpha: 0.5)),
          ),
          // Market filtre
          IconButton(
            onPressed: _showMarketFilter,
            icon: Badge(
              isLabelVisible: _selectedMarkets.isNotEmpty,
              label: Text('${_selectedMarkets.length}',
                  style: const TextStyle(fontSize: 9)),
              backgroundColor: AppColors.primary,
              child: Icon(Icons.filter_list_rounded,
                  size: 20,
                  color: _selectedMarkets.isNotEmpty
                      ? AppColors.primary
                      : AppColors.charcoal.withValues(alpha: 0.5)),
            ),
          ),
          // Info
          IconButton(
            onPressed: _showDisclaimer,
            icon: Icon(Icons.info_outline_rounded,
                size: 20,
                color: AppColors.charcoal.withValues(alpha: 0.4)),
            tooltip: l10n.priceComparisonDisclaimerTitle,
          ),
        ],
      ),
      body: _searchMode
          ? _buildSearchContent()
          : _loading
              ? _buildLoading()
              : _error != null
                  ? _buildError()
                  : _buildContent(),
    );
  }

  // ─── Arama ──────────────────────────────────────────────

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _doSearch(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Ürün ara (ör: süt, tavuk)...',
        hintStyle:
            TextStyle(color: AppColors.charcoal.withValues(alpha: 0.3)),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        suffixIcon: IconButton(
          onPressed: _doSearch,
          icon: const Icon(Icons.arrow_forward_rounded,
              color: AppColors.primary, size: 20),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_searching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('Sonuç bulunamadı',
            style: TextStyle(
                color: AppColors.charcoal.withValues(alpha: 0.4))),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                size: 48,
                color: AppColors.charcoal.withValues(alpha: 0.12)),
            const SizedBox(height: 12),
            Text('Ürün adı yazıp arayın',
                style: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.35),
                    fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) => _buildItemDetailCard(_searchResults[i]),
    );
  }

  // ─── Market Filtre ─────────────────────────────────────

  void _showMarketFilter() {
    final tempSelected = List<String>.from(_selectedMarkets);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.store_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Market Filtresi',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const Spacer(),
                  if (tempSelected.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setSheetState(() => tempSelected.clear()),
                      child: const Text('Temizle',
                          style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Boş bırakırsan tüm marketler gösterilir',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.charcoal.withValues(alpha: 0.4)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allMarkets.map((m) {
                  final key = m.$1;
                  final label = m.$2;
                  final selected = tempSelected.contains(key);
                  return FilterChip(
                    label: Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : AppColors.charcoal)),
                    selected: selected,
                    onSelected: (val) {
                      setSheetState(() {
                        if (val) {
                          tempSelected.add(key);
                        } else {
                          tempSelected.remove(key);
                        }
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor:
                        AppColors.charcoal.withValues(alpha: 0.04),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() =>
                        _selectedMarkets = List.from(tempSelected));
                    _saveMarketPrefs();
                    _fetchPrices();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Uygula',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
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
            'Fiyatlar karşılaştırılıyor...',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.charcoal.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDisclaimer() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
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
                color: AppColors.charcoal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.verified_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.priceComparisonDisclaimerTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
            ),
            // İçerik
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Text(
                  l10n.priceComparisonDisclaimer,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: AppColors.charcoal.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.charcoal.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(l10n.priceComparisonError,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _fetchPrices,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context);
    final hasResults = _foundCount > 0;

    return Column(
      children: [
        // Özet kartı
        if (hasResults) _buildSummaryCard(),
        // Veri kaynağı + tarih
        if (hasResults)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Row(
              children: [
                Icon(Icons.update_rounded,
                    size: 13,
                    color: AppColors.charcoal.withValues(alpha: 0.25)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _buildLastUpdateText(l10n),
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.charcoal.withValues(alpha: 0.3)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showDisclaimer,
                  child: Row(
                    children: [
                      Text(
                        l10n.priceComparisonDataSource,
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.charcoal.withValues(alpha: 0.3)),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.info_outline_rounded,
                          size: 12,
                          color: AppColors.charcoal.withValues(alpha: 0.25)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Görünüm seçici
        if (hasResults) _buildViewModeSelector(),
        // İçerik
        Expanded(
          child: hasResults
              ? _buildListContent()
              : _buildEmptyState(l10n),
        ),
      ],
    );
  }

  String _buildLastUpdateText(AppLocalizations l10n) {
    final date = _dataDate ?? DateTime.now();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataDay = DateTime(date.year, date.month, date.day);
    final daysAgo = today.difference(dataDay).inDays;

    final dateStr = DateFormat('dd.MM.yyyy').format(date);
    final base = l10n.priceComparisonLastUpdate(dateStr);

    if (daysAgo <= 0) {
      return base;
    } else if (daysAgo == 1) {
      return '$base ${l10n.priceComparisonLastUpdateYesterday}';
    } else {
      return '$base ${l10n.priceComparisonLastUpdateDaysAgo(daysAgo)}';
    }
  }

  Widget _buildSummaryCard() {
    final l10n = AppLocalizations.of(context);
    final groups = MarketPriceService.groupByOptimalMarket(_priceResults);
    final total = _optimalTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.price_check_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(l10n.priceComparisonOptimalPlan,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.priceComparisonEstimatedTotal,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('₺${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 24)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l10n.priceComparisonFoundCount(
                        _foundCount, _priceResults.length),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.priceComparisonMarketCount(groups.length),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector() {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        children: [
          _viewModeChip(
            label: l10n.priceComparisonViewOptimal,
            icon: Icons.auto_awesome_rounded,
            mode: _ViewMode.optimal,
          ),
          const SizedBox(width: 8),
          _viewModeChip(
            label: l10n.priceComparisonViewByMarket,
            icon: Icons.store_rounded,
            mode: _ViewMode.byMarket,
          ),
          const SizedBox(width: 8),
          _viewModeChip(
            label: l10n.priceComparisonViewByItem,
            icon: Icons.list_rounded,
            mode: _ViewMode.byItem,
          ),
        ],
      ),
    );
  }

  Widget _viewModeChip({
    required String label,
    required IconData icon,
    required _ViewMode mode,
  }) {
    final selected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _viewMode = mode);
        RemoteLoggerService.userAction('price_view_mode_changed',
            screen: 'price_comparison',
            details: {'mode': mode.name});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.charcoal.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected
                    ? Colors.white
                    : AppColors.charcoal.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? Colors.white
                        : AppColors.charcoal.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent() {
    switch (_viewMode) {
      case _ViewMode.optimal:
        return _buildOptimalView();
      case _ViewMode.byMarket:
        return _buildByMarketView();
      case _ViewMode.byItem:
        return _buildByItemView();
    }
  }

  // ─── 1) Akıllı Öneri Görünümü ─────────────────────────
  Widget _buildOptimalView() {
    final groups = MarketPriceService.groupByOptimalMarket(_priceResults);
    final notFound =
        _priceResults.where((r) => r.products.isEmpty).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: groups.length + (notFound.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < groups.length) {
          return _buildMarketGroupCard(groups[i], i);
        }
        return _buildNotFoundCard(notFound);
      },
    );
  }

  Widget _buildMarketGroupCard(MarketGroup group, int index) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.accent,
      const Color(0xFF5B8DEF),
      const Color(0xFF9B59B6),
      const Color(0xFF1ABC9C),
    ];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        children: [
          // Market başlığı
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.store_rounded, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.marketDisplayName,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: color)),
                      Text(
                        '${group.items.length} ürün',
                        style: TextStyle(
                            fontSize: 11,
                            color: color.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₺${group.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: color),
                ),
              ],
            ),
          ),
          // Ürünler
          ...group.items.map((item) => _buildGroupItemTile(item)),
        ],
      ),
    );
  }

  Widget _buildGroupItemTile(MarketGroupItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Ürün görseli
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.imageUrl!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.shopping_basket_rounded,
                      size: 18,
                      color: AppColors.charcoal.withValues(alpha: 0.2)),
                ),
              ),
            )
          else
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.charcoal.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.shopping_basket_rounded,
                  size: 18,
                  color: AppColors.charcoal.withValues(alpha: 0.2)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(item.ingredientName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                    if (_isOnlyProcessed(item.ingredientName)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('~',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary)),
                      ),
                    ],
                  ],
                ),
                Text(
                  item.productTitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.charcoal.withValues(alpha: 0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.weightLabel != null)
                  Text(item.weightLabel!,
                      style: TextStyle(
                          fontSize: 10,
                          color:
                              AppColors.charcoal.withValues(alpha: 0.35))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₺${item.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              if (item.unitPrice != null)
                Text(item.unitPrice!,
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.charcoal.withValues(alpha: 0.4))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotFoundCard(List<IngredientPriceResult> notFound) {
    final l10n = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.charcoal.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded,
                  size: 18,
                  color: AppColors.charcoal.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              Text(l10n.priceComparisonNotFound,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.charcoal.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: notFound.map((r) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.charcoal.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(r.ingredientName,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.charcoal.withValues(alpha: 0.5))),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── 2) Market Bazlı Görünüm (tek marketten hepsini al) ────
  Widget _buildByMarketView() {
    final totals =
        MarketPriceService.calculateSingleMarketTotals(_priceResults);
    if (totals.isEmpty) {
      return _buildEmptyState(AppLocalizations.of(context));
    }

    // Marketleri en ucuzdan sırala
    final sortedMarkets = totals.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final cheapestTotal = sortedMarkets.first.value;

    // Her market için ürün detaylarını hesapla
    final Map<String, List<_MarketItemDetail>> marketDetails = {};
    for (final market in sortedMarkets) {
      final items = <_MarketItemDetail>[];
      for (final result in _priceResults) {
        if (result.products.isEmpty) continue;
        // Bu marketteki en ucuz ürünü bul
        double? cheapest;
        String? productTitle;
        for (final product in result.products) {
          for (final offer in product.markets) {
            if (offer.marketName == market.key) {
              if (cheapest == null || offer.price < cheapest) {
                cheapest = offer.price;
                productTitle = product.title;
              }
            }
          }
        }
        if (cheapest != null) {
          items.add(_MarketItemDetail(
            ingredientName: result.ingredientName,
            productTitle: productTitle ?? '',
            price: cheapest,
          ));
        }
      }
      marketDetails[market.key] = items;
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sortedMarkets.length,
      itemBuilder: (ctx, i) {
        final entry = sortedMarkets[i];
        final isCheapest = i == 0;
        final diff = entry.value - cheapestTotal;
        final displayName = _getMarketDisplayName(entry.key);
        final items = marketDetails[entry.key] ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isCheapest
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(context)
                .copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding:
                  const EdgeInsets.only(left: 14, right: 14, bottom: 12),
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCheapest
                      ? AppColors.primary
                      : AppColors.charcoal.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isCheapest
                        ? Colors.white
                        : AppColors.charcoal.withValues(alpha: 0.4),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  if (isCheapest) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        AppLocalizations.of(context)
                            .priceComparisonCheapest,
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: !isCheapest
                  ? Text('+₺${diff.toStringAsFixed(2)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.accent.withValues(alpha: 0.8)))
                  : Text('${items.length} ürün',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary.withValues(alpha: 0.7))),
              trailing: Text(
                '₺${entry.value.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color:
                      isCheapest ? AppColors.primary : AppColors.charcoal,
                ),
              ),
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.ingredientName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12)),
                            Text(item.productTitle,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.45)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Text('₺${item.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  // ─── 3) Malzeme Bazlı Görünüm ─────────────────────────
  Widget _buildByItemView() {
    final resultsWithProducts =
        _priceResults.where((r) => r.products.isNotEmpty).toList();
    final notFound =
        _priceResults.where((r) => r.products.isEmpty).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: resultsWithProducts.length + (notFound.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i < resultsWithProducts.length) {
          return _buildItemDetailCard(resultsWithProducts[i]);
        }
        return _buildNotFoundCard(notFound);
      },
    );
  }

  Widget _buildItemDetailCard(IngredientPriceResult result) {
    // En ucuz ürünü bul
    final allOffers = <_FlatOffer>[];
    for (final product in result.products) {
      for (final market in product.markets) {
        allOffers.add(_FlatOffer(
          product: product,
          offer: market,
        ));
      }
    }
    allOffers.sort((a, b) => a.offer.price.compareTo(b.offer.price));

    // En fazla 5 teklif göster
    final displayOffers = allOffers.take(5).toList();
    final cheapestPrice =
        displayOffers.isNotEmpty ? displayOffers.first.offer.price : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_basket_rounded,
                color: AppColors.primary, size: 18),
          ),
          title: Text(result.ingredientName,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(
            result.cheapestMarket != null
                ? '${result.cheapestMarket} — ₺${result.cheapestPrice?.toStringAsFixed(2)}'
                : '',
            style: TextStyle(
                fontSize: 12,
                color: AppColors.primary.withValues(alpha: 0.8)),
          ),
          children: displayOffers.map((flat) {
            final isCheap = flat.offer.price == cheapestPrice;
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  // Market badge
                  Container(
                    width: 56,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCheap
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.charcoal.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      flat.offer.displayName,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isCheap
                            ? AppColors.primary
                            : AppColors.charcoal.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      flat.product.title,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₺${flat.offer.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isCheap
                          ? AppColors.primary
                          : AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.price_check_rounded,
                size: 48,
                color: AppColors.charcoal.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(l10n.priceComparisonEmpty,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.4),
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }

  /// Bu malzeme için sadece işlenmiş alternatif mi var?
  bool _isOnlyProcessed(String ingredientName) {
    for (final r in _priceResults) {
      if (r.ingredientName == ingredientName) return r.onlyProcessed;
    }
    return false;
  }

  /// Market adı lookup helper
  String _getMarketDisplayName(String marketName) {
    // Bilinen marketlerin görüntü adlarını ürün verilerinden bul
    for (final result in _priceResults) {
      for (final product in result.products) {
        for (final market in product.markets) {
          if (market.marketName == marketName) {
            return market.displayName;
          }
        }
      }
    }
    return marketName.toUpperCase();
  }
}

class _FlatOffer {
  final MarketProduct product;
  final MarketOffer offer;
  const _FlatOffer({required this.product, required this.offer});
}

class _MarketItemDetail {
  final String ingredientName;
  final String productTitle;
  final double price;
  const _MarketItemDetail({
    required this.ingredientName,
    required this.productTitle,
    required this.price,
  });
}
