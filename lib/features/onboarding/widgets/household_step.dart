import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Onboarding Adım 4: Hane halkı sayısı
class HouseholdStep extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const HouseholdStep({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  void _showCustomInput(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.groups_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.householdCustom,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: l10n.householdCustomHint,
                  hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(Icons.person_rounded,
                        color: AppColors.charcoal.withValues(alpha: 0.4),
                        size: 20),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (value) {
                  _submitCustom(context, value);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Text(
                        l10n.allergyAddCustomCancel,
                        style: TextStyle(
                            color: AppColors.charcoal.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _submitCustom(context, controller.text);
                        Navigator.pop(ctx);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(l10n.allergyAddCustomButton),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitCustom(BuildContext context, String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed >= 1 && parsed <= 20) {
      onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final options = [
      _HouseholdOption(1, l10n.householdSolo, Icons.person_rounded),
      _HouseholdOption(2, l10n.householdCouple, Icons.people_rounded),
      _HouseholdOption(4, l10n.householdSmallFamily, Icons.family_restroom_rounded),
      _HouseholdOption(0, l10n.householdCustom, Icons.edit_rounded), // 0 = custom
    ];

    // Custom seçili mi (1, 2, 4 dışında bir değer)
    final isCustomValue = selected != 1 && selected != 2 && selected != 4;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingHouseholdTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingHouseholdSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),

          // 2x2 grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.3,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final bool isSelected;
              if (option.value == 0) {
                // Custom kart
                isSelected = isCustomValue;
              } else {
                isSelected = selected == option.value;
              }

              return _HouseholdCard(
                option: option,
                isSelected: isSelected,
                displayValue: option.value == 0
                    ? (isCustomValue ? '$selected' : '?')
                    : '${option.value}',
                onTap: () {
                  if (option.value == 0) {
                    _showCustomInput(context);
                  } else {
                    onChanged(option.value);
                  }
                },
              );
            },
          ),

          const SizedBox(height: 32),

          // Alt bilgi — Flexible ile taşma düzeltmesi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    l10n.householdInfoText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
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

class _HouseholdOption {
  final int value;
  final String label;
  final IconData icon;

  const _HouseholdOption(this.value, this.label, this.icon);
}

class _HouseholdCard extends StatelessWidget {
  final _HouseholdOption option;
  final bool isSelected;
  final String displayValue;
  final VoidCallback onTap;

  const _HouseholdCard({
    required this.option,
    required this.isSelected,
    required this.displayValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                option.icon,
                size: 24,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.primary : AppColors.charcoal,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              option.label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
