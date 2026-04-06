import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/remote_logger_service.dart';
import 'meal_plan_generation_screen.dart';

/// Kullanıcının kendi yemek adlarını yazarak manuel plan oluşturduğu ekran.
/// Seçili günler tab olarak gösterilir, her günde öğün slotları listelenir.
/// Kullanıcı yemek adlarını yazar, AI detayları (kalori, malzeme, tarif) tamamlar.
class ManualMealPlanScreen extends StatefulWidget {
  final String uid;
  final UserPreferences preferences;
  final List<int> selectedDayIndices;
  final DateTime startDate;

  const ManualMealPlanScreen({
    super.key,
    required this.uid,
    required this.preferences,
    required this.selectedDayIndices,
    required this.startDate,
  });

  @override
  State<ManualMealPlanScreen> createState() => _ManualMealPlanScreenState();
}

class _ManualMealPlanScreenState extends State<ManualMealPlanScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  /// Her gün ve öğün slotu için TextEditingController haritası.
  /// Anahtar: "günIndex_slotAdı"
  final Map<String, TextEditingController> _controllers = {};
  late int _kisiSayisi;

  static const _gunAdlari = [
    'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
    'Cuma', 'Cumartesi', 'Pazar',
  ];

  /// Kısa gün adları (tab etiketleri için)
  static const _gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

  @override
  void initState() {
    super.initState();
    _kisiSayisi = widget.preferences.kisiSayisi;
    RemoteLoggerService.setScreen('manual_meal_plan');
    RemoteLoggerService.info('screen_opened', screen: 'manual_meal_plan');

    _tabController = TabController(
      length: widget.selectedDayIndices.length,
      vsync: this,
    );

    // Her gün/slot için controller oluştur
    for (final dayIdx in widget.selectedDayIndices) {
      for (final slot in widget.preferences.secilenOgunler) {
        final key = '${dayIdx}_$slot';
        _controllers[key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Öğün slot adını kullanıcı dostu Türkçe etikete çevirir
  String _slotLabel(String slot) {
    switch (slot) {
      case 'kahvalti':
        return 'Kahvaltı';
      case 'ogle':
        return 'Öğle';
      case 'aksam':
        return 'Akşam';
      case 'ara_ogun':
        return 'Ara Öğün';
      default:
        return slot;
    }
  }

  /// Öğün slotu için ikon döndürür
  IconData _slotIcon(String slot) {
    switch (slot) {
      case 'kahvalti':
        return Icons.wb_sunny_rounded;
      case 'ogle':
        return Icons.light_mode_rounded;
      case 'aksam':
        return Icons.nightlight_round;
      case 'ara_ogun':
        return Icons.local_cafe_rounded;
      default:
        return Icons.restaurant_rounded;
    }
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
                title: Text(sayi >= 5 ? '5+ kişi' : '$sayi kişi',
                    style: TextStyle(
                      fontWeight: _kisiSayisi == sayi ? FontWeight.w700 : FontWeight.w500,
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

  /// Girilen tüm yemek adlarını toplar.
  /// Dönüş: gün tarihi -> slot adı -> yemek adları listesi
  Map<String, Map<String, List<String>>> _collectEntries() {
    final entries = <String, Map<String, List<String>>>{};

    final refDate = widget.startDate;
    final daysFromMon = (refDate.weekday - DateTime.monday) % 7;
    final monday = refDate.subtract(Duration(days: daysFromMon));

    for (final dayIdx in widget.selectedDayIndices) {
      final date = monday.add(Duration(days: dayIdx));
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final daySlots = <String, List<String>>{};
      for (final slot in widget.preferences.secilenOgunler) {
        final key = '${dayIdx}_$slot';
        final text = _controllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          // Virgülle ayrılmış birden fazla yemek adı destekle
          final names = text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (names.isNotEmpty) {
            daySlots[slot] = names;
          }
        }
      }
      if (daySlots.isNotEmpty) {
        entries[dateStr] = daySlots;
      }
    }
    return entries;
  }

  /// "Planı Tamamla" butonuna basıldığında
  void _onComplete() {
    final entries = _collectEntries();
    final l10n = AppLocalizations.of(context);

    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.manualPlanEmpty),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accent,
        ),
      );
      return;
    }

    RemoteLoggerService.userAction('manual_plan_complete_tapped',
        screen: 'manual_meal_plan', details: {
      'total_meals': entries.values
          .expand((slots) => slots.values)
          .expand((names) => names)
          .length,
      'days_filled': entries.length,
    });

    // Kişi sayısı değiştiyse preferences'ı güncelle
    final effectivePrefs = _kisiSayisi != widget.preferences.kisiSayisi
        ? widget.preferences.copyWith(kisiSayisi: _kisiSayisi)
        : widget.preferences;

    // MealPlanGenerationScreen'e manualEntries ile git
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MealPlanGenerationScreen(
          uid: widget.uid,
          preferences: effectivePrefs,
          startDate: widget.startDate,
          returnToHome: true,
          selectedDayIndices: widget.selectedDayIndices,
          manualEntries: entries,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Referans Pazartesi hesapla
    final refDate = widget.startDate;
    final daysFromMon = (refDate.weekday - DateTime.monday) % 7;
    final monday = refDate.subtract(Duration(days: daysFromMon));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.charcoal,
          ),
        ),
        title: Text(
          l10n.manualPlanTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: widget.selectedDayIndices.length > 4,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.charcoal.withValues(alpha: 0.4),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: widget.selectedDayIndices.map((dayIdx) {
            final date = monday.add(Duration(days: dayIdx));
            final shortName = _gunKisa[date.weekday - 1];
            final dateLabel =
                '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}';
            return Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shortName),
                  Text(dateLabel,
                      style: const TextStyle(fontSize: 10)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          // Kişi sayısı (düzenlenebilir)
          GestureDetector(
            onTap: _showKisiSayisiPicker,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_kisiSayisi kişilik — öğünler bu kişi sayısına göre orantılanacak',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.7),
                            height: 1.3,
                          ),
                    ),
                  ),
                  Icon(Icons.edit_rounded, size: 14,
                      color: AppColors.charcoal.withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),
          // Tab içerikleri
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: widget.selectedDayIndices.map((dayIdx) {
                final date = monday.add(Duration(days: dayIdx));
                final dayName = _gunAdlari[date.weekday - 1];
                return _buildDayContent(dayIdx, dayName, l10n);
              }).toList(),
            ),
          ),
        ],
      ),
      // Planı Tamamla FAB butonu
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FloatingActionButton.extended(
            onPressed: _onComplete,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(
              l10n.manualPlanComplete,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Öğün sıralama önceliği (kahvaltı → öğle → akşam → ara öğün)
  static const _slotOrder = ['kahvalti', 'ogle', 'aksam', 'ara_ogun', 'ara_ogun_1', 'ara_ogun_2', 'ana_ogun_1', 'ana_ogun_2'];

  /// Bir gün için öğün slotlarını listeler
  Widget _buildDayContent(int dayIdx, String dayName, AppLocalizations l10n) {
    final sortedSlots = List<String>.from(widget.preferences.secilenOgunler)
      ..sort((a, b) {
        final ai = _slotOrder.indexOf(a);
        final bi = _slotOrder.indexOf(b);
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: sortedSlots.length,
      itemBuilder: (context, slotIndex) {
        final slot = sortedSlots[slotIndex];
        final key = '${dayIdx}_$slot';
        return _buildSlotCard(slot, key, l10n);
      },
    );
  }

  String _slotHint(String slot) {
    switch (slot) {
      case 'kahvalti':
        return 'ör. Menemen, Peynirli Omlet';
      case 'ogle':
        return 'ör. Tavuk Sote, Pilav';
      case 'aksam':
        return 'ör. Karnıyarık, Mercimek Çorbası';
      case 'ara_ogun':
      case 'ara_ogun_1':
      case 'ara_ogun_2':
        return 'ör. Meyve Tabağı, Yoğurt';
      default:
        return 'ör. Yemek adı yazın';
    }
  }

  /// Tek bir öğün slotu kartı
  Widget _buildSlotCard(String slot, String controllerKey, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot başlığı
          Row(
            children: [
              Icon(
                _slotIcon(slot),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                _slotLabel(slot),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Yemek adı giriş alanı
          TextField(
            controller: _controllers[controllerKey],
            decoration: InputDecoration(
              hintText: _slotHint(slot),
              hintStyle: TextStyle(
                color: AppColors.charcoal.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal,
                ),
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
