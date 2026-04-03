import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/meal_plan.dart';
import '../../../core/models/user_preferences.dart';

/// Gün seçim sonucu
class DaySelectionResult {
  final List<int> selectedIndices;
  final DateTime startDate;
  final UserPreferences? updatedPreferences;

  const DaySelectionResult({
    required this.selectedIndices,
    required this.startDate,
    this.updatedPreferences,
  });
}

/// Haftalık plan oluşturmadan önce gün seçimi bottom sheet.
/// Mevcut plan varsa dolu günleri gösterir, seçim yapılır.
/// Tercihler varsa üstte gösterilir ve düzenlenebilir.
class DaySelectionSheet extends StatefulWidget {
  final MealPlan? existingPlan;
  final DateTime startDate;
  final UserPreferences? preferences;

  const DaySelectionSheet({
    super.key,
    this.existingPlan,
    required this.startDate,
    this.preferences,
  });

  static Future<DaySelectionResult?> show(
    BuildContext context, {
    MealPlan? existingPlan,
    required DateTime startDate,
    UserPreferences? preferences,
  }) {
    return showModalBottomSheet<DaySelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DaySelectionSheet(
        existingPlan: existingPlan,
        startDate: startDate,
        preferences: preferences,
      ),
    );
  }

  @override
  State<DaySelectionSheet> createState() => _DaySelectionSheetState();
}

class _DaySelectionSheetState extends State<DaySelectionSheet> {
  final _selected = <int>{};
  late List<String> _secilenOgunler;
  late int _kisiSayisi;
  final _scrollController = ScrollController();

