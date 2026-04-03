import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_preferences.dart';

/// Profil ekranında onboarding tercihlerini gösteren ve düzenleme imkanı sunan bölüm.
class PreferencesSection extends StatelessWidget {
  final UserPreferences? preferences;
  final ValueChanged<UserPreferences> onSave;

  const PreferencesSection({
    super.key,
    required this.preferences,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = preferences ?? const UserPreferences();

    return Container(
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
          // Yemek Alışkanlıkları Notu
          _FoodNoteCard(
            note: prefs.foodNote,
            onSave: (note) => onSave(prefs.copyWith(foodNote: note)),
          ),
          _divider(),

          // Mutfak Tercihleri
          _PreferenceCard(
            icon: Icons.restaurant_menu_rounded,
            iconColor: const Color(0xFFD84315),
            iconBg: const Color(0xFFFBE9E7),
            title: l10n.profileCuisines,
            chips: prefs.mutfaklar
                .map((id) => _getCuisineLabel(l10n, id))
                .toList(),
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editCuisines(context, prefs),
          ),
          _divider(),

          // Alerjiler
          _PreferenceCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFE65100),
            iconBg: const Color(0xFFFFF3E0),
            title: l10n.profileAllergies,
            chips: prefs.alerjenler
                .map((id) => _getAllergyLabel(l10n, id))
                .toList(),
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editAllergies(context, prefs),
          ),
          _divider(),

          // Diyetler
          _PreferenceCard(
            icon: Icons.eco_rounded,
            iconColor: AppColors.primary,
            iconBg: const Color(0xFFE8F5E9),
            title: l10n.profileDiets,
            chips: prefs.diyetler
                .map((id) => _getDietLabel(l10n, id))
                .toList(),
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editDiets(context, prefs),
          ),
          _divider(),

          // Öğün Planı
          _PreferenceCard(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFF1565C0),
            iconBg: const Color(0xFFE3F2FD),
            title: l10n.profileMealPlan,
            chips: prefs.secilenOgunler.map((s) => _getSlotLabel(s)).toList(),
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editMealPlan(context, prefs),
          ),
          _divider(),

          // Kişi Sayısı
          _PreferenceCard(
            icon: Icons.people_rounded,
            iconColor: const Color(0xFF6A1B9A),
            iconBg: const Color(0xFFF3E5F5),
            title: l10n.profileHousehold,
            chips: [l10n.profilePersonCount(prefs.kisiSayisi)],
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editHousehold(context, prefs),
          ),
          _divider(),

