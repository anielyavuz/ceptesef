import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Onboarding Adım 1: Mutfak tercihleri
/// Pinterest tarzı masonry grid — 25 kategori
class CuisineStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const CuisineStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(String id) {
    final list = List<String>.from(selected);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    onChanged(list);
  }

  List<_CuisineItem> _buildCuisines(AppLocalizations l10n) {
    return [
      _CuisineItem('turk', l10n.cuisineTurkish, '🍳', const Color(0xFFD84315), const Color(0xFFBF360C)),
      _CuisineItem('ev_yemekleri', l10n.cuisineHomeCooking, '🍲', const Color(0xFF5D4037), const Color(0xFF3E2723)),
      _CuisineItem('akdeniz', l10n.cuisineMediterranean, '🫒', const Color(0xFF2E7D32), const Color(0xFF1B5E20)),
      _CuisineItem('izgara', l10n.cuisineGrill, '🥩', const Color(0xFF8D6E63), const Color(0xFF4E342E)),
      _CuisineItem('italyan', l10n.cuisineItalian, '🍝', const Color(0xFFC62828), const Color(0xFF8E0000)),
      _CuisineItem('uzak_dogu', l10n.cuisineAsian, '🥢', const Color(0xFFD32F2F), const Color(0xFFB71C1C)),
      _CuisineItem('meksika', l10n.cuisineMexican, '🌮', const Color(0xFFEF6C00), const Color(0xFFE65100)),
      _CuisineItem('fast_food', l10n.cuisineFastFood, '🍔', const Color(0xFFF9A825), const Color(0xFFF57F17)),
      _CuisineItem('deniz_urunleri', l10n.cuisineSeafood, '🦐', const Color(0xFF00838F), const Color(0xFF006064)),
      _CuisineItem('sokak_lezzetleri', l10n.cuisineStreetFood, '🌯', const Color(0xFFE65100), const Color(0xFFBF360C)),
      _CuisineItem('fit', l10n.cuisineHealthy, '🥑', const Color(0xFF558B2F), const Color(0xFF33691E)),
      _CuisineItem('vegan_mutfagi', l10n.cuisineVegan, '🌱', const Color(0xFF388E3C), const Color(0xFF1B5E20)),
      _CuisineItem('tatlilar', l10n.cuisineDesserts, '🍰', const Color(0xFF8E24AA), const Color(0xFF6A1B9A)),
      _CuisineItem('corbalar', l10n.cuisineSoups, '🍜', const Color(0xFF6D4C41), const Color(0xFF3E2723)),
      _CuisineItem('salata', l10n.cuisineSalads, '🥗', const Color(0xFF43A047), const Color(0xFF2E7D32)),
      _CuisineItem('hamur_isi', l10n.cuisinePastry, '🥟', const Color(0xFFD4A056), const Color(0xFFB07D3B)),
      _CuisineItem('fransiz', l10n.cuisineFrench, '🥐', const Color(0xFF5C6BC0), const Color(0xFF3949AB)),
      _CuisineItem('ortadogu', l10n.cuisineMiddleEast, '🧆', const Color(0xFFFF8F00), const Color(0xFFFF6F00)),
      _CuisineItem('one_pot', l10n.cuisineOnePot, '🫕', const Color(0xFF00897B), const Color(0xFF00695C)),
      _CuisineItem('dunya', l10n.cuisineWorld, '🌍', const Color(0xFF1565C0), const Color(0xFF0D47A1)),
      _CuisineItem('aperatif', l10n.cuisineSnacks, '🧀', const Color(0xFFAB47BC), const Color(0xFF7B1FA2)),
      _CuisineItem('bebek_cocuk', l10n.cuisineKids, '👶', const Color(0xFF42A5F5), const Color(0xFF1E88E5)),
      _CuisineItem('glutensiz', l10n.cuisineGlutenFree, '🌾', const Color(0xFF78909C), const Color(0xFF546E7A)),
      _CuisineItem('hizli_kahvalti', l10n.cuisineQuickBreakfast, '🥤', const Color(0xFFEC407A), const Color(0xFFC2185B)),
      _CuisineItem('guney_amerika', l10n.cuisineSouthAmerican, '🫔', const Color(0xFF66BB6A), const Color(0xFF388E3C)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cuisines = _buildCuisines(l10n);

    // Masonry: 2 sütun, alternatif yükseklikler
    final leftIndices = <int>[];
    final rightIndices = <int>[];
    for (var i = 0; i < cuisines.length; i++) {
      if (i % 2 == 0) {
        leftIndices.add(i);
      } else {
        rightIndices.add(i);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingCuisineTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingCuisineSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 6),
          // Seçim sayacı
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected.isNotEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    key: ValueKey(selected.length),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${selected.length} / ${cuisines.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey(0)),
          ),
          const SizedBox(height: 16),
          // Pinterest masonry layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol sütun
              Expanded(
                child: Column(
                  children: List.generate(leftIndices.length, (i) {
                    final item = cuisines[leftIndices[i]];
                    final isTall = i % 3 == 0; // her 3. kart uzun
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PinterestCard(
                        item: item,
                        height: isTall ? 128 : 106,
                        isSelected: selected.contains(item.id),
                        onTap: () => _toggle(item.id),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 12),
              // Sağ sütun — Pinterest offset
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: List.generate(rightIndices.length, (i) {
                      final item = cuisines[rightIndices[i]];
                      final isTall = i % 3 == 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PinterestCard(
                          item: item,
                          height: isTall ? 128 : 106,
                          isSelected: selected.contains(item.id),
                          onTap: () => _toggle(item.id),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CuisineItem {
  final String id;
  final String label;
  final String emoji;
  final Color colorStart;
  final Color colorEnd;

  const _CuisineItem(this.id, this.label, this.emoji, this.colorStart, this.colorEnd);
}

class _PinterestCard extends StatelessWidget {
  final _CuisineItem item;
  final double height;
  final bool isSelected;
  final VoidCallback onTap;

  const _PinterestCard({
    required this.item,
    required this.height,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [item.colorStart, item.colorEnd],
          ),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: Colors.white, width: 3)
              : null,
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? item.colorStart.withValues(alpha: 0.5)
                  : Colors.black.withValues(alpha: 0.08),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isSelected ? 17 : 20),
          child: Stack(
            children: [
              // Büyük dekoratif emoji
              Positioned(
                right: -8,
                bottom: -12,
                child: AnimatedOpacity(
                  opacity: isSelected ? 0.25 : 0.12,
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    item.emoji,
                    style: const TextStyle(fontSize: 68),
                  ),
                ),
              ),
              // İçerik
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Üst: emoji pill + check
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
                        ),
                        const Spacer(),
                        AnimatedScale(
                          scale: isSelected ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.elasticOut,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: item.colorStart,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Alt: etiket
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }
}
