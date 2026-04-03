# Market Fiyat Sistemi - Firebase Yapisi

## Genel Bakis

marketfiyati.org.tr (TUBITAK) API'sinden gunluk fiyat verisi cekilir,
Firestore'a kategori bazli yazilir. Flutter uygulamasi buradan okur.

---

## Firestore Yapisi

```
marketFiyatlar/                          <- collection
  {YYYYMMDD}/                            <- gun doc (orn: 20260331)
    tarih: "20260331"
    guncellenmeTarihi: Timestamp
    toplamUrun: 328
    toplamKategori: 23
    kategoriler: {                        <- her kategorinin ozeti
      "sebzeler": {
        urunSayisi: 39,
        urunListesi: ["domates", "sogan", ...]
      },
      ...
    }
    urunIndex: {                          <- urun -> kategori hizli lookup
      "domates": "sebzeler",
      "tavuk gogsu": "et_tavuk",
      ...
    }

    kategoriler/                          <- subcollection
      sebzeler/                           <- kategori doc
        kategori: "sebzeler"
        guncellenmeTarihi: Timestamp
        urunSayisi: 39
        urunler: {
          "domates": {
            query: "domates",
            updatedAt: "2026-03-31T09:45:59+00:00",
            productCount: 25,
            products: [
              {
                productId: "1YY7",
                title: "Domates Suyu 700g Burcu",
                brand: "Burcu",
                imageUrl: "https://...",
                weightLabel: "700 GR",
                cheapest: {
                  name: "bim",
                  displayName: "BIM",
                  price: 23.0,
                  unitPrice: "32,86 TL/Kg",
                  depotName: "Dogancilar Uskudar"
                },
                markets: [
                  { name: "bim", displayName: "BIM", price: 23.0, ... },
                  { name: "a101", displayName: "A101", price: 25.5, ... },
                  { name: "migros", displayName: "Migros", price: 29.9, ... }
                ]
              },
              ...
            ]
          },
          "sogan": { ... },
          ...
        }

      meyveler/                           <- baska kategori doc
        ...
      et_tavuk/
        ...
```

---

## Kategoriler (23 adet)

| Kategori Adi       | Aciklama                    | Urun Sayisi |
|---------------------|-----------------------------|-------------|
| sebzeler            | Taze sebzeler               | ~39         |
| meyveler            | Taze meyveler               | ~24         |
| et_tavuk            | Kirmizi et, tavuk, hindi    | ~16         |
| balik_deniz         | Balik ve deniz urunleri     | ~13         |
| sarkuteri           | Sucuk, sosis, salam, pastirma | ~9       |
| sut_urunleri        | Sut, peynir, yogurt, krema  | ~25         |
| yumurta             | Yumurta                     | 1           |
| temel_gida          | Un, seker, tuz, ekmek, tahil | ~28        |
| baklagil_kuruluk    | Mercimek, nohut, bulgur     | ~11         |
| makarna_cesitleri   | Spagetti, lazanya, noodle   | ~6          |
| pirinc_cesitleri    | Basmati, baldo, jasmine     | ~4          |
| yag                 | Zeytinyagi, aycicek, susam  | ~5          |
| sos_sirke           | Salca, ketcap, sirke, soslar | ~28        |
| konserve            | Konserve sebze, balik       | ~7          |
| baharat             | Tum baharatlar              | ~33         |
| kahvaltilik         | Bal, recel, tahin, pekmez   | ~11         |
| kuruyemis           | Findik, ceviz, kuru meyve   | ~17         |
| icecekler           | Cay, kahve, su, meyve suyu  | ~15         |
| hamur_unlu          | Yufka, milfoy, kadayif      | ~3          |
| pisirim_firinda     | Maya, vanilya, kakao        | ~14         |
| turk_ozel           | Tarhana, manti, lahmacun    | ~6          |
| tatli               | Lokum, kunefe, sutlac       | ~11         |
| dondurulmus         | Dondurulmus sebze, borek    | ~2          |

