# Cepte Şef — Pazar Analizi & Monetizasyon Stratejisi

> Tarih: 2 Nisan 2026
> Analiz: 50 TL/ay abonelik modeli değerlendirmesi

---

## 1. Pazar Boşluğu

Türkiye'de AI destekli haftalık yemek planlama yapan uygulama bulunmuyor. Mevcut oyuncular:

| Uygulama | Ne Yapıyor | Fiyat | İndirme |
|----------|-----------|-------|---------|
| Nefis Yemek Tarifleri | Tarif veritabanı | Ücretsiz + ~49 TL/ay premium | 10M+ |
| Yemek Tarifleri (çeşitli) | Tarif arama | Reklam destekli | 1-5M |
| Lezzet (Hürriyet) | Tarif içerik | Ücretsiz | 1M+ |
| Getir Yemek / Yemeksepeti | Yemek siparişi | Komisyon bazlı | 10M+ |

**Hiçbiri** haftalık plan üretmiyor, alışveriş listesi çıkarmıyor, AI ile kişiselleştirmiyor.

### Uluslararası AI Yemek Planlama Uygulamaları

| Uygulama | Fiyat | Kullanıcı | Durum |
|----------|-------|-----------|-------|
| Eat This Much | $5/ay veya $47/yıl | 2M+ | Aktif, orta retention |
| Mealime | $5.99/ay (Pro) | 5M+ | İyi retention, pratik odaklı |
| Whisk (Samsung Food) | Ücretsiz | Büyük | Monetizasyonda zorlandı |
| DishGen | $3.99/ay | Küçük | AI tarif üretici |
| Silo | $9.99/ay | VC destekli | Sağlık odaklı |

**Başarı kalıpları:** AI planlama + alışveriş listesi + kiler takibi birleşimi en iyi retention gösteriyor.
**Başarısızlık kalıpları:** "ChatGPT wrapper" hissi veren, derin mutfak bilgisi olmayan uygulamalar.

---

## 2. Fiyat Pozisyonlama

### Türkiye'de Referans Fiyatlar

| Uygulama/Servis | Aylık Fiyat |
|-----------------|-------------|
| Spotify | ~59 TL |
| Netflix (başlangıç) | ~99 TL |
| Nefis Yemek premium | ~49 TL |
| Utility/lifestyle uygulamalar | 30-80 TL |

### 50 TL/ay Değerlendirmesi

50 TL/ay bu aralıkta **makul bir fiyat**. Ancak kritik olan değer algısı:

- Türkiye'de ortalama hane gıda harcaması: **8.000-12.000 TL/ay**
- Gıda, hane bütçesinin **%25-30'unu** oluşturuyor (AB ortalaması %13)
- Gıda enflasyonu nedeniyle bütçe bilinci yüksek

**Eğer uygulama ayda 500-1.000 TL tasarruf sağladığını hissettirirse, 50 TL kendini 10-20x amorti eder.**

### Önerilen Fiyat Yapısı

| Plan | Fiyat | Aylık Karşılık |
|------|-------|----------------|
| Aylık | 49.99 TL/ay | 49.99 TL |
| Yıllık | 399.99 TL/yıl | 33.33 TL |
| Aile (4 profil) | 79.99 TL/ay | — |

Yıllık plan hem churn'ü düşürür hem toplam geliri artırır. Türkiye'de en çok çalışan model: **Freemium + 7 gün deneme + yıllık indirim**.

---

## 3. Hedef Kitle Segmentasyonu

| Segment | Yaş | Ödeme İhtimali | Neden |
|---------|-----|---------------|-------|
| Çalışan kadınlar | 25-40 | **Yüksek** | Zaman kısıtı, sağlıklı beslenme, aile sorumluluğu |
| Yeni evliler | 22-35 | **Yüksek** | Yemek planlamayı öğreniyorlar, bütçe bilinci |
| Fitness/diyet takipçileri | 20-40 | **Orta-Yüksek** | Alerjen/diyet filtreleri, kalori takibi |
| Öğrenciler | 18-25 | **Düşük** | Bütçe kısıtı — freemium ile yakalanabilir |
| 45+ yaş | 45+ | **Düşük** | Dijital abonelik alışkanlığı zayıf |

**Gerçekçi dönüşüm oranı:** İndirenlerin **%2-5**'i ödeme yapar (sektör ortalaması).