          // Sevmedikleri
          _PreferenceCard(
            icon: Icons.thumb_down_alt_rounded,
            iconColor: const Color(0xFFC62828),
            iconBg: const Color(0xFFFFEBEE),
            title: l10n.profileDislikes,
            chips: prefs.sevmedikleri
                .map((id) => _getDislikeLabel(l10n, id))
                .toList(),
            emptyText: l10n.profileNoneSelected,
            onEdit: () => _editDislikes(context, prefs),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, indent: 56, color: AppColors.border);
  }

  // ─── Mutfak düzenleme ──────────────────────────────────────

  void _editCuisines(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final allCuisines = _buildCuisineList(l10n);
    var selected = List<String>.from(prefs.mutfaklar);

    _showEditSheet(
      context: context,
      title: l10n.profileCuisines,
      icon: Icons.restaurant_menu_rounded,
      iconColor: const Color(0xFFD84315),
      iconBg: const Color(0xFFFBE9E7),
      builder: (setState) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: allCuisines.map((item) {
          final isSelected = selected.contains(item.id);
          return _SelectableChip(
            label: item.label,
            emoji: item.emoji,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  selected.remove(item.id);
                } else {
                  selected.add(item.id);
                }
              });
            },
          );
        }).toList(),
      ),
      onSave: () => onSave(prefs.copyWith(mutfaklar: selected)),
    );
  }

  // ─── Alerji düzenleme ──────────────────────────────────────

  void _editAllergies(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final allAllergies = _buildAllergyList(l10n);
    var selected = List<String>.from(prefs.alerjenler);

    _showEditSheet(
      context: context,
      title: l10n.profileAllergies,
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFFE65100),
      iconBg: const Color(0xFFFFF3E0),
      builder: (setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...allAllergies.map((item) {
                final isSelected = selected.contains(item.id);
                return _SelectableChip(
                  label: item.label,
                  emoji: item.emoji,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        selected.remove(item.id);
                      } else {
                        selected.add(item.id);
                      }
                    });
                  },
                );
              }),
              // Custom alerjenler
              ...selected
                  .where((a) => a.startsWith('custom:'))
                  .map((a) {
                final name = a.replaceFirst('custom:', '');
                return _SelectableChip(
                  label: name[0].toUpperCase() + name.substring(1),
                  emoji: '⚠️',
                  isSelected: true,
                  onTap: () {
                    setState(() => selected.remove(a));
                  },
                );
              }),
              // Ekle butonu
              _AddCustomButton(
                label: l10n.allergyAddCustom,
                onAdd: (value) {
                  final customId = 'custom:${value.toLowerCase()}';
                  if (!selected.contains(customId)) {
                    setState(() => selected.add(customId));
                  }
                },
                hintText: l10n.allergyAddCustomHint,
                dialogTitle: l10n.allergyAddCustomTitle,
              ),
            ],
          ),
        ],
      ),
      onSave: () => onSave(prefs.copyWith(alerjenler: selected)),
    );
  }

  // ─── Diyet düzenleme ──────────────────────────────────────

  void _editDiets(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final allDiets = _buildDietList(l10n);
    var selected = List<String>.from(prefs.diyetler);

    _showEditSheet(
      context: context,
      title: l10n.profileDiets,
      icon: Icons.eco_rounded,
      iconColor: AppColors.primary,
      iconBg: const Color(0xFFE8F5E9),
      builder: (setState) => Column(
        children: allDiets.map((item) {
          final isSelected = selected.contains(item.id);
          return _DietTile(
            label: item.label,
            icon: item.icon,
            color: item.color,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                if (isSelected) {
                  selected.remove(item.id);
                } else {
                  selected.add(item.id);
                }
              });
            },
          );
        }).toList(),
      ),
      onSave: () => onSave(prefs.copyWith(diyetler: selected)),
    );
  }

  // ─── Öğün planı düzenleme ──────────────────────────────────

  void _editMealPlan(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    var selected = List<String>.from(prefs.secilenOgunler);

    final slots = [
      ('kahvalti', l10n.mealSlotKahvalti, '\u{1F305}'),
      ('ogle', l10n.mealSlotOgle, '\u{2600}\u{FE0F}'),
      ('aksam', l10n.mealSlotAksam, '\u{1F319}'),
      ('ara_ogun', l10n.mealSlotAraOgun, '\u{1F34E}'),
    ];

    _showEditSheet(
      context: context,
      title: l10n.profileMealPlan,
      icon: Icons.schedule_rounded,
      iconColor: const Color(0xFF1565C0),
      iconBg: const Color(0xFFE3F2FD),
      builder: (setState) => Column(
        children: slots.map((slot) {
          final isSelected = selected.contains(slot.$1);
          final isLast = isSelected && selected.length == 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                if (isLast) return;
                setState(() {
                  if (isSelected) {
                    selected.remove(slot.$1);
                  } else {
                    selected.add(slot.$1);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(slot.$3, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        slot.$2,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                      ),
                    ),
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
            ),
          );
        }).toList(),
      ),
      onSave: () => onSave(prefs.copyWith(secilenOgunler: selected)),
    );
  }

  // ─── Kişi sayısı düzenleme ─────────────────────────────────

  void _editHousehold(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    var selected = prefs.kisiSayisi;

    final presets = [
      _HouseholdOption(1, l10n.householdSolo, Icons.person_rounded),
      _HouseholdOption(2, l10n.householdCouple, Icons.people_rounded),
      _HouseholdOption(4, l10n.householdSmallFamily, Icons.family_restroom_rounded),
    ];

    _showEditSheet(
      context: context,
      title: l10n.profileHousehold,
      icon: Icons.people_rounded,
      iconColor: const Color(0xFF6A1B9A),
      iconBg: const Color(0xFFF3E5F5),
      builder: (setState) => Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemCount: presets.length + 1,
            itemBuilder: (context, index) {
              if (index < presets.length) {
                final option = presets[index];
                final isSelected = selected == option.value;
                return _HouseholdCard(
                  icon: option.icon,
                  label: option.label,
                  value: '${option.value}',
                  isSelected: isSelected,
                  onTap: () => setState(() => selected = option.value),
                );
              }
              // Custom kart
              final isCustom =
                  selected != 1 && selected != 2 && selected != 4;
              return _HouseholdCard(
                icon: Icons.edit_rounded,
                label: l10n.householdCustom,
                value: isCustom ? '$selected' : '?',
                isSelected: isCustom,
                onTap: () {
                  _showCustomNumberInput(
                    context,
                    l10n.householdCustom,
                    l10n.householdCustomHint,
                    (value) => setState(() => selected = value),
                  );
                },
              );
            },
          ),
        ],
      ),
      onSave: () => onSave(prefs.copyWith(kisiSayisi: selected)),
    );
  }

  // ─── Sevmedikleri düzenleme ─────────────────────────────────

  void _editDislikes(BuildContext context, UserPreferences prefs) {
    final l10n = AppLocalizations.of(context);
    final sections = _buildDislikeSections(l10n);
    var selected = List<String>.from(prefs.sevmedikleri);

    _showEditSheet(
      context: context,
      title: l10n.profileDislikes,
      icon: Icons.thumb_down_alt_rounded,
      iconColor: const Color(0xFFC62828),
      iconBg: const Color(0xFFFFEBEE),
      builder: (setState) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sections.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(section.emoji,
                            style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text(
                          section.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: section.items.map((item) {
                        final isSelected = selected.contains(item.id);
                        return _SelectableChip(
                          label: item.label,
                          emoji: item.emoji,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                selected.remove(item.id);
                              } else {
                                selected.add(item.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )),
          // Custom eklenenler
          ...selected.where((s) => s.startsWith('custom:')).map((s) {
            final name = s.replaceFirst('custom:', '');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SelectableChip(
                label: name[0].toUpperCase() + name.substring(1),
                emoji: '✏️',
                isSelected: true,
                onTap: () => setState(() => selected.remove(s)),
              ),
            );
          }),
          _AddCustomButton(
            label: l10n.dislikeAddCustom,
            onAdd: (value) {
              final customId = 'custom:${value.toLowerCase()}';
              if (!selected.contains(customId)) {
                setState(() => selected.add(customId));
              }
            },
            hintText: l10n.dislikeAddCustomHint,
            dialogTitle: l10n.dislikeAddCustomTitle,
          ),
        ],
      ),
      onSave: () => onSave(prefs.copyWith(sevmedikleri: selected)),
    );
  }

  // ─── Genel düzenleme bottom sheet ──────────────────────────

  void _showEditSheet({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget Function(StateSetter setState) builder,
    required VoidCallback onSave,
  }) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
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
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.charcoal,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.charcoal.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),
              // İçerik
              Expanded(
                child: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: builder(setState),
                  ),
                ),
              ),
              // Kaydet butonu
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(ctx).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onSave();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      l10n.profileEditSave,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Özel sayı input helper ────────────────────────────────

  void _showCustomNumberInput(
    BuildContext context,
    String title,
    String hint,
    ValueChanged<int> onValue,
  ) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (value) {
            final parsed = int.tryParse(value.trim());
            if (parsed != null && parsed >= 1 && parsed <= 20) {
              onValue(parsed);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.allergyAddCustomCancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 1 && parsed <= 20) {
                onValue(parsed);
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.allergyAddCustomButton),
          ),
        ],
      ),
    );
  }

  // ─── Veri eşleme (id → label) ─────────────────────────────

  String _getCuisineLabel(AppLocalizations l10n, String id) {
    final map = <String, String>{
      'turk': l10n.cuisineTurkish,
      'ev_yemekleri': l10n.cuisineHomeCooking,
      'akdeniz': l10n.cuisineMediterranean,
      'izgara': l10n.cuisineGrill,
      'italyan': l10n.cuisineItalian,
      'uzak_dogu': l10n.cuisineAsian,
      'meksika': l10n.cuisineMexican,
      'fast_food': l10n.cuisineFastFood,
      'deniz_urunleri': l10n.cuisineSeafood,
      'sokak_lezzetleri': l10n.cuisineStreetFood,
      'fit': l10n.cuisineHealthy,
      'vegan_mutfagi': l10n.cuisineVegan,
      'tatlilar': l10n.cuisineDesserts,
      'corbalar': l10n.cuisineSoups,
      'salata': l10n.cuisineSalads,
      'hamur_isi': l10n.cuisinePastry,
      'fransiz': l10n.cuisineFrench,
      'ortadogu': l10n.cuisineMiddleEast,
      'one_pot': l10n.cuisineOnePot,
      'dunya': l10n.cuisineWorld,
      'aperatif': l10n.cuisineSnacks,
      'bebek_cocuk': l10n.cuisineKids,
      'glutensiz': l10n.cuisineGlutenFree,
      'hizli_kahvalti': l10n.cuisineQuickBreakfast,
      'guney_amerika': l10n.cuisineSouthAmerican,
    };
    return map[id] ?? id;
  }

  String _getAllergyLabel(AppLocalizations l10n, String id) {
    if (id.startsWith('custom:')) {
      final name = id.replaceFirst('custom:', '');
      return name[0].toUpperCase() + name.substring(1);
    }
    final map = <String, String>{
      'gluten': l10n.allergyGluten,
      'yer_fistigi': l10n.allergyPeanut,
      'sut': l10n.allergyDairy,
      'yumurta': l10n.allergyEgg,
      'soya': l10n.allergySoy,
      'deniz_urunleri': l10n.allergySeafood,
    };
    return map[id] ?? id;
  }

  String _getDietLabel(AppLocalizations l10n, String id) {
    final map = <String, String>{
      'vejetaryen': l10n.dietVegetarian,
      'vegan': l10n.dietVegan,
      'keto': l10n.dietKeto,
      'kilo_verme': l10n.dietWeightLoss,
      'kilo_alma': l10n.dietWeightGain,
      'yuksek_protein': l10n.dietHighProtein,
      'dusuk_karbonhidrat': l10n.dietLowCarb,
      'diyabet_dostu': l10n.dietDiabetic,
    };
    return map[id] ?? id;
  }

  String _getSlotLabel(String slot) {
    switch (slot) {
      case 'kahvalti': return 'Kahvaltı';
      case 'ogle': return 'Öğle';
      case 'aksam': return 'Akşam';
      case 'ara_ogun': return 'Ara Öğün';
      default: return slot;
    }
  }

  String _getDislikeLabel(AppLocalizations l10n, String id) {
    if (id.startsWith('custom:')) {
      final name = id.replaceFirst('custom:', '');
      return name[0].toUpperCase() + name.substring(1);
    }
    final map = <String, String>{
      'patlican': l10n.dislikeEggplant,
      'kereviz': l10n.dislikeCelery,
      'bamya': l10n.dislikeOkra,
      'lahana': l10n.dislikeCabbage,
      'brokoli': l10n.dislikeBroccoli,
      'ispanak': l10n.dislikeSpinach,
      'avokado': l10n.dislikeAvocado,
      'ananas': l10n.dislikePineapple,
      'incir': l10n.dislikeFig,
      'hindistan_cevizi': l10n.dislikeCoconut,
      'deniz_urunu': l10n.dislikeSeafood,
      'kirmizi_et': l10n.dislikeRedMeat,
      'tavuk': l10n.dislikeChicken,
      'baklagil': l10n.dislikeLegumes,
      'sakatat': l10n.dislikeOrgan,
    };
    return map[id] ?? id;
  }

  // ─── Veri listeleri (düzenleme sheet'leri için) ────────────

  List<_LabeledItem> _buildCuisineList(AppLocalizations l10n) {
    return [
      _LabeledItem('turk', l10n.cuisineTurkish, '🍳'),
      _LabeledItem('ev_yemekleri', l10n.cuisineHomeCooking, '🍲'),
      _LabeledItem('akdeniz', l10n.cuisineMediterranean, '🫒'),
      _LabeledItem('izgara', l10n.cuisineGrill, '🥩'),
      _LabeledItem('italyan', l10n.cuisineItalian, '🍝'),
      _LabeledItem('uzak_dogu', l10n.cuisineAsian, '🥢'),
      _LabeledItem('meksika', l10n.cuisineMexican, '🌮'),
      _LabeledItem('fast_food', l10n.cuisineFastFood, '🍔'),
      _LabeledItem('deniz_urunleri', l10n.cuisineSeafood, '🦐'),
      _LabeledItem('sokak_lezzetleri', l10n.cuisineStreetFood, '🌯'),
      _LabeledItem('fit', l10n.cuisineHealthy, '🥑'),
      _LabeledItem('vegan_mutfagi', l10n.cuisineVegan, '🌱'),
      _LabeledItem('tatlilar', l10n.cuisineDesserts, '🍰'),
      _LabeledItem('corbalar', l10n.cuisineSoups, '🍜'),
      _LabeledItem('salata', l10n.cuisineSalads, '🥗'),
      _LabeledItem('hamur_isi', l10n.cuisinePastry, '🥟'),
      _LabeledItem('fransiz', l10n.cuisineFrench, '🥐'),
      _LabeledItem('ortadogu', l10n.cuisineMiddleEast, '🧆'),
      _LabeledItem('one_pot', l10n.cuisineOnePot, '🫕'),
      _LabeledItem('dunya', l10n.cuisineWorld, '🌍'),
      _LabeledItem('aperatif', l10n.cuisineSnacks, '🧀'),
      _LabeledItem('bebek_cocuk', l10n.cuisineKids, '👶'),
      _LabeledItem('glutensiz', l10n.cuisineGlutenFree, '🌾'),
      _LabeledItem('hizli_kahvalti', l10n.cuisineQuickBreakfast, '🥤'),
      _LabeledItem('guney_amerika', l10n.cuisineSouthAmerican, '🫔'),
    ];
  }

  List<_LabeledItem> _buildAllergyList(AppLocalizations l10n) {
    return [
      _LabeledItem('gluten', l10n.allergyGluten, '🌾'),
      _LabeledItem('yer_fistigi', l10n.allergyPeanut, '🥜'),
      _LabeledItem('sut', l10n.allergyDairy, '🥛'),
      _LabeledItem('yumurta', l10n.allergyEgg, '🥚'),
      _LabeledItem('soya', l10n.allergySoy, '🫘'),
      _LabeledItem('deniz_urunleri', l10n.allergySeafood, '🐟'),
    ];
  }

  List<_DietData> _buildDietList(AppLocalizations l10n) {
    return [
      _DietData('vejetaryen', l10n.dietVegetarian, Icons.eco_rounded, const Color(0xFF2E7D32)),
      _DietData('vegan', l10n.dietVegan, Icons.spa_rounded, const Color(0xFF1B5E20)),
      _DietData('keto', l10n.dietKeto, Icons.bolt_rounded, const Color(0xFFE65100)),
      _DietData('kilo_verme', l10n.dietWeightLoss, Icons.trending_down_rounded, const Color(0xFF00897B)),
      _DietData('kilo_alma', l10n.dietWeightGain, Icons.trending_up_rounded, const Color(0xFF5D4037)),
      _DietData('yuksek_protein', l10n.dietHighProtein, Icons.fitness_center_rounded, const Color(0xFFC62828)),
      _DietData('dusuk_karbonhidrat', l10n.dietLowCarb, Icons.remove_circle_outline_rounded, const Color(0xFF6A1B9A)),
      _DietData('diyabet_dostu', l10n.dietDiabetic, Icons.monitor_heart_rounded, const Color(0xFF1565C0)),
    ];
  }

  List<_DislikeSectionData> _buildDislikeSections(AppLocalizations l10n) {
    return [
      _DislikeSectionData(
        title: l10n.dislikesVegetables,
        emoji: '🥬',
        items: [
          _LabeledItem('patlican', l10n.dislikeEggplant, '🍆'),
          _LabeledItem('kereviz', l10n.dislikeCelery, '🥬'),
          _LabeledItem('bamya', l10n.dislikeOkra, '🫛'),
          _LabeledItem('lahana', l10n.dislikeCabbage, '🥗'),
          _LabeledItem('brokoli', l10n.dislikeBroccoli, '🥦'),
          _LabeledItem('ispanak', l10n.dislikeSpinach, '🍃'),
        ],
      ),
      _DislikeSectionData(
        title: l10n.dislikesFruits,
        emoji: '🍎',
        items: [
          _LabeledItem('avokado', l10n.dislikeAvocado, '🥑'),
          _LabeledItem('ananas', l10n.dislikePineapple, '🍍'),
          _LabeledItem('incir', l10n.dislikeFig, '🫐'),
          _LabeledItem('hindistan_cevizi', l10n.dislikeCoconut, '🥥'),
        ],
      ),
      _DislikeSectionData(
        title: l10n.dislikesProteins,
        emoji: '🥩',
        items: [
          _LabeledItem('deniz_urunu', l10n.dislikeSeafood, '🐟'),
          _LabeledItem('kirmizi_et', l10n.dislikeRedMeat, '🥩'),
          _LabeledItem('tavuk', l10n.dislikeChicken, '🍗'),
          _LabeledItem('baklagil', l10n.dislikeLegumes, '🫘'),
          _LabeledItem('sakatat', l10n.dislikeOrgan, '🫀'),
        ],
      ),
    ];
  }
}