---

## Flutter'dan Okuma

### Gunun tarih doc ID'si

```dart
String todayDocId = DateFormat('yyyyMMdd').format(DateTime.now());
```

### Metadata oku (kategoriler + urun index)

```dart
// 1 read
final metaSnap = await FirebaseFirestore.instance
    .collection('marketFiyatlar')
    .doc(todayDocId)
    .get();

final data = metaSnap.data()!;
final Map<String, dynamic> kategoriler = data['kategoriler'];
final Map<String, dynamic> urunIndex = data['urunIndex'];
```

### Tek kategori oku

```dart
// 1 read
final katSnap = await FirebaseFirestore.instance
    .collection('marketFiyatlar')
    .doc(todayDocId)
    .collection('kategoriler')
    .doc('sebzeler')
    .get();

final urunler = katSnap.data()!['urunler'] as Map<String, dynamic>;
```

### Belirli urunun fiyatlarini getir

```dart
// 2 read: metadata + kategori doc
Future<Map<String, dynamic>?> getUrunFiyat(String urunAdi) async {
  final docId = DateFormat('yyyyMMdd').format(DateTime.now());

  // 1) urunIndex'ten kategoriyi bul
  final meta = await FirebaseFirestore.instance
      .collection('marketFiyatlar').doc(docId).get();
  final kategori = meta.data()!['urunIndex'][urunAdi];
  if (kategori == null) return null;

  // 2) kategori doc'undan urunu al
  final katDoc = await FirebaseFirestore.instance
      .collection('marketFiyatlar').doc(docId)
      .collection('kategoriler').doc(kategori).get();

  return katDoc.data()!['urunler'][urunAdi];
}
```

### Tum verileri oku

```dart
// 24 read (1 meta + 23 kategori)
Future<Map<String, dynamic>> tumVerileriGetir() async {
  final docId = DateFormat('yyyyMMdd').format(DateTime.now());
  final base = FirebaseFirestore.instance
      .collection('marketFiyatlar').doc(docId);

  final meta = await base.get();
  final kategoriler = (meta.data()!['kategoriler'] as Map).keys;

  Map<String, dynamic> tumUrunler = {};
  for (final kat in kategoriler) {
    final snap = await base.collection('kategoriler').doc(kat).get();
    tumUrunler.addAll(snap.data()!['urunler'] as Map<String, dynamic>);
  }
  return tumUrunler;
}
```

---

## Maliyet / Read Tahmini

| Islem                        | Read Sayisi |
|------------------------------|-------------|
| Tek urun fiyat sorgula       | 2           |
| Tek kategori listele          | 1           |
| Tum kategoriler + tum urunler | 24          |
| Metadata (kategori listesi)   | 1           |

Firestore ucretsiz katman: 50.000 read/gun
Ornek: 1000 kullanici x gunluk 10 sorgu x 2 read = 20.000 read/gun (ucretsiz limitte)

---

## Veri Kaynagi

- **API**: marketfiyati.org.tr (TUBITAK BILGEM)
- **Marketler**: Migros, BIM, A101, SOK, CarrefourSA, Hakmar, Tarim Kredi
- **Guncelleme**: Gunluk 1 kez (cron, sabah 06:00)
- **Toplam urun**: ~328 urun, 23 kategori

---

## Cron Kurulumu (Raspberry Pi)

```bash
crontab -e
# gunluk sabah 6'da calistir:
0 6 * * * /usr/bin/python3 /home/elo/Desktop/marketArama/marketSearch.py >> /home/elo/Desktop/marketArama/market.log 2>&1
```

---

## Komutlar

```bash
# Tum urunleri cek + JSON + Firestore
python3 marketSearch.py

# Cache'i yoksay, zorla guncelle
python3 marketSearch.py --force

# Tek urun test
python3 marketSearch.py --ingredient "domates"

# Mevcut JSON'u Firestore'a yukle (API cekme)
python3 marketSearch.py --upload-only
```