---

## 4. Churn (Abone Kaybı) Analizi

### Beklenen Abone Kalış Oranları

| Dönem | Kalan Abone | Açıklama |
|-------|-------------|----------|
| 1. ay | %100 | Deneme heyecanı |
| 2. ay | %65-75 | İlk düşüş — "gerçekten kullanıyor muyum?" |
| 3. ay | %45-55 | Alışkanlık oluşmadıysa terk |
| 6. ay | %25-35 | Sadık kullanıcı tabanı netleşiyor |
| 12. ay | %15-20 | Gerçek "elde tutulan" segment |

**Ortalama abone ömrü: 3-5 ay** (aylık abonelikte).
**Yıllık abonelikte: 8-12 ay** (taahhüt etkisi).

### Churn'ü Düşüren Faktörler (Cepte Şef'te mevcut)

- Haftalık plan yenileme döngüsü → doğal re-engagement
- Alışveriş listesi entegrasyonu → haftada 2-3 açılış
- AI kişiselleştirme → zaman geçtikçe daha iyi öneriler
- Push bildirimler → öğün hatırlatma
- Rating sistemi → kullanıcı yatırım hissi
- Lezzet profili → kişiselleştirme derinleşiyor

### Churn Riskleri

- AI önerilerinin 3-4 hafta sonra tekrara düşmesi
- "Bunu ChatGPT'ye de sorarım" algısı
- Tariflerdeki malzemelerin bulunabilirlik sorunu
- Onboarding'de yeterli "wow" anı yaratamama

---

## 5. Gelir Projeksiyonu

### Senaryo A: Organik Büyüme (Düşük Bütçe)

| Dönem | İndirme | Abone (%3) | Aylık Brüt | Aylık Net (-%30) |
|-------|---------|------------|------------|------------------|
| 3. ay | 3.000 | 90 | 4.500 TL | 3.150 TL |
| 6. ay | 10.000 | 200 | 10.000 TL | 7.000 TL |
| 12. ay | 25.000 | 500 | 25.000 TL | 17.500 TL |
| 18. ay | 50.000 | 1.000 | 50.000 TL | 35.000 TL |

### Senaryo B: Aktif Pazarlama (Orta Bütçe)

| Dönem | İndirme | Abone (%4) | Aylık Brüt | Aylık Net (-%30) |
|-------|---------|------------|------------|------------------|
| 3. ay | 8.000 | 320 | 16.000 TL | 11.200 TL |
| 6. ay | 30.000 | 900 | 45.000 TL | 31.500 TL |
| 12. ay | 80.000 | 2.400 | 120.000 TL | 84.000 TL |
| 18. ay | 150.000 | 4.500 | 225.000 TL | 157.500 TL |

### Senaryo C: Viral Büyüme (İyimser)

| Dönem | İndirme | Abone (%5) | Aylık Brüt | Aylık Net (-%30) |
|-------|---------|------------|------------|------------------|
| 6. ay | 100.000 | 3.500 | 175.000 TL | 122.500 TL |
| 12. ay | 300.000 | 10.000 | 500.000 TL | 350.000 TL |

> Not: Tüm senaryolarda churn hesaba katılmıştır (aktif abone sayısı, toplam indirme x dönüşüm oranı değil). Apple/Google %30 komisyon düşülmüştür.

---

## 6. Maliyet Analizi

### Sabit Maliyetler (Aylık)

| Kalem | Maliyet |
|-------|---------|
| Firebase (Blaze plan) | 200-500 TL (kullanıma göre) |
| Gemini API | 500-2.000 TL (kullanıma göre) |
| Apple Developer | ~85 TL/ay (yıllık 999 TL / 12) |
| Google Play Developer | Tek seferlik 25$ |
| Grafana/Loki hosting | 0-500 TL |
| **Toplam** | **~1.000-3.000 TL/ay** |

### Değişken Maliyetler

- Gemini API çağrısı başına maliyet (plan üretimi + chat) → kullanıcı arttıkça lineer artış
- Firebase Firestore okuma/yazma → kullanıcı sayısına bağlı
- FCM push → ücretsiz

**Kâra geçiş noktası: ~100-150 aktif abone** (sabit maliyetleri karşılar).

---

## 7. Freemium Strateji Önerisi

### Ücretsiz Katman