// ─── Yardımcı modeller ──────────────────────────────────────

class _LabeledItem {
  final String id;
  final String label;
  final String emoji;
  const _LabeledItem(this.id, this.label, this.emoji);
}

class _DietData {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _DietData(this.id, this.label, this.icon, this.color);
}

class _HouseholdOption {
  final int value;
  final String label;
  final IconData icon;
  const _HouseholdOption(this.value, this.label, this.icon);
}

class _DislikeSectionData {
  final String title;
  final String emoji;
  final List<_LabeledItem> items;
  const _DislikeSectionData({
    required this.title,
    required this.emoji,
    required this.items,
  });
}

// ─── Yardımcı widget'lar ────────────────────────────────────

/// Profil tercih kartı — başlık + chip'ler + düzenle ikonu
class _PreferenceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final List<String> chips;
  final String emptyText;
  final VoidCallback onEdit;
  final bool isLast;

  const _PreferenceCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.chips,
    required this.emptyText,
    required this.onEdit,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(height: 8),
                  chips.isEmpty
                      ? Text(
                          emptyText,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.4),
                                    fontStyle: FontStyle.italic,
                                  ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: chips
                              .map((label) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      label,
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
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit_rounded,
              size: 18,
              color: AppColors.charcoal.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçilebilir chip (düzenleme sheet'lerinde kullanılır)
class _SelectableChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? Colors.white : AppColors.charcoal,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
            ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.check_rounded : Icons.add_rounded,
              size: 14,
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

/// Diyet satır widget'ı
class _DietTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DietTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.charcoal,
                    ),
              ),
            ),
            Container(
              width: 22,
              height: 22,
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
                      size: 13, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Household kart widget'ı
class _HouseholdCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _HouseholdCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.charcoal.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? AppColors.primary : AppColors.charcoal,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

/// Custom öğe ekleme butonu
class _AddCustomButton extends StatelessWidget {
  final String label;
  final ValueChanged<String> onAdd;
  final String hintText;
  final String dialogTitle;

  const _AddCustomButton({
    required this.label,
    required this.onAdd,
    required this.hintText,
    required this.dialogTitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showInput(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInput(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              onAdd(trimmed);
              Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.allergyAddCustomCancel),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                onAdd(trimmed);
                Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(l10n.allergyAddCustomButton),
          ),
        ],
      ),
    );
  }
}

/// Kullanıcının serbest metin olarak yemek alışkanlıklarını yazabileceği kart.
class _FoodNoteCard extends StatefulWidget {
  final String note;
  final ValueChanged<String> onSave;

  const _FoodNoteCard({required this.note, required this.onSave});

  @override
  State<_FoodNoteCard> createState() => _FoodNoteCardState();
}

class _FoodNoteCardState extends State<_FoodNoteCard> {
  late final TextEditingController _controller;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note);
    _controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(covariant _FoodNoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note != widget.note && !_dirty) {
      _controller.text = widget.note;
    }
  }

  void _onChanged() {
    final isDirty = _controller.text.trim() != widget.note;
    if (isDirty != _dirty) setState(() => _dirty = isDirty);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: Color(0xFFF9A825),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.profileFoodNoteTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.profileFoodNoteSubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.5),
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            maxLength: 300,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal,
                ),
            decoration: InputDecoration(
              hintText: l10n.profileFoodNoteHint,
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                  ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.charcoal.withValues(alpha: 0.3),
                  ),
            ),
          ),
          if (_dirty)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FilledButton.icon(
                  onPressed: () {
                    widget.onSave(_controller.text.trim());
                    setState(() => _dirty = false);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.profileEditSave),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
