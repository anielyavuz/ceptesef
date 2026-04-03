/// Mutfak ID → okunabilir kısa etiket dönüşümü.
/// Hem kaydedilenler hem detay ekranında kullanılır.
class CuisineLabels {
  CuisineLabels._();

  static const _labels = {
    'turk': 'Türk',
    'akdeniz': 'Akdeniz',
    'ev_yemekleri': 'Ev Yemekleri',
    'italyan': 'İtalyan',
    'uzak_dogu': 'Asya',
    'meksika': 'Meksika',
    'fransiz': 'Fransız',
    'fast_food': 'Fast Food',
    'vegan': 'Vegan',
    'fit_saglikli': 'Fit',
    'izgara_mangal': 'Izgara',
    'deniz_urunleri': 'Deniz Ürünleri',
    'sokak_lezzetleri': 'Sokak',
    'tatlilar': 'Tatlı',
    'corbalar': 'Çorba',
    'salatalar': 'Salata',
    'hamur_isleri': 'Hamur İşleri',
    'tek_tencere': 'Tek Tencere',
    'sirp': 'Sırp',
    'hint': 'Hint',
    'japon': 'Japon',
    'cin': 'Çin',
    'kore': 'Kore',
    'arap': 'Arap',
    'guney_amerika': 'G. Amerika',
    'ispanyol': 'İspanyol',
    'yunan': 'Yunan',
    'uluslararasi': 'Uluslararası',
  };

  /// Mutfak ID'sini okunabilir etikete çevirir.
  static String label(String id) =>
      _labels[id] ?? id.replaceAll('_', ' ');
}
