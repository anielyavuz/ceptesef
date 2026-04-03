import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Onboarding Adım 2: Alerji ve diyet seçimi
/// Custom alerji ekleme modal + 8 diyet seçeneği
class AllergyDietStep extends StatelessWidget {
  final List<String> selectedAllergies;
  final List<String> selectedDiets;
  final ValueChanged<List<String>> onAllergiesChanged;
  final ValueChanged<List<String>> onDietsChanged;

  const AllergyDietStep({
    super.key,
    required this.selectedAllergies,
    required this.selectedDiets,
    required this.onAllergiesChanged,
    required this.onDietsChanged,
  });

  void _toggleAllergy(String id) {
    final list = List<String>.from(selectedAllergies);
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    onAllergiesChanged(list);
  }

  void _addCustomAllergy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

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
              // Handle bar
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
              // Başlık
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded,
                        color: Color(0xFFE65100), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.allergyAddCustomTitle,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Input
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.allergyAddCustomHint,
                  hintStyle: TextStyle(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(Icons.edit_rounded,
                        color: AppColors.charcoal.withValues(alpha: 0.4), size: 20),
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
                        color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (value) {
                  _submitCustomAllergy(context, value);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 16),
              // Butonlar
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
                        _submitCustomAllergy(context, controller.text);
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

  void _submitCustomAllergy(BuildContext context, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    // custom: prefix ile ayır, duplicate kontrolü
    final customId = 'custom:${trimmed.toLowerCase()}';
    if (!selectedAllergies.contains(customId)) {
      final list = List<String>.from(selectedAllergies)..add(customId);
      onAllergiesChanged(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final allergies = [
      _ChipItem('gluten', l10n.allergyGluten, '🌾'),
      _ChipItem('yer_fistigi', l10n.allergyPeanut, '🥜'),
      _ChipItem('sut', l10n.allergyDairy, '🥛'),
      _ChipItem('yumurta', l10n.allergyEgg, '🥚'),
      _ChipItem('soya', l10n.allergySoy, '🫘'),
      _ChipItem('deniz_urunleri', l10n.allergySeafood, '🐟'),
    ];

    final diets = [
      _DietItem('vejetaryen', l10n.dietVegetarian, Icons.eco_rounded, const Color(0xFF2E7D32)),
      _DietItem('vegan', l10n.dietVegan, Icons.spa_rounded, const Color(0xFF1B5E20)),
      _DietItem('keto', l10n.dietKeto, Icons.bolt_rounded, const Color(0xFFE65100)),
      _DietItem('kilo_verme', l10n.dietWeightLoss, Icons.trending_down_rounded, const Color(0xFF00897B)),
      _DietItem('kilo_alma', l10n.dietWeightGain, Icons.trending_up_rounded, const Color(0xFF5D4037)),
      _DietItem('yuksek_protein', l10n.dietHighProtein, Icons.fitness_center_rounded, const Color(0xFFC62828)),
      _DietItem('dusuk_karbonhidrat', l10n.dietLowCarb, Icons.remove_circle_outline_rounded, const Color(0xFF6A1B9A)),
      _DietItem('diyabet_dostu', l10n.dietDiabetic, Icons.monitor_heart_rounded, const Color(0xFF1565C0)),
    ];

    // Custom alerjileri ayıkla
    final customAllergies = selectedAllergies
        .where((a) => a.startsWith('custom:'))
        .map((a) => a.replaceFirst('custom:', ''))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingAllergyTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onboardingAllergySubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),

          // Alerjiler bölümü
          _SectionCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFE65100),
            iconBg: const Color(0xFFFFF3E0),
            title: l10n.allergiesSection,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    // Hazır alerjenler
                    ...allergies.map((item) {
                      final isSelected = selectedAllergies.contains(item.id);
                      return _AllergyChip(
                        label: item.label,
                        emoji: item.emoji,
                        isSelected: isSelected,
                        onTap: () => _toggleAllergy(item.id),
                      );
                    }),
                    // Custom eklenenler
                    ...customAllergies.map((name) {
                      final customId = 'custom:${name.toLowerCase()}';
                      return _AllergyChip(
                        label: name[0].toUpperCase() + name.substring(1),
                        emoji: '⚠️',
                        isSelected: true,
                        onTap: () => _toggleAllergy(customId),
                      );
                    }),
                    // Ekle butonu
                    GestureDetector(
                      onTap: () => _addCustomAllergy(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              l10n.allergyAddCustom,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Diyetler bölümü
          _SectionCard(
            icon: Icons.restaurant_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFE8F5E9),
            title: l10n.dietsSection,
            child: Column(
              children: diets.map((item) {
                final isSelected = selectedDiets.contains(item.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _DietTile(
                    item: item,
                    isSelected: isSelected,
                    onTap: () {
                      final list = List<String>.from(selectedDiets);
                      if (isSelected) {
                        list.remove(item.id);
                      } else {
                        list.add(item.id);
                      }
                      onDietsChanged(list);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Info kartı
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.onboardingAllergyInfoTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.onboardingAllergyInfoDesc,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.charcoal.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Text('🥬', style: TextStyle(fontSize: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Yardımcı modeller ve widget'lar ---

class _ChipItem {
  final String id;
  final String label;
  final String emoji;
  const _ChipItem(this.id, this.label, this.emoji);
}

class _DietItem {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _DietItem(this.id, this.label, this.icon, this.color);
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _AllergyChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _AllergyChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isSelected ? Colors.white : AppColors.charcoal,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : AppColors.charcoal.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _DietTile extends StatelessWidget {
  final _DietItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const _DietTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: item.color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.charcoal,
                    ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
