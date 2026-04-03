import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Onboarding Adım 3: Öğün seçimi — checkbox toggle kartları
class MealPlanStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MealPlanStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final slots = [
      _SlotInfo(
        id: 'kahvalti',
        title: l10n.mealSlotKahvalti,
        icon: Icons.free_breakfast_rounded,
        iconBg: const Color(0xFFFFF3E0),
        iconColor: const Color(0xFFE65100),
        emoji: '\u{1F305}',
      ),
      _SlotInfo(
        id: 'ogle',
        title: l10n.mealSlotOgle,
        icon: Icons.lunch_dining_rounded,
        iconBg: const Color(0xFFE8F5E9),
        iconColor: AppColors.primary,
        emoji: '\u{2600}\u{FE0F}',
      ),
      _SlotInfo(
        id: 'aksam',
        title: l10n.mealSlotAksam,
        icon: Icons.dinner_dining_rounded,
        iconBg: const Color(0xFFE8EAF6),
        iconColor: const Color(0xFF283593),
        emoji: '\u{1F319}',
      ),
      _SlotInfo(
        id: 'ara_ogun',
        title: l10n.mealSlotAraOgun,
        icon: Icons.local_cafe_rounded,
        iconBg: const Color(0xFFFCE4EC),
        iconColor: const Color(0xFFC62828),
        emoji: '\u{1F34E}',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst başlık
          Text(
            l10n.onboardingMealTitle,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingMealSlotTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingMealSlotDesc,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),

          // Öğün toggle kartları
          ...slots.map((slot) {
            final isSelected = selected.contains(slot.id);
            // Son seçili slot'u deselect etmeye izin verme
            final isLastSelected = isSelected && selected.length == 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SlotCard(
                slot: slot,
                isSelected: isSelected,
                onTap: () {
                  if (isLastSelected) return;
                  final newList = List<String>.from(selected);
                  if (isSelected) {
                    newList.remove(slot.id);
                  } else {
                    newList.add(slot.id);
                  }
                  onChanged(newList);
                },
              ),
            );
          }),

          const SizedBox(height: 20),

          // Motivasyon sözü
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF2D5016).withValues(alpha: 0.9),
                  const Color(0xFF1B5E20),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('\u{1F966}', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 12),
                Text(
                  l10n.onboardingMealQuote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotInfo {
  final String id;
  final String title;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String emoji;

  const _SlotInfo({
    required this.id,
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.emoji,
  });
}

class _SlotCard extends StatelessWidget {
  final _SlotInfo slot;
  final bool isSelected;
  final VoidCallback onTap;

  const _SlotCard({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSelected ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: slot.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(slot.emoji, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                slot.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
            ),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
