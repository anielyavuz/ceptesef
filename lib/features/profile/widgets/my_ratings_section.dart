import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/recipe_interaction.dart';
import '../../../core/services/taste_profile_service.dart';
import '../../../core/services/remote_logger_service.dart';

/// Profil ekranında kullanıcının tarif değerlendirmelerini gösteren bölüm.
/// Her satırda tarif adı + 3 rating butonu (bayıldım/güzel/değil).
/// Aynı butona tekrar basınca rating kaldırılır.
class MyRatingsSection extends StatefulWidget {
  const MyRatingsSection({super.key});

  @override
  State<MyRatingsSection> createState() => _MyRatingsSectionState();
}

class _MyRatingsSectionState extends State<MyRatingsSection> {
  List<RecipeInteraction> _ratings = [];
  bool _isLoading = true;
  bool _isExpanded = false;
  int _visibleCount = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final tasteService = context.read<TasteProfileService>();
      final interactions = await tasteService.getRatedInteractions(user.uid);
      if (mounted) {
        setState(() {
          _ratings = interactions;
          _isLoading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('my_ratings_load_failed',
          error: e, screen: 'profile');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _changeRating(RecipeInteraction interaction, int newRating) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final l10n = AppLocalizations.of(context);
    HapticFeedback.lightImpact();

    if (interaction.rating == newRating) {
      // Ayni butona basinca kaldır — listeden sil
      setState(() => _ratings.remove(interaction));

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileRatingRemoved),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );

      // Firestore'dan da kaldır: rating=0 ile üzerine yaz
      context
          .read<TasteProfileService>()
          .logRecipeAction(user.uid, _interactionToRecipe(interaction), 'rated', rating: 0);

      RemoteLoggerService.userAction('rating_removed',
          screen: 'profile',
          details: {'recipe': interaction.recipeName});
    } else {
      // Farkli rating sec
      setState(() {
        final idx = _ratings.indexOf(interaction);
        if (idx >= 0) {
          _ratings[idx] = RecipeInteraction(
            recipeId: interaction.recipeId,
            recipeName: interaction.recipeName,
            action: 'rated',
            mutfaklar: interaction.mutfaklar,
            ogunTipi: interaction.ogunTipi,
            zorluk: interaction.zorluk,
            rating: newRating,
            timestamp: interaction.timestamp,
          );
        }
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileRatingUpdated),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );

      context
          .read<TasteProfileService>()
          .logRecipeAction(user.uid, _interactionToRecipe(interaction), 'rated', rating: newRating);

      RemoteLoggerService.userAction('rating_changed',
          screen: 'profile',
          details: {'recipe': interaction.recipeName, 'rating': newRating});
    }
  }

  /// Interaction'dan minimal Recipe olusturur (logRecipeAction icin)
  Recipe _interactionToRecipe(RecipeInteraction i) {
    return Recipe(
      id: i.recipeId,
      yemekAdi: i.recipeName,
      ogunTipi: i.ogunTipi,
      mutfaklar: i.mutfaklar,
      zorluk: i.zorluk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_ratings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            l10n.profileMyRatingsEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                ),
          ),
        ),
      );
    }

    final total = _ratings.length;
    final showCount = _isExpanded ? _visibleCount.clamp(0, total) : 0;
    final hasMore = _isExpanded && _visibleCount < total;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Baslik — tikla ac/kapa
          GestureDetector(
            onTap: () => setState(() {
              _isExpanded = !_isExpanded;
              if (_isExpanded) _visibleCount = 5;
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Text(
                    '${_ratings.length} tarif',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.charcoal.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Liste
          if (_isExpanded) ...[
            Divider(height: 1, color: AppColors.border),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: showCount,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
              itemBuilder: (context, index) {
                final interaction = _ratings[index];
                return _RatingRow(
                  name: interaction.recipeName,
                  currentRating: interaction.rating ?? 0,
                  onRate: (rating) => _changeRating(interaction, rating),
                );
              },
            ),
            // Daha fazla goster butonu
            if (hasMore)
              GestureDetector(
                onTap: () => setState(() => _visibleCount += 5),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Center(
                    child: Text(
                      '${(total - _visibleCount).clamp(1, 5)} tarif daha göster',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Rating Satiri ──────────────────────────────────────

class _RatingRow extends StatelessWidget {
  final String name;
  final int currentRating;
  final ValueChanged<int> onRate;

  const _RatingRow({
    required this.name,
    required this.currentRating,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Tarif adi
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Rating butonlari
          _RatingChip(
            emoji: '\u{1F60D}',
            isSelected: currentRating == 3,
            color: const Color(0xFFE91E63),
            onTap: () => onRate(3),
          ),
          const SizedBox(width: 6),
          _RatingChip(
            emoji: '\u{1F44D}',
            isSelected: currentRating == 2,
            color: AppColors.primary,
            onTap: () => onRate(2),
          ),
          const SizedBox(width: 6),
          _RatingChip(
            emoji: '\u{1F44E}',
            isSelected: currentRating == 1,
            color: const Color(0xFF9E9E9E),
            onTap: () => onRate(1),
          ),
        ],
      ),
    );
  }
}

// ─── Rating Chip ────────────────────────────────────────

class _RatingChip extends StatelessWidget {
  final String emoji;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _RatingChip({
    required this.emoji,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(emoji, style: TextStyle(fontSize: isSelected ? 18 : 14)),
        ),
      ),
    );
  }
}

