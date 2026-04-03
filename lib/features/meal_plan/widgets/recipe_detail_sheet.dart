import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';

/// Tarif detay bottom sheet — malzeme, yapılış, kalori bilgileri gösterir.
class RecipeDetailSheet extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailSheet({super.key, required this.recipe});

  static void show(BuildContext context, Recipe recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecipeDetailSheet(recipe: recipe),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // İçerik
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  children: [
                    // Yemek adı
                    Text(
                      recipe.yemekAdi,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.charcoal,
                              ),
                    ),
                    const SizedBox(height: 16),
                    // Bilgi satırı: kalori, süre, zorluk, porsiyon
                    Row(
                      children: [
                        if (recipe.kalori > 0)
                          _InfoPill(
                            icon: Icons.local_fire_department_rounded,
                            label: '${recipe.kalori} kcal',
                            color: const Color(0xFFE65100),
                          ),
                        if (recipe.toplamSureDk > 0)
                          _InfoPill(
                            icon: Icons.schedule_rounded,
                            label: l10n.mealPlanMinutes(recipe.toplamSureDk),
                            color: const Color(0xFF1565C0),
                          ),
                        _InfoPill(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: recipe.zorluk,
                          color: _difficultyColor(recipe.zorluk),
                        ),
                        _InfoPill(
                          icon: Icons.people_outline_rounded,
                          label: l10n.mealPlanServings(recipe.kisiSayisi),
                          color: const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Mutfak tag'leri
                    if (recipe.mutfaklar.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: recipe.mutfaklar
                            .map((m) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    m,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ))
                            .toList(),
                      ),

                    // Malzemeler
                    if (recipe.malzemeler.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _SectionHeader(
                        icon: Icons.shopping_basket_rounded,
                        title: 'Malzemeler',
                        badge: '${recipe.malzemeler.length}',
                      ),
                      const SizedBox(height: 12),
                      ...recipe.malzemeler.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 7, right: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.charcoal,
                                        height: 1.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],

                    // Yapılış
                    if (recipe.yapilis.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _SectionHeader(
                        icon: Icons.menu_book_rounded,
                        title: 'Yapılış',
                        badge: '${recipe.yapilis.length} adım',
                      ),
                      const SizedBox(height: 12),
                      ...recipe.yapilis.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.charcoal,
                                        height: 1.5,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;

  const _SectionHeader({
    required this.icon,
    required this.title,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}