- Haftada 1 yemek planı oluşturma
- Maksimum 3 gün plan
- Temel alerjen/diyet filtreleri
- Sınırlı tarif kaydetme (10 tarif)
- Reklam yok (UX'i bozmamak için)

### Premium Katman (49.99 TL/ay)

- Sınırsız haftalık plan oluşturma
- 7 gün tam plan
- Gelişmiş filtreler (mutfak, zorluk, süre)
- Sınırsız tarif kaydetme
- Alışveriş listesi entegrasyonu
- Tek tarif değiştirme (AI)
- Bütçe modu
- Aile profili desteği
- Öncelikli AI yanıt

### Dönüşüm Tetikleyicileri

- Ücretsiz planı beğendikten sonra "Tüm haftanın planını görmek için Premium'a geç"
- 7 günlük ücretsiz deneme (kredi kartı sonradan)
- "İlk ay %50 indirim" kampanyası

---

## 8. Rekabet Avantajları

| Cepte Şef'in Güçlü Yanları | Rakiplerin Zayıf Yanları |
|----------------------------|-------------------------|
| Türk mutfağına hakim AI | Global uygulamalar Türk yemeklerini bilmez |
| Alerjen + diyet + lezzet profili | Nefis Yemek sadece tarif veritabanı |
| Haftalık plan + alışveriş listesi | Kimse ikisini birleştirmiyor |
| Kişiselleştirme (rating → AI öğrenme) | Statik tarif listeleri |
| Türkçe doğal dil desteği | İngilizce ağırlıklı AI uygulamalar |
| Yerel fiyatlandırma | Global uygulamalar dolar bazlı |

---

## 9. Pazarlama Kanalları

### Düşük Bütçe (Organik)

- **ASO (App Store Optimization):** "haftalık yemek planı", "yemek listesi", "ne pişirsem" anahtar kelimeleri
- **Instagram/TikTok:** Kısa videolar — "AI bana bu hafta ne pişireceğimi söyledi"
- **Influencer:** Yemek bloggerları ile organik iş birliği
- **SEO:** Blog içerikleri — "haftalık yemek listesi", "ekonomik yemek planı"

### Orta Bütçe (Ücretli)

- Instagram/Facebook reklamları — hedef: 25-40 kadın, yemek/sağlık ilgisi
- Google Ads — "ne pişirsem", "haftalık yemek listesi" aramaları
- YouTube pre-roll — yemek kanallarında

### Mesaj Stratejisi

**Ana mesaj:** "Haftanın yemek planını 30 saniyede oluştur, market listeni hazırla, bütçenden tasarruf et."

**Destekleyici mesajlar:**
- "Alerjen ve diyetine uygun planlar"
- "Türk mutfağının en iyileri, AI ile kişiselleştirilmiş"
- "Her hafta yeni tarifler, tekrara düşme"
- "Aylık 500-1000 TL gıda tasarrufu"

---

## 10. Sonuç & Aksiyon Planı

### Kısa Vadeli (0-3 ay)

1. Freemium model tasarla ve uygula
2. 7 günlük ücretsiz deneme ekle
3. Onboarding akışını optimize et (ilk plan → "wow" anı)
4. ASO çalışması yap
5. Instagram/TikTok içerik üretimine başla

### Orta Vadeli (3-6 ay)

1. Kullanıcı geri bildirimlerine göre iterate et
2. Bütçe modu ekle ("Bu hafta X TL'ye yemek planla")
3. Haftalık bildirim sistemi güçlendir
4. Referans programı (arkadaşını davet et → 1 ay ücretsiz)
5. Yıllık plan seçeneği sun

### Uzun Vadeli (6-12 ay)

1. Aile/ev halkı desteği
2. Yerel market fiyat entegrasyonu
3. Sosyal özellikler (plan paylaşma)
4. Mevsimsel/özel gün planları (Ramazan, bayram)
5. Kiler takibi → "evdeki malzemelerle ne pişirebilirim?"

---

### Tek Cümle Özet

> Cepte Şef, Türkiye'de rakipsiz bir AI yemek planlama uygulaması. 50 TL/ay makul bir fiyat, ancak sürdürülebilir gelir için 50.000+ indirme, güçlü onboarding ve düşük churn kritik. En büyük koz: "Türk mutfağını bilen, bütçe dostu, kişisel asistan" konumlandırması.