  static const _gunAdlari = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
    'Cuma', 'Cumartesi', 'Pazar',
  ];

  final List<_DayInfo> _days = [];

  @override
  void initState() {
    super.initState();
    _secilenOgunler = List<String>.from(
        widget.preferences?.secilenOgunler ?? ['kahvalti', 'ogle', 'aksam']);
    _kisiSayisi = widget.preferences?.kisiSayisi ?? 1;
    _buildDays();
    // İlk geçmiş olmayan güne otomatik kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firstNonPastIdx = _days.indexWhere((d) => !d.isPast);
      if (firstNonPastIdx > 0 && _scrollController.hasClients) {
        // Her satır yaklaşık 56px yüksekliğinde
        final offset = (firstNonPastIdx * 56.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _buildDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = widget.startDate;

    final daysFromMonday = (start.weekday - DateTime.monday) % 7;
    final monday = start.subtract(Duration(days: daysFromMonday));

    final int totalDays;
    // Kalan gün sayısı az ise (≤3) veya plan yoksa 14 gün göster
    final remainingInWeek = (DateTime.sunday - start.weekday) % 7 + 1;
    if (widget.existingPlan == null || remainingInWeek <= 3) {
      totalDays = 14;
    } else {
      totalDays = 7;
    }

    for (var i = 0; i < totalDays; i++) {
      final date = monday.add(Duration(days: i));
      final dateDay = DateTime(date.year, date.month, date.day);
      final isPast = dateDay.isBefore(today);
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      MealDay? existingDay;
      int existingMealCount = 0;
      if (widget.existingPlan != null) {
        for (final d in widget.existingPlan!.gunler) {
          if (d.gun == dateStr) {
            existingDay = d;
            existingMealCount = d.ogunler.length;
            break;
          }
        }
      }

      final info = _DayInfo(
        index: i,
        date: date,
        dateStr: dateStr,
        gunAdi: _gunAdlari[date.weekday - 1],
        isPast: isPast,
        existingDay: existingDay,
        existingMealCount: existingMealCount,
      );
      _days.add(info);

      if (!isPast && !dateDay.isBefore(DateTime(start.year, start.month, start.day))) {
        if (existingMealCount == 0) {
          _selected.add(i);
        }
      }
    }
  }

  void _toggleDay(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else {
        _selected.add(index);
      }
    });
  }

  void _selectAll() {
    setState(() {
      for (final day in _days) {
        if (!day.isPast) _selected.add(day.index);
      }
    });
  }

  void _deselectAll() {
    setState(() => _selected.clear());
  }

  void _toggleSlot(String slot) {
    setState(() {
      if (_secilenOgunler.contains(slot)) {
        if (_secilenOgunler.length > 1) _secilenOgunler.remove(slot);
      } else {
        _secilenOgunler.add(slot);
      }
    });
  }

  void _showKisiSayisiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text('Kişi Sayısı',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.charcoal)),
            const SizedBox(height: 12),
            for (final sayi in [1, 2, 4, 5])
              ListTile(
                leading: Icon(
                  _kisiSayisi == sayi
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _kisiSayisi == sayi
                      ? AppColors.primary
                      : AppColors.charcoal.withValues(alpha: 0.3),
                  size: 20,
                ),
                title: Text(_kisiLabel(sayi),
                    style: TextStyle(
                      fontWeight:
                          _kisiSayisi == sayi ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.charcoal,
                    )),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  setState(() => _kisiSayisi = sayi);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirm() {
    if (_selected.isEmpty) return;

    final sortedIndices = _selected.toList()..sort();

    // startDate olarak ilk seçilen günün tarihini kullan (bugün değil)
    final firstSelectedDate = _days[sortedIndices.first].date;

    UserPreferences? updated;
    final origOgunler = widget.preferences?.secilenOgunler ?? [];
    final ogunlerChanged = _secilenOgunler.length != origOgunler.length ||
        !_secilenOgunler.every((s) => origOgunler.contains(s));
    if (widget.preferences != null &&
        (ogunlerChanged || _kisiSayisi != widget.preferences!.kisiSayisi)) {
      updated = widget.preferences!.copyWith(
        secilenOgunler: List<String>.from(_secilenOgunler),
        kisiSayisi: _kisiSayisi,
      );
    }

    Navigator.pop(context, DaySelectionResult(
      selectedIndices: sortedIndices,
      startDate: firstSelectedDate,
      updatedPreferences: updated,
    ));
  }

  String _slotLabel(String slot) {
    switch (slot) {
      case 'kahvalti': return 'Kahvaltı';
      case 'ogle': return 'Öğle';
      case 'aksam': return 'Akşam';
      case 'ara_ogun': return 'Ara Öğün';
      default: return slot;
    }
  }

  String _slotEmoji(String slot) {
    switch (slot) {
      case 'kahvalti': return '\u{1F305}';
      case 'ogle': return '\u{2600}\u{FE0F}';
      case 'aksam': return '\u{1F319}';
      case 'ara_ogun': return '\u{1F34E}';
      default: return '\u{1F37D}\u{FE0F}';
    }
  }

  String _kisiLabel(int sayi) {
    if (sayi >= 5) return '5+ kişi';
    return '$sayi kişi';
  }

  Widget _buildSlotChip(String slot) {
    final isActive = _secilenOgunler.contains(slot);
    return GestureDetector(
      onTap: () => _toggleSlot(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.charcoal.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : AppColors.charcoal.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_slotEmoji(slot), style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              _slotLabel(slot),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allFutureSelected = _days
        .where((d) => !d.isPast)
        .every((d) => _selected.contains(d.index));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Tercih özeti (düzenlenebilir)
            if (widget.preferences != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    // Öğün slotları — toggle chip'ler
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final slot in UserPreferences.availableSlots)
                          _buildSlotChip(slot),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Kişi sayısı
                    GestureDetector(
                      onTap: () => _showKisiSayisiPicker(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_rounded,
                              size: 16,
                              color: AppColors.charcoal.withValues(alpha: 0.5)),
                          const SizedBox(width: 6),
                          Text(
                            _kisiLabel(_kisiSayisi),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.charcoal,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded,
                              size: 12,
                              color: AppColors.charcoal.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Başlık + tümünü seç
            Row(
              children: [
                Text(
                  'Hangi günler için plan oluşturulsun?',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: allFutureSelected ? _deselectAll : _selectAll,
                  child: Text(
                    allFutureSelected ? 'Hiçbiri' : 'Tümü',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Gün listesi
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _days.expand((day) {
                    final isChecked = _selected.contains(day.index);
                    final hasMeals = day.existingMealCount > 0;

                    final widgets = <Widget>[];
                    // Hafta ayırıcı (Pazar → Pazartesi geçişinde)
                    if (day.index > 0 && day.date.weekday == DateTime.monday) {
                      widgets.add(Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.border, height: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Sonraki Hafta',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.charcoal.withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: AppColors.border, height: 1)),
                          ],
                        ),
                      ));
                    }

                    widgets.add(GestureDetector(
                      onTap: day.isPast ? null : () => _toggleDay(day.index),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: day.isPast
                                    ? AppColors.charcoal.withValues(alpha: 0.05)
                                    : isChecked
                                        ? AppColors.primary
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                  color: day.isPast
                                      ? AppColors.charcoal.withValues(alpha: 0.1)
                                      : isChecked
                                          ? AppColors.primary
                                          : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isChecked && !day.isPast
                                  ? const Icon(Icons.check_rounded,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.gunAdi,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: day.isPast
                                          ? AppColors.charcoal.withValues(alpha: 0.3)
                                          : AppColors.charcoal,
                                    ),
                                  ),
                                  Text(
                                    '${day.date.day.toString().padLeft(2, '0')}.${day.date.month.toString().padLeft(2, '0')}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.charcoal.withValues(alpha: 0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (day.isPast)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.charcoal.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('Geçmiş',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.charcoal.withValues(alpha: 0.3),
                                  )),
                              )
                            else if (hasMeals)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? AppColors.accent.withValues(alpha: 0.1)
                                      : AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isChecked
                                      ? '${_secilenOgunler.length} öğün olarak yenilenecek'
                                      : '${day.existingMealCount} öğün mevcut',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: isChecked ? AppColors.accent : AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ));

                    return widgets;
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Onay butonu
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selected.isNotEmpty ? _confirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.charcoal.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  _selected.isEmpty
                      ? 'Gün seçin'
                      : '${_selected.length} gün için plan oluştur',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayInfo {
  final int index;
  final DateTime date;
  final String dateStr;
  final String gunAdi;
  final bool isPast;
  final MealDay? existingDay;
  final int existingMealCount;

  const _DayInfo({
    required this.index,
    required this.date,
    required this.dateStr,
    required this.gunAdi,
    required this.isPast,
    this.existingDay,
    required this.existingMealCount,
  });
}
