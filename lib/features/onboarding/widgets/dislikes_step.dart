import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Onboarding Adım 5: Sevmediği malzemeler
class DislikesStep extends StatelessWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const DislikesStep({
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

  List<Widget> _buildCustomItems(BuildContext context) {
    final customItems = selected
        .where((s) => s.startsWith('custom:'))
        .map((s) => s.replaceFirst('custom:', ''))
        .toList();

    if (customItems.isEmpty) return [];

    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: customItems.map((name) {
            final customId = 'custom:${name.toLowerCase()}';
            return GestureDetector(
              onTap: () => _toggle(customId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✏️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      name[0].toUpperCase() + name.substring(1),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ];
  }

  void _showCustomInput(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded,
                        color: Color(0xFFE65100), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.dislikeAddCustomTitle,
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
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.dislikeAddCustomHint,
                  hintStyle: TextStyle(color: AppColors.charcoal.withValues(alpha: 0.3)),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(Icons.edit_rounded,
                        color: AppColors.charcoal.withValues(alpha: 0.4), size: 20),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                onSubmitted: (value) {
                  _submitCustom(value);
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
                        style: TextStyle(color: AppColors.charcoal.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        _submitCustom(controller.text);
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

  void _submitCustom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    final customId = 'custom:${trimmed.toLowerCase()}';
    if (!selected.contains(customId)) {
      final list = List<String>.from(selected)..add(customId);
      onChanged(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final sections = [
      _DislikeSection(
        title: l10n.dislikesVegetables,
        emoji: '🥬',
        items: [
          _DislikeItem('patlican', l10n.dislikeEggplant, '🍆'),
          _DislikeItem('kereviz', l10n.dislikeCelery, '🥬'),
          _DislikeItem('bamya', l10n.dislikeOkra, '🫛'),
          _DislikeItem('lahana', l10n.dislikeCabbage, '🥗'),
          _DislikeItem('brokoli', l10n.dislikeBroccoli, '🥦'),
          _DislikeItem('ispanak', l10n.dislikeSpinach, '🍃'),
        ],
      ),
      _DislikeSection(
        title: l10n.dislikesFruits,
        emoji: '🍎',
        items: [
          _DislikeItem('avokado', l10n.dislikeAvocado, '🥑'),
          _DislikeItem('ananas', l10n.dislikePineapple, '🍍'),
          _DislikeItem('incir', l10n.dislikeFig, '🫐'),
          _DislikeItem('hindistan_cevizi', l10n.dislikeCoconut, '🥥'),
        ],
      ),
      _DislikeSection(
        title: l10n.dislikesProteins,
        emoji: '🥩',
        items: [
          _DislikeItem('deniz_urunu', l10n.dislikeSeafood, '🐟'),
          _DislikeItem('kirmizi_et', l10n.dislikeRedMeat, '🥩'),
          _DislikeItem('tavuk', l10n.dislikeChicken, '🍗'),
          _DislikeItem('baklagil', l10n.dislikeLegumes, '🫘'),
          _DislikeItem('sakatat', l10n.dislikeOrgan, '🫀'),
        ],
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.onboardingDislikesTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.onboardingDislikesSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.onboardingDislikesOptional,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.4),
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 24),

          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _DislikeSectionWidget(
                  section: section,
                  selected: selected,
                  onToggle: _toggle,
                ),
              )),

          // Custom eklenenler
          ..._buildCustomItems(context),

          // Ekle butonu
          GestureDetector(
            onTap: () => _showCustomInput(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    l10n.dislikeAddCustom,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }
}

class _DislikeItem {
  final String id;
  final String label;
  final String emoji;
  const _DislikeItem(this.id, this.label, this.emoji);
}

class _DislikeSection {
  final String title;
  final String emoji;
  final List<_DislikeItem> items;
  const _DislikeSection({
    required this.title,
    required this.emoji,
    required this.items,
  });
}

class _DislikeSectionWidget extends StatelessWidget {
  final _DislikeSection section;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const _DislikeSectionWidget({
    required this.section,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(section.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: section.items.map((item) {
            final isSelected = selected.contains(item.id);
            return GestureDetector(
              onTap: () => onToggle(item.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isSelected ? Colors.white : AppColors.charcoal,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      isSelected ? Icons.check_rounded : Icons.add_rounded,
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : AppColors.charcoal.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
