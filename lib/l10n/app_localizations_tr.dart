// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Cepte Şef';

  @override
  String get welcomeMessage => 'Cepte Şef\'e hoş geldiniz!';

  @override
  String get loading => 'Yükleniyor...';

  @override
  String get errorGeneral => 'Bir hata oluştu. Lütfen tekrar deneyin.';

  @override
  String get retry => 'Tekrar Dene';

  @override
  String get settings => 'Ayarlar';

  @override
  String get language => 'Dil';

  @override
  String get turkish => 'Türkçe';

  @override
  String get english => 'İngilizce';

  @override
  String get loginTitle => 'Giriş Yap';

  @override
  String get loginSubtitle => 'Devam etmek için bilgilerinizi girin';

  @override
  String get loginHeroTitle => 'Mutfağa Tekrar\nHoş Geldiniz.';

  @override
  String get email => 'E-posta';

  @override
  String get emailHint => 'ornek@mail.com';

  @override
  String get password => 'Şifre';

  @override
  String get passwordHint => 'Şifrenizi girin';

  @override
  String get signIn => 'Giriş Yap';

  @override
  String get forgotPassword => 'Şifremi Unuttum';

  @override
  String get or => 'VEYA';

  @override
  String get continueWithGoogle => 'Google';

  @override
  String get continueWithApple => 'Apple';

  @override
  String get noAccount => 'Hesabınız yok mu?';

  @override
  String get signUp => 'Kayıt Ol';

  @override
  String get registerTitle => 'Hesap Oluştur';

  @override
  String get registerSubtitle =>
      'Cepte Şef\'e katılın ve yolculuğunuza başlayın.';

  @override
  String get registerHeroTitle => 'Mutfağınızın\nYeni Ritmi.';

  @override
  String get registerHeroSubtitle =>
      'Taze içerikler, kusursuz tarifler ve size özel beslenme asistanınızla tanışın.';

  @override
  String get fullName => 'Ad Soyad';

  @override
  String get fullNameHint => 'Adınız Soyadınız';

  @override
  String get termsText => 'Okudum ve kabul ediyorum: ';

  @override
  String get termsOfService => 'Kullanım Koşulları';

  @override
  String get and => ' ve ';

  @override
  String get privacyPolicy => 'Gizlilik Politikası';

  @override
  String get register => 'Kayıt Ol';

  @override
  String get orContinueWith => 'Veya şununla devam et';

  @override
  String get alreadyHaveAccount => 'Zaten hesabınız var mı?';

  @override
  String get forgotPasswordTitle => 'Şifrenizi mi\nUnuttunuz?';

  @override
  String get forgotPasswordSubtitle =>
      'E-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.';

  @override
  String get sendResetLink => 'Bağlantı Gönder';

  @override
  String get backToLogin => 'Giriş Ekranına Dön';

  @override
  String get resetEmailSent =>
      'Şifre sıfırlama bağlantısı e-posta adresinize gönderildi.';

  @override
  String get errorInvalidEmail => 'Geçerli bir e-posta adresi girin.';

  @override
  String get errorWeakPassword => 'Şifre en az 6 karakter olmalıdır.';

  @override
  String get errorEmailInUse => 'Bu e-posta adresi zaten kayıtlı.';

  @override
  String get errorWrongPassword => 'E-posta veya şifre hatalı.';

  @override
  String get errorUserNotFound => 'Bu e-posta ile kayıtlı hesap bulunamadı.';

  @override
  String get errorTooManyRequests =>
      'Çok fazla deneme yapıldı. Lütfen daha sonra tekrar deneyin.';

  @override
  String get errorEmptyField => 'Bu alan boş bırakılamaz.';

  @override
  String get errorAcceptTerms => 'Lütfen kullanım koşullarını kabul edin.';

  @override
  String get comingSoon => 'Yakında!';

  @override
  String get signOut => 'Çıkış Yap';

  @override
  String get legalClose => 'Kapat';

  @override
  String get termsOfServiceTitle => 'Kullanım Koşulları';

  @override
  String get termsOfServiceContent =>
      'CEPTE ŞEF — KULLANIM KOŞULLARI\n\nSon Güncelleme: Mart 2026\n\n1. KOŞULLARIN KABULÜ\n\nCepte Şef (\"Uygulama\") üzerinde hesap oluşturarak veya Uygulamayı kullanarak işbu Kullanım Koşullarını (\"Koşullar\") kabul etmiş sayılırsınız. Bu Koşulların herhangi bir bölümünü kabul etmiyorsanız, Uygulamayı kullanmamalısınız.\n\n2. HİZMET TANIMI\n\nCepte Şef, yapay zeka teknolojisi kullanarak kişiselleştirilmiş haftalık yemek planları, tarif önerileri ve beslenme rehberliği sunan akıllı bir mutfak asistanıdır. Uygulama \"olduğu gibi\" ve \"mevcut haliyle\" sunulmaktadır.\n\n3. YAPAY ZEKA İÇERİĞİ SORUMLULUK REDDİ\n\nUygulama, yemek planları, tarifler ve beslenme bilgileri üretmek için yapay zeka (Google Gemini) kullanmaktadır. AÇIKÇA KABUL VE BEYAN EDERSİNİZ Kİ:\n\n(a) Yapay zeka tarafından üretilen içerikler yanlışlıklar, hatalar veya eksiklikler içerebilir;\n(b) Tarifler ve yemek planları otomatik olarak üretilir ve lisanslı beslenme uzmanları, diyetisyenler veya sağlık profesyonelleri tarafından incelenmemiş, doğrulanmamış veya onaylanmamıştır;\n(c) Sağlanan besin değerleri, kalori miktarları ve malzeme bilgileri yaklaşık tahminlerdir ve hatalı olabilir;\n(d) Kullanmadan önce tüm malzemeleri, pişirme talimatlarını, sıcaklıkları ve hazırlama yöntemlerini doğrulamak yalnızca sizin sorumluluğunuzdadır;\n(e) Uygulama, profesyonel tıbbi, beslenme veya diyet tavsiyesinin yerini almaz.\n\n4. ALERJİ VE SAĞLIK UYARISI\n\nKRİTİK UYARI: Uygulama, kullanıcının belirttiği alerjileri ve diyet kısıtlamalarını dikkate almaya çalışsa da, yapay zeka tarafından üretilen tariflerin alerjen veya sağlık riski oluşturabilecek maddelerden arınmış olacağına dair HİÇBİR GARANTİ VERİLMEMEKTEDİR.\n\n(a) Her tarifteki tüm malzemeleri potansiyel alerjenler açısından bağımsız olarak doğrulamalısınız;\n(b) Çapraz bulaşma riskleri yapay zeka içeriğinde hesaba katılmamaktadır;\n(c) Ciddi alerjileriniz, gıda intoleranslarınız veya tıbbi diyet gereksinimleriniz varsa, herhangi bir tarifi veya yemek planını uygulamadan önce uzman bir sağlık profesyoneline danışınız;\n(d) Şirket, yapay zeka tarafından üretilen tariflerin kullanımından kaynaklanan herhangi bir alerjik reaksiyon, olumsuz sağlık etkisi veya yaralanmadan sorumlu tutulamaz.\n\n5. KULLANICI HESAPLARI\n\n(a) Doğru ve eksiksiz kayıt bilgileri sağlamalısınız;\n(b) Hesap bilgilerinizin gizliliğini korumak sizin sorumluluğunuzdadır;\n(c) Hesabınız altında gerçekleşen tüm faaliyetlerden siz sorumlusunuz;\n(d) Hesap oluşturmak için en az 13 yaşında olmalısınız;\n(e) Bu Koşulları ihlal eden hesapları askıya alma veya sonlandırma hakkımızı saklı tutarız.\n\n6. KULLANICI DAVRANIŞI\n\nAşağıdakileri yapmamayı kabul edersiniz:\n(a) Uygulamayı herhangi bir yasa dışı amaç için kullanmak;\n(b) Uygulama sistemlerine yetkisiz erişim sağlamaya çalışmak;\n(c) Uygulamayı tersine mühendislik, derleme çözme veya parçalara ayırma;\n(d) Uygulamaya erişmek için otomatik sistemler kullanmak;\n(e) Hesabınızı üçüncü taraflarla paylaşmak.\n\n7. FİKRİ MÜLKİYET\n\nUygulama içindeki tüm içerik, ticari markalar, logolar ve fikri mülkiyet Cepte Şef\'e aittir veya lisanslıdır. Açık yazılı izin olmaksızın kopyalama, değiştirme, dağıtma veya türev eser oluşturma yapılamaz.\n\n8. SORUMLULUĞUN SINIRLANDIRILMASI\n\nYASALARIN İZİN VERDİĞİ AZAMİ ÖLÇÜDE:\n\n(a) Şirket, herhangi bir doğrudan, dolaylı, arızi, özel, sonuç olarak ortaya çıkan veya cezai tazminattan sorumlu değildir;\n(b) Şirket, yapay zeka tarafından üretilen içeriğe güvenilmesinden kaynaklanan herhangi bir kayıp veya zarardan sorumlu değildir;\n(c) Şirket, tariflerin veya yemek planlarının takip edilmesinden kaynaklanan herhangi bir sağlık sorunu, alerjik reaksiyon veya yaralanmadan sorumlu değildir;\n(d) Şirketin toplam sorumluluğu, önceki 12 ayda Uygulama için ödediğiniz tutarı aşamaz;\n(e) Şirket, herhangi bir hizmet kesintisi, veri kaybı veya sistem arızasından sorumlu değildir.\n\n9. TAZMİNAT\n\nUygulamayı kullanımınızdan veya bu Koşulları ihlal etmenizden kaynaklanan tüm talep, zarar, kayıp veya masraflara karşı Cepte Şef\'i, yetkililerini, yöneticilerini, çalışanlarını ve temsilcilerini tazmin etmeyi ve zararsız kılmayı kabul edersiniz.\n\n10. ÜÇÜNCÜ TARAF HİZMETLERİ\n\nUygulama, üçüncü taraf hizmetleriyle (Firebase, Google Gemini) entegre çalışır. Bu hizmetler kendi koşulları ve gizlilik politikalarına tabidir. Şirket, üçüncü taraf hizmetlerinin kullanılabilirliği, doğruluğu veya uygulamalarından sorumlu değildir.\n\n11. DEĞİŞİKLİKLER\n\nBu Koşulları herhangi bir zamanda değiştirme hakkımızı saklı tutarız. Değişikliklerden sonra Uygulamayı kullanmaya devam etmeniz, güncellenen Koşulları kabul ettiğiniz anlamına gelir. Önemli değişiklikler Uygulama üzerinden bildirilecektir.\n\n12. FESİH\n\nUygulamaya erişiminizi herhangi bir zamanda, sebep göstererek veya göstermeksizin, bildirimde bulunarak veya bulunmaksızın sonlandırabiliriz. Fesih üzerine Uygulamayı kullanma hakkınız derhal sona erer.\n\n13. UYGULANACAK HUKUK\n\nBu Koşullar, Türkiye Cumhuriyeti kanunlarına göre yönetilir ve yorumlanır. Uyuşmazlıklar İstanbul Mahkemeleri\'nde çözülecektir.\n\n14. BÖLÜNEBİLİRLİK\n\nBu Koşulların herhangi bir hükmü geçersiz veya uygulanamaz bulunursa, kalan hükümler tam olarak yürürlükte kalmaya devam eder.\n\n15. İLETİŞİM\n\nBu Koşullar hakkındaki sorularınız için Uygulama üzerinden bizimle iletişime geçin.';

  @override
  String get privacyPolicyTitle => 'Gizlilik Politikası';

  @override
  String get homeWeeklyMode => 'Haftalık Plan';

  @override
  String get homeDailyMode => 'Günlük Plan';

  @override
  String get homeDailyTitle => 'Günlük Plan';

  @override
  String get homeDailySubtitle => 'Öğünlerine yemek ekleyerek günü planla.';

  @override
  String get homeDailyAddMeal => 'Yemek Ekle';

  @override
  String get homeDailyEmpty =>
      'Henüz bir yemek eklenmedi.\nAşağıdaki + butonuna bas ve AI ile tarif bul!';

  @override
  String get homeDailyPickSlot => 'Hangi öğüne ekleyelim?';

  @override
  String get homeScanRecipe => 'Tarif Tara';

  @override
  String get homeScanRecipeDesc =>
      'Yemek fotoğrafı çekin veya galeriden seçin, AI tarifi tanıyıp kaydedilenlerinize eklesin.';

  @override
  String get homeScanCamera => 'Kamera';

  @override
  String get homeScanGallery => 'Galeri';

  @override
  String get homeScanAnalyzing => 'Tarif analiz ediliyor...';

  @override
  String homeScanSaved(Object recipeName) {
    return '$recipeName kaydedilenlerinize eklendi!';
  }

  @override
  String get homeScanViewDetail => 'Detay';

  @override
  String get homeScanError => 'Tarif analiz edilemedi. Lütfen tekrar deneyin.';

  @override
  String get homeScanSuccessTitle => 'Tarif Kaydedildi!';

  @override
  String homeScanSuccessDesc(Object recipeName) {
    return '$recipeName kaydedilenlerinize eklendi.';
  }

  @override
  String get homeScanAddToPlan => 'Plana Ekle';

  @override
  String get homeScanViewRecipe => 'Tarifi Gör';

  @override
  String get profileFoodNoteTitle => 'Yemek Alışkanlıklarım';

  @override
  String get profileFoodNoteSubtitle =>
      'Yemek alışkanlıklarınızı yazın, size öneri sunarken bunu dikkate alacağız.';

  @override
  String get profileFoodNoteHint =>
      'Örn: Akşamları hafif yerim, baharatlı severim, kahvaltıda yumurta olmazsa olmaz...';

  @override
  String get profileSavedRecipes => 'Kaydedilenler';

  @override
  String get profileSavedEmpty =>
      'Henüz kaydedilen tarif yok.\nAI ile eklediğin tarifler burada birikecek.';

  @override
  String get privacyPolicyContent =>
      'CEPTE ŞEF — GİZLİLİK POLİTİKASI\n\nSon Güncelleme: Mart 2026\n\n1. GİRİŞ\n\nBu Gizlilik Politikası, Cepte Şef (\"biz\", \"bizim\") olarak Uygulamayı kullandığınızda kişisel verilerinizi nasıl topladığımızı, kullandığımızı, sakladığımızı ve koruduğumuzu açıklamaktadır. Uygulamayı kullanarak bu politikada açıklanan veri uygulamalarını kabul etmiş olursunuz.\n\n2. TOPLADIĞIMIZ VERİLER\n\n2.1 Sağladığınız Bilgiler:\n(a) Hesap bilgileri: ad, e-posta adresi, şifre (şifrelenmiş);\n(b) Profil tercihleri: diyet kısıtlamaları, alerjiler, yemek tercihleri;\n(c) Kullanıcı tarafından oluşturulan içerik: kaydedilen tarifler, yemek planı tercihleri.\n\n2.2 Otomatik Olarak Toplanan Bilgiler:\n(a) Cihaz bilgileri: cihaz türü, işletim sistemi, benzersiz cihaz tanımlayıcıları;\n(b) Kullanım verileri: uygulama etkileşimleri, kullanılan özellikler, zaman damgaları;\n(c) Performans verileri: çökme raporları, hata günlükleri.\n\n2.3 Yapay Zeka Etkileşim Verileri:\n(a) Yapay zeka sistemine gönderilen sorgular ve istemler;\n(b) Yapay zeka tarafından üretilen yanıtlar ve öneriler;\n(c) Yapay zeka içeriğine verilen kullanıcı geri bildirimleri.\n\n3. VERİLERİNİZİ NASIL KULLANIRIZ\n\nVerilerinizi aşağıdaki amaçlarla kullanırız:\n(a) Yemek planları ve tarif önerilerini sağlamak ve kişiselleştirmek;\n(b) Hesabınızı oluşturmak ve yönetmek;\n(c) Yapay zeka öneri doğruluğunu artırmak;\n(d) Kullanım kalıplarını analiz etmek ve Uygulamayı geliştirmek;\n(e) Hizmet güncellemelerini ve önemli bildirimleri iletmek;\n(f) Güvenliği sağlamak ve dolandırıcılığı önlemek;\n(g) Yasal yükümlülüklere uymak.\n\n4. VERİ DEPOLAMA VE GÜVENLİK\n\n(a) Verileriniz Firebase (Google Cloud) sunucularında saklanır;\n(b) Şifreler şifrelenir ve hiçbir zaman düz metin olarak saklanmaz;\n(c) Aktarım sırasında ve beklemede şifreleme dahil endüstri standardı güvenlik önlemleri uygularız;\n(d) Çabalarımıza rağmen, hiçbir aktarım veya depolama yöntemi %100 güvenli değildir. Mutlak güvenliği garanti edemeyiz;\n(e) Veriler, Google Cloud\'un faaliyet gösterdiği çeşitli ülkelerde saklanabilir ve işlenebilir.\n\n5. ÜÇÜNCÜ TARAFLARLA VERİ PAYLAŞIMI\n\n5.1 Aşağıdaki üçüncü taraf hizmetleriyle veri paylaşırız:\n(a) Firebase (Google) — kimlik doğrulama, veri depolama, analitik;\n(b) Google Gemini AI — yapay zeka sorgularını işlemek ve kişiselleştirilmiş içerik üretmek.\n\n5.2 Yapay zeka hizmetleriyle paylaşılan veriler:\n(a) Kişiselleştirilmiş öneriler üretmek için diyet tercihleriniz, alerjileriniz ve yemek tercihleriniz Google Gemini\'ye gönderilir;\n(b) Bu veriler Google\'ın Gizlilik Politikasına göre işlenir;\n(c) Google\'ın yapay zeka hizmetlerine gönderilen verileri nasıl işlediğini kontrol etmemiz mümkün değildir.\n\n5.3 Kişisel verilerinizi pazarlama amacıyla üçüncü taraflara SATMAYIZ, KİRALAMAYIZ veya TAKAS ETMEYİZ.\n\n5.4 Yasalar, düzenlemeler, yasal süreçler veya hükümet talepleri gerektirdiğinde verilerinizi ifşa edebiliriz.\n\n6. HAKLARINIZ\n\nYürürlükteki yasalara tabi olarak aşağıdaki haklara sahipsiniz:\n(a) Kişisel verilerinize erişim;\n(b) Yanlış verileri düzeltme;\n(c) Hesabınızı ve ilişkili verileri silme;\n(d) Verilerinizi taşınabilir formatta dışa aktarma;\n(e) Veri işleme için verilen onayı geri çekme;\n(f) Kişisel verilerinizin işlenmesine itiraz etme;\n(g) Denetim makamına şikayette bulunma.\n\nBu haklarınızı kullanmak için Uygulama üzerinden bizimle iletişime geçin.\n\n7. VERİ SAKLAMA SÜRESİ\n\n(a) Hesabınız aktif olduğu sürece verilerinizi saklarız;\n(b) Hesap silinmesi üzerine kişisel verileriniz 30 gün içinde silinecektir;\n(c) Bazı veriler yasal gereklilikler veya meşru iş amaçları için daha uzun süre tutulabilir;\n(d) Anonimleştirilmiş ve toplu veriler analitik amacıyla süresiz olarak tutulabilir.\n\n8. ÇOCUKLARIN GİZLİLİĞİ\n\nUygulama 13 yaşın altındaki çocuklara yönelik değildir. 13 yaşın altındaki çocuklardan bilerek kişisel veri toplamayız. Böyle bir toplama yapıldığını öğrenirsek, ilgili verileri derhal sileriz.\n\n9. ÇEREZLER VE İZLEME\n\nUygulama, işlevsellik ve analitik amaçları için yerel depolama ve benzeri teknolojiler kullanabilir. Bunlar Uygulamanın düzgün çalışması için gereklidir.\n\n10. ULUSLARARASI VERİ AKTARIMI\n\nVerileriniz, ikamet ettiğiniz ülke dışındaki ülkelere aktarılabilir ve buralarda işlenebilir; bu ülkeler aynı düzeyde veri koruma sağlamayabilir. Uygulamayı kullanarak bu tür aktarımlara onay vermiş olursunuz.\n\n11. POLİTİKA DEĞİŞİKLİKLERİ\n\nBu Gizlilik Politikasını zaman zaman güncelleyebiliriz. Önemli değişiklikler Uygulama üzerinden bildirilecektir. Değişikliklerden sonra kullanıma devam etmeniz kabul anlamına gelir.\n\n12. VERİ İHLALİ BİLDİRİMİ\n\nHaklarınız ve özgürlükleriniz için yüksek risk oluşturan bir veri ihlali durumunda, etkilenen kullanıcıları ve ilgili makamları yürürlükteki yasaların gerektirdiği şekilde bilgilendireceğiz.\n\n13. İLETİŞİM\n\nGizlilikle ilgili sorularınız veya veri haklarınızı kullanmak için Uygulama üzerinden bizimle iletişime geçin.\n\n14. UYGULANACAK HUKUK\n\nBu Gizlilik Politikası, 6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) dahil Türkiye Cumhuriyeti kanunlarına tabidir.';

  @override
  String get inbox => 'Gelen Kutusu';

  @override
  String get noNotifications => 'Henüz bildirim yok';

  @override
  String get today => 'Bugün';

  @override
  String get yesterday => 'Dün';

  @override
  String get notificationDeleted => 'Bildirim silindi';

  @override
  String get onboardingProgress => 'Onboarding Progress';

  @override
  String onboardingStepOf(Object current, Object total) {
    return 'Adım $current / $total';
  }

  @override
  String get onboardingContinue => 'Devam Et';

  @override
  String get onboardingBack => 'Geri';

  @override
  String get onboardingSkip => 'Şimdilik Atla';

  @override
  String get onboardingCuisineTitle => 'Neleri seversiniz?';

  @override
  String get onboardingCuisineSubtitle =>
      'Size özel bir plan hazırlayabilmemiz için favori mutfaklarınızı seçin.';

  @override
  String get cuisineTurkish => 'Türk Mutfağı';

  @override
  String get cuisineMediterranean => 'Akdeniz';

  @override
  String get cuisineHomeCooking => 'Ev Yemekleri';

  @override
  String get cuisineAsian => 'Uzak Doğu';

  @override
  String get cuisineHealthy => 'Fit & Sağlıklı';

  @override
  String get cuisineWorld => 'Dünya Mutfağı';

  @override
  String get cuisineSeafood => 'Deniz Ürünleri';

  @override
  String get cuisineStreetFood => 'Sokak Lezzetleri';

  @override
  String get cuisineGrill => 'Izgara & Mangal';

  @override
  String get cuisineItalian => 'İtalyan';

  @override
  String get cuisineMexican => 'Meksika';

  @override
  String get cuisineFastFood => 'Fast Food';

  @override
  String get cuisineVegan => 'Vegan Mutfak';

  @override
  String get cuisineDesserts => 'Tatlılar';

  @override
  String get cuisineSoups => 'Çorbalar';

  @override
  String get cuisineSalads => 'Salatalar';

  @override
  String get cuisinePastry => 'Hamur İşleri';

  @override
  String get cuisineFrench => 'Fransız';

  @override
  String get cuisineMiddleEast => 'Ortadoğu';

  @override
  String get cuisineOnePot => 'Tek Tencere';

  @override
  String get cuisineSnacks => 'Atıştırmalıklar';

  @override
  String get cuisineKids => 'Bebek & Çocuk';

  @override
  String get cuisineGlutenFree => 'Glutensiz';

  @override
  String get cuisineQuickBreakfast => 'Hızlı Kahvaltı';

  @override
  String get cuisineSouthAmerican => 'Güney Amerika';

  @override
  String get onboardingAllergyTitle =>
      'Özel bir diyetiniz veya alerjiniz var mı?';

  @override
  String get onboardingAllergySubtitle =>
      'Size en uygun tarifleri sunabilmemiz için beslenme tercihlerinizi belirleyin.';

  @override
  String get allergiesSection => 'Alerjiler';

  @override
  String get dietsSection => 'Diyetler';

  @override
  String get allergyGluten => 'Gluten';

  @override
  String get allergyPeanut => 'Yer Fıstığı';

  @override
  String get allergyDairy => 'Süt';

  @override
  String get allergyEgg => 'Yumurta';

  @override
  String get allergySoy => 'Soya';

  @override
  String get allergySeafood => 'Deniz Ürünleri';

  @override
  String get dietVegetarian => 'Vejetaryen';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietKeto => 'Keto';

  @override
  String get dietWeightLoss => 'Sağlıklı Kilo Verme';

  @override
  String get dietWeightGain => 'Sağlıklı Kilo Alma';

  @override
  String get dietHighProtein => 'Yüksek Protein';

  @override
  String get dietLowCarb => 'Düşük Karbonhidrat';

  @override
  String get dietDiabetic => 'Diyabet Dostu';

  @override
  String get allergyAddCustom => 'Kendi alerjini ekle';

  @override
  String get allergyAddCustomTitle => 'Özel Alerji Ekle';

  @override
  String get allergyAddCustomHint => 'Örn: Susam, Hardal...';

  @override
  String get allergyAddCustomButton => 'Ekle';

  @override
  String get allergyAddCustomCancel => 'İptal';

  @override
  String get onboardingAllergyInfoTitle => 'Kişiselleştirilmiş Mutfak';

  @override
  String get onboardingAllergyInfoDesc =>
      'Seçimlerinize göre 2.000+ tarif filtrelenerek size en güvenli ve lezzetli menüler sunulacak.';

  @override
  String get onboardingMealTitle => 'ÖĞÜN TERCİHLERİ';

  @override
  String get onboardingMealQuestion => 'Günde kaç öğün beslenirsiniz?';

  @override
  String get onboardingMealSubtitle =>
      'Yaşam tarzınıza en uygun öğün düzenini seçin, listenizi ona göre hazırlayalım.';

  @override
  String get mealSlotKahvalti => 'Kahvaltı';

  @override
  String get mealSlotOgle => 'Öğle Yemeği';

  @override
  String get mealSlotAksam => 'Akşam Yemeği';

  @override
  String get mealSlotAraOgun => 'Ara Öğün';

  @override
  String get onboardingMealSlotTitle => 'Hangi öğünleri planlayalım?';

  @override
  String get onboardingMealSlotDesc =>
      'Günlük planınızda hangi öğünlerin yer alacağını seçin. Daha sonra değiştirebilirsiniz.';

  @override
  String get mealSlotMinimumWarning => 'En az bir öğün seçilmelidir';

  @override
  String get onboardingMealQuote =>
      '\"Düzenli beslenme, mutfaktaki en büyük yardımcınızdır.\"';

  @override
  String get onboardingHouseholdTitle => 'Yemekler kaç kişilik hazırlanacak?';

  @override
  String get onboardingHouseholdSubtitle =>
      'Size en uygun porsiyonları ve alışveriş listesini hazırlayabilmemiz için ev halkı sayısını seçin.';

  @override
  String get householdSolo => 'Sadece Ben';

  @override
  String get householdCouple => 'Çiftler';

  @override
  String get householdSmallFamily => 'Küçük Aile';

  @override
  String get householdLargeFamily => 'Kalabalık';

  @override
  String get householdCustom => 'Özel';

  @override
  String get householdCustomHint => 'Örn: 6, 8, 10...';

  @override
  String get householdInfoText =>
      'Dilediğiniz zaman ayarlardan değiştirebilirsiniz.';

  @override
  String get onboardingDislikesTitle => 'Neleri Sevmezsiniz?';

  @override
  String get onboardingDislikesSubtitle =>
      'Yemek planınızda görmek istemediğiniz malzemeleri seçerek size en uygun tarifleri hazırlamamıza yardımcı olun.';

  @override
  String get onboardingDislikesOptional => '(Opsiyonel)';

  @override
  String get dislikesVegetables => 'Sebzeler';

  @override
  String get dislikesFruits => 'Meyveler';

  @override
  String get dislikesProteins => 'Proteinler';

  @override
  String get dislikeEggplant => 'Patlıcan';

  @override
  String get dislikeCelery => 'Kereviz';

  @override
  String get dislikeOkra => 'Bamya';

  @override
  String get dislikeCabbage => 'Lahana';

  @override
  String get dislikeBroccoli => 'Brokoli';

  @override
  String get dislikeSpinach => 'Ispanak';

  @override
  String get dislikeAvocado => 'Avokado';

  @override
  String get dislikePineapple => 'Ananas';

  @override
  String get dislikeFig => 'İncir';

  @override
  String get dislikeCoconut => 'Hindistan Cevizi';

  @override
  String get dislikeSeafood => 'Deniz Ürünü';

  @override
  String get dislikeRedMeat => 'Kırmızı Et';

  @override
  String get dislikeChicken => 'Tavuk';

  @override
  String get dislikeLegumes => 'Baklagil';

  @override
  String get dislikeOrgan => 'Sakatat';

  @override
  String get dislikeAddCustom => 'Kendi malzemeni ekle';

  @override
  String get dislikeAddCustomTitle => 'Sevmediğin Malzeme Ekle';

  @override
  String get dislikeAddCustomHint => 'Örn: Mantar, Zeytin...';

  @override
  String get onboardingComplete => 'Planımı Oluştur';

  @override
  String get mealPlanGeneratingTitle => 'Planınız Hazırlanıyor...';

  @override
  String get mealPlanGeneratingSubtitle =>
      'AI şefimiz size özel haftalık yemek planınızı oluşturuyor';

  @override
  String get mealPlanGeneratingError =>
      'Yemek planı oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String get mealPlanRetry => 'Tekrar Dene';

  @override
  String get mealPlanPreviewTitle => 'Haftalık Planınız';

  @override
  String get mealPlanConfirm => 'Planı Onayla';

  @override
  String get mealPlanRegenerate => 'Yeniden Oluştur';

  @override
  String get mealPlanChangeRecipe => 'Değiştir';

  @override
  String get mealPlanChangeRecipeHint => 'Yerine ne istersiniz? (opsiyonel)';

  @override
  String mealPlanMinutes(Object count) {
    return '$count dk';
  }

  @override
  String mealPlanServings(Object count) {
    return '$count kişilik';
  }

  @override
  String get slotKahvalti => 'Kahvaltı';

  @override
  String get slotOgle => 'Öğle';

  @override
  String get slotAksam => 'Akşam';

  @override
  String get slotAraOgun => 'Ara Öğün';

  @override
  String get slotAnaOgun => 'Ana Öğün';

  @override
  String get slotAtistirmalik => 'Atıştırmalık';

  @override
  String get homeWeeklyPlan => 'Bu Haftaki Planın';

  @override
  String get homeWeeklyPlanSubtitle => 'Sağlıklı seçimler, mutlu günler.';

  @override
  String get homeNoPlan => 'Henüz yemek planı yok';

  @override
  String get homeNoPlanDesc =>
      'İlk haftalık yemek planınızı oluşturarak başlayın!';

  @override
  String get homeCreatePlan => 'Plan Oluştur';

  @override
  String get homeDifficultyKolay => 'Kolay';

  @override
  String get homeDifficultyOrta => 'Orta';

  @override
  String get homeDifficultyZor => 'Zor';

  @override
  String get navHome => 'Ana Sayfa';

  @override
  String get navProfile => 'Profil';

  @override
  String get navRecipes => 'Tarifler';

  @override
  String get navShopping => 'Alışveriş';

  @override
  String get shoppingTitle => 'Alışveriş Listesi';

  @override
  String get shoppingSelectMeals => 'Öğünleri Seç';

  @override
  String get shoppingSelectAll => 'Tümünü Seç';

  @override
  String get shoppingDeselectAll => 'Tümünü Kaldır';

  @override
  String get shoppingGenerateList => 'Liste Oluştur';

  @override
  String get shoppingEmptyPlan =>
      'Alışveriş listesi oluşturmak için önce bir haftalık plan üretmelisiniz.';

  @override
  String get shoppingNoSelection => 'En az bir öğün seçin';

  @override
  String shoppingItemCount(Object count) {
    return '$count malzeme';
  }

  @override
  String get shoppingCopied => 'Alışveriş listesi kopyalandı!';

  @override
  String get shoppingDeleteTitle => 'Listeyi Sil';

  @override
  String get shoppingDeleteMessage =>
      'Bu alışveriş listesi kalıcı olarak silinecek.';

  @override
  String get shoppingSaved => 'Alışveriş listesi kaydedildi!';

  @override
  String get shoppingMyLists => 'Listelerim';

  @override
  String get shoppingNewList => 'Yeni Liste';

  @override
  String get shoppingAddItemHint => 'Malzeme ekle (ör: 2 kg domates)';

  @override
  String get shoppingItemAdded => 'Eklendi';

  @override
  String get shoppingItemDeleted => 'Silindi';

  @override
  String get shoppingManualList => 'Manuel Liste';

  @override
  String get shoppingManualListDesc =>
      'Boş bir liste oluştur, malzemeleri kendin ekle';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileLogout => 'Çıkış Yap';

  @override
  String get profileDeleteAccount => 'Hesabı Sil';

  @override
  String get profileDeleteAccountTitle => 'Hesabı Sil';

  @override
  String get profileDeleteAccountMessage =>
      'Hesabınızı silmek istediğinizden emin misiniz? Tüm verileriniz kalıcı olarak silinecektir. Bu işlem geri alınamaz.';

  @override
  String get profileDeleteAccountConfirm => 'Sil';

  @override
  String get profileDeleteAccountCancel => 'İptal';

  @override
  String get profileDeleteAccountSuccess => 'Hesabınız silindi.';

  @override
  String get profileDeleteAccountError =>
      'Hesap silinemedi. Lütfen tekrar deneyin.';

  @override
  String get profileLogoutTitle => 'Çıkış Yap';

  @override
  String get profileLogoutMessage =>
      'Çıkış yapmak istediğinizden emin misiniz?';

  @override
  String get profileLogoutConfirm => 'Çıkış Yap';

  @override
  String get profileLogoutCancel => 'İptal';

  @override
  String get profileAccountSection => 'Hesap';

  @override
  String get profileEmail => 'E-posta';

  @override
  String get profileName => 'İsim';

  @override
  String get navSuggest => 'Yemek Önerisi';

  @override
  String get suggestTitle => 'Ne yemek istersiniz?';

  @override
  String get suggestHint => 'Örn: Hafif bir akşam yemeği, tavuklu bir şey...';

  @override
  String get suggestDefault =>
      'Bugün ne yesek? Canının çektiğini yaz, sana harika bir tarif bulayım! 🍳';

  @override
  String get suggestSend => 'Gönder';

  @override
  String get suggestGenerating => 'Tarif hazırlanıyor...';

  @override
  String get suggestAddToPlan => 'Plana Ekle';

  @override
  String get suggestPickDay => 'Hangi gün?';

  @override
  String get suggestPickSlot => 'Hangi öğün?';

  @override
  String get suggestAdded => 'Tarif plana eklendi!';

  @override
  String get suggestReplaceConfirm =>
      'Bu öğünde zaten bir tarif var. Ne yapmak istersiniz?';

  @override
  String get suggestReplace => 'Değiştir';

  @override
  String get suggestAddAlongside => 'Ekleme Yap';

  @override
  String get suggestCancel => 'İptal';

  @override
  String get addMealSourceTitle => 'Nasıl eklemek istersiniz?';

  @override
  String get addMealSourceAI => 'AI ile Ekle';

  @override
  String get addMealSourceAIDesc => 'Asistan sizin için tarif önersin';

  @override
  String get addMealSourceSaved => 'Kaydedilenlerden Ekle';

  @override
  String get addMealSourceSavedDesc => 'Kayıtlı tariflerinizden seçin';

  @override
  String get addMealSourceSavedEmpty => 'Henüz kaydedilen tarif yok';

  @override
  String get addMealSourceSavedSearch => 'Tarif ara...';

  @override
  String get profilePreferencesSection => 'Tercihlerim';

  @override
  String get profileCuisines => 'Mutfak Tercihleri';

  @override
  String get profileAllergies => 'Alerjiler';

  @override
  String get profileDiets => 'Diyetler';

  @override
  String get profileMealPlan => 'Öğün Planı';

  @override
  String get profileHousehold => 'Kişi Sayısı';

  @override
  String get profileDislikes => 'Sevmedikleri';

  @override
  String get profileNoneSelected => 'Seçim yapılmadı';

  @override
  String profilePersonCount(Object count) {
    return '$count Kişi';
  }

  @override
  String get profileEditSave => 'Kaydet';

  @override
  String get profilePreferencesSaved => 'Tercihleriniz güncellendi.';

  @override
  String get profilePreferencesError =>
      'Tercihler güncellenemedi. Lütfen tekrar deneyin.';

  @override
  String get profileAppVersion => 'Sürüm';

  @override
  String get homeDailySourceTitle => 'Nasıl eklemek istersiniz?';

  @override
  String get homeDailySourceSaved => 'Kaydedilenlerden Seç';

  @override
  String get homeDailySourceSavedDesc =>
      'Daha önce kaydettiğin tariflerden ekle';

  @override
  String get homeDailySourceAI => 'AI ile Tarif Al';

  @override
  String get homeDailySourceAIDesc => 'Chatbot ile yeni tarif önerisi al';

  @override
  String get homeDailySavedPickerTitle => 'Kaydedilen Tarifler';

  @override
  String get homeDailySavedPickerEmpty =>
      'Henüz kaydedilen tarif yok.\nTarif tarayarak veya AI önerileriyle koleksiyon oluşturun.';

  @override
  String homeDailySavedAdded(Object recipeName) {
    return '$recipeName öğüne eklendi!';
  }

  @override
  String get homeDailyDeleteTitle => 'Tarifi Sil';

  @override
  String homeDailyDeleteMessage(Object recipeName) {
    return '$recipeName bu öğünden silinecek. Emin misiniz?';
  }

  @override
  String get homeDailyDeleteConfirm => 'Sil';

  @override
  String get homeDailyDeleteCancel => 'İptal';

  @override
  String homeDailyDeleted(Object recipeName) {
    return '$recipeName silindi.';
  }

  @override
  String get shareReceived => 'Paylaşılan görsel analiz ediliyor...';

  @override
  String shareSuccess(Object recipeName) {
    return '$recipeName kaydedilenlerinize eklendi!';
  }

  @override
  String get shareError => 'Paylaşılan görsel analiz edilemedi.';

  @override
  String get shareLoginRequired => 'Tarifi kaydetmek için giriş yapmalısınız.';

  @override
  String get homePlanExpired => 'Bu haftanın planı sona erdi';

  @override
  String get homePlanExpiredDesc => 'Bu hafta için yeni bir plan oluşturun!';

  @override
  String get homeNewWeekPlan => 'Yeni Hafta Planla';

  @override
  String homePlanCountdown(Object count) {
    return 'Bu haftanın planı $count gün sonra bitiyor';
  }

  @override
  String get homePlanCountdownTomorrow => 'Bu haftanın planı yarın bitiyor!';

  @override
  String get homeRegenerateRemaining => 'Kalan Günleri Yenile';

  @override
  String get homeRegeneratingRemaining => 'Kalan günler yenileniyor...';

  @override
  String get homeRegenerateSuccess => 'Kalan günler yenilendi!';

  @override
  String get homeRegeneratingDay => 'Gün yenileniyor...';

  @override
  String get homeRegeneratingDaySubtitle =>
      'AI şefimiz yeni tarifler hazırlıyor';

  @override
  String get homeRegeneratingSlot => 'Tarif yenileniyor...';

  @override
  String get homeRegeneratingSlotSubtitle => 'Yeni bir tarif hazırlanıyor';

  @override
  String homeSlotRefreshed(Object recipeName) {
    return '$recipeName yenilendi!';
  }

  @override
  String get homeWeeklyEdit => 'Planı Düzenle';

  @override
  String get homeWeeklyEditTitle => 'Plan Düzenleme';

  @override
  String get homeWeeklyEditRegenRemaining => 'Kalan Günleri Yenile';

  @override
  String get homeWeeklyEditRegenRemainingDesc =>
      'Bugünden itibaren öğünleri yeniden oluştur';

  @override
  String get homeWeeklyEditNewPlan => 'Yeni Hafta Planla';

  @override
  String get homeWeeklyEditNewPlanDesc => 'Tüm haftayı sıfırdan oluştur';

  @override
  String get homeWeeklyEditRegenDay => 'Bu Günü Yenile';

  @override
  String get homeWeeklyEditRegenDayDesc =>
      'Sadece seçili günün öğünlerini yenile';

  @override
  String get homeRefreshDialogTitle => 'Tarifi Yenile';

  @override
  String homeRefreshDialogDesc(Object recipeName) {
    return '$recipeName yerine yeni bir tarif önerilecek.';
  }

  @override
  String get homeRefreshDialogHint =>
      'Örn: Daha hafif bir şey, daha fazla protein...';

  @override
  String get homeRefreshAutoButton => 'Otomatik Yenile';

  @override
  String get homeRefreshWithDescButton => 'AI ile Yenile';

  @override
  String get savedFilterAll => 'Tümü';

  @override
  String get savedFilterQuick => 'Hızlı (≤30dk)';

  @override
  String get savedFilterMedium => 'Orta (30-60dk)';

  @override
  String get savedFilterLong => 'Uzun (60dk+)';

  @override
  String get savedStarred => 'Favoriler';

  @override
  String get savedStarAdded => 'Favorilere eklendi';

  @override
  String get savedStarRemoved => 'Favorilerden çıkarıldı';

  @override
  String get savedRatedLoved => 'Bayıldım';

  @override
  String get savedRatedGood => 'Güzel';

  @override
  String get profileMyRatings => 'Değerlendirmelerim';

  @override
  String get profileMyRatingsEmpty => 'Henüz değerlendirme yok';

  @override
  String get profileRatingRemoved => 'Değerlendirme kaldırıldı';

  @override
  String get profileRatingUpdated => 'Değerlendirme güncellendi';

  @override
  String get addToShoppingList => 'Alışveriş Listesine Ekle';

  @override
  String get createNewList => 'Yeni Liste Oluştur';

  @override
  String get addedToList => 'Listeye eklendi';

  @override
  String get addToPlan => 'Plana Ekle';

  @override
  String get saveRecipeButton => 'Kaydet';

  @override
  String get recipeAlreadySaved => 'Zaten kayıtlı!';

  @override
  String get recipeSavedSuccess => 'Tarif kaydedildi!';

  @override
  String get selectDay => 'Gün Seç';

  @override
  String get selectMeal => 'Öğün Seç';

  @override
  String get addedToPlan => 'Plana eklendi';

  @override
  String get noPlanAvailable =>
      'Bu hafta için plan yok. Önce bir plan oluşturun.';

  @override
  String get savedGroupDate => 'Tarihe Göre';

  @override
  String get savedGroupDuration => 'Süreye Göre';

  @override
  String get savedGroupCuisine => 'Mutfağa Göre';

  @override
  String get savedGroupToday => 'Bugün';

  @override
  String get savedGroupYesterday => 'Dün';

  @override
  String get savedGroupThisWeek => 'Bu Hafta';

  @override
  String get savedGroupThisMonth => 'Bu Ay';

  @override
  String get savedGroupOlder => 'Daha Eski';

  @override
  String get savedGroupQuickRecipes => 'Hızlı (≤30dk)';

  @override
  String get savedGroupMediumRecipes => 'Orta (30-60dk)';

  @override
  String get savedGroupLongRecipes => 'Uzun (60dk+)';

  @override
  String get homeNoPlanForDay => 'Bu gün için plan yok';

  @override
  String get homeNoPlanForDayDesc => 'Bu güne plan eklemek ister misiniz?';

  @override
  String get homeNextWeekNoPlan => 'Bu hafta için plan oluşturulmadı';

  @override
  String get homeNextWeekNoPlanDesc =>
      'Bu haftanın tarifini üretmek ister misiniz?';

  @override
  String get homeNextWeekGenerate => 'Haftalık Plan Oluştur';

  @override
  String savedSelectMode(Object count) {
    return '$count tarif seçildi';
  }

  @override
  String get savedDeleteSelected => 'Seçilenleri Sil';

  @override
  String get savedDeleteConfirmTitle => 'Tarifleri Sil';

  @override
  String savedDeleteConfirmMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bu $count tarif kalıcı olarak silinecek.',
      one: 'Bu tarif kalıcı olarak silinecek.',
    );
    return '$_temp0';
  }

  @override
  String get savedDeleteConfirmButton => 'Sil';

  @override
  String savedDeleteSuccess(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tarif silindi.',
      one: 'Tarif silindi.',
    );
    return '$_temp0';
  }

  @override
  String get savedDeleteSingleTitle => 'Tarifi Sil';

  @override
  String get savedDeleteSingleMessage =>
      'Bu tarif kaydedilenlerden kalıcı olarak silinecek.';

  @override
  String get tagAll => 'Tümü';

  @override
  String get tagManage => 'Etiketleri Yönet';

  @override
  String get tagAdd => 'Etiket Ekle';

  @override
  String get tagName => 'Etiket adı';

  @override
  String get tagColor => 'Renk';

  @override
  String get tagSave => 'Kaydet';

  @override
  String get tagDelete => 'Etiketi Sil';

  @override
  String get tagDeleteConfirm =>
      'Bu etiket tüm tariflerden kaldırılacak. Devam edilsin mi?';

  @override
  String get tagEmpty => 'Henüz etiket oluşturulmadı';

  @override
  String get tagEditRecipe => 'Etiketle';

  @override
  String get tagCreated => 'Etiket oluşturuldu';

  @override
  String get tagDeleted => 'Etiket silindi';

  @override
  String get tagUpdated => 'Etiketler güncellendi';

  @override
  String get tagNoTag => 'Etiketsiz';

  @override
  String get cancel => 'İptal';

  @override
  String get priceComparisonTitle => 'Fiyat Karşılaştırma';

  @override
  String get priceComparisonError =>
      'Fiyat verileri yüklenemedi. Lütfen tekrar deneyin.';

  @override
  String get priceComparisonOptimalPlan => 'Akıllı Alışveriş Planı';

  @override
  String get priceComparisonEstimatedTotal => 'Tahmini Toplam';

  @override
  String priceComparisonFoundCount(Object found, Object total) {
    return '$found / $total ürün bulundu';
  }

  @override
  String priceComparisonMarketCount(Object count) {
    return '$count markette';
  }

  @override
  String get priceComparisonViewOptimal => 'Akıllı Öneri';

  @override
  String get priceComparisonViewByMarket => 'Market Bazlı';

  @override
  String get priceComparisonViewByItem => 'Ürün Bazlı';

  @override
  String get priceComparisonNotFound => 'Fiyat bulunamadı';

  @override
  String get priceComparisonCheapest => 'EN UYGUN';

  @override
  String get priceComparisonEmpty =>
      'Listenizdeki ürünler için güncel fiyat verisi bulunamadı.';

  @override
  String get priceComparisonButton => 'Fiyat Karşılaştır';

  @override
  String get priceComparisonButtonDesc =>
      'En uygun marketi bul, akıllı alışveriş yap';

  @override
  String get priceComparisonDataSource => 'Veri kaynağı: marketfiyati.org.tr';

  @override
  String priceComparisonLastUpdate(Object date) {
    return 'Son güncelleme: $date';
  }

  @override
  String get priceComparisonLastUpdateYesterday => '(dün)';

  @override
  String priceComparisonLastUpdateDaysAgo(Object days) {
    return '($days gün önce)';
  }

  @override
  String get priceComparisonDisclaimerTitle => 'Veri Kaynağı Hakkında';

  @override
  String get priceComparisonDisclaimer =>
      'Bu ekranda gösterilen fiyat verileri, T.C. Sanayi ve Teknoloji Bakanlığı koordinasyonunda TÜBİTAK BİLGEM tarafından geliştirilen marketfiyati.org.tr platformundan alınmaktadır.\n\nVeriler; A101, BİM, CarrefourSA, Hakmar, Migros, Tarım Kredi Kooperatifleri ve ŞOK marketleri tarafından sağlanan bilgilere dayanmaktadır.\n\nCepte Şef, fiyat verilerinin doğruluğu, güncelliği veya eksiksizliği konusunda herhangi bir garanti vermemekte olup, gösterilen fiyatlar yalnızca bilgilendirme amaçlıdır. Gerçek mağaza fiyatları konum, stok durumu ve kampanyalara bağlı olarak farklılık gösterebilir.\n\nCepte Şef bu verilerin kullanımından doğabilecek herhangi bir zarardan sorumlu tutulamaz.';

  @override
  String homeScanProgress(Object current, Object total) {
    return 'Tarif taranıyor ($current/$total)...';
  }

  @override
  String homeScanMultiSuccess(Object count) {
    return '$count tarif başarıyla tarandı';
  }

  @override
  String homeScanMultiPartial(Object success, Object total, Object failed) {
    return '$success/$total tarif tarandı ($failed başarısız)';
  }

  @override
  String get manualPlanTitle => 'Kendi Planını Oluştur';

  @override
  String get manualPlanSubtitle =>
      'Yemek adlarını yaz, detayları AI tamamlasın';

  @override
  String get manualPlanMealHint => 'ör. Mercimek Çorbası';

  @override
  String get manualPlanComplete => 'Planı Tamamla';

  @override
  String get manualPlanEmpty => 'En az bir yemek adı girin';

  @override
  String get manualPlanEnriching => 'Tarifleriniz zenginleştiriliyor...';

  @override
  String get daySelectionManualOption => 'Kendi Planını Yaz';

  @override
  String get daySelectionAIOption => 'AI ile Oluştur';

  @override
  String get familyPlan => 'Aile Planı';

  @override
  String get familyPlanSubtitle =>
      'Ailenizle yemek planı, alışveriş ve tarifleri paylaşın';

  @override
  String get familyPlanCreate => 'Aile Planı Oluştur';

  @override
  String get familyPlanJoin => 'Aile Planına Katıl';

  @override
  String get familyPlanName => 'Plan Adı';

  @override
  String get familyPlanNameHint => 'ör. Yavuz Ailesi';

  @override
  String get familyPlanCode => 'Davet Kodu';

  @override
  String get familyPlanCodeHint => '6 haneli kodu girin';

  @override
  String get familyPlanCreated => 'Aile planı oluşturuldu!';

  @override
  String get familyPlanJoined => 'Aile planına katıldınız!';

  @override
  String get familyPlanInvalidCode => 'Geçersiz veya süresi dolmuş kod';

  @override
  String get familyPlanMembers => 'Üyeler';

  @override
  String get familyPlanOwner => 'Yönetici';

  @override
  String get familyPlanLeave => 'Plandan Ayrıl';

  @override
  String get familyPlanLeaveConfirm =>
      'Aile planından ayrılmak istediğinize emin misiniz?';

  @override
  String get familyPlanLeft => 'Aile planından ayrıldınız';

  @override
  String get familyPlanInviteCode => 'Davet Kodu';

  @override
  String get familyPlanInviteCodeExpiry => 'Kod 24 saat geçerli';

  @override
  String get familyPlanRefreshCode => 'Yeni Kod Oluştur';

  @override
  String get familyPlanShareCode => 'Kodu Paylaş';

  @override
  String get familyPlanDeleteConfirm =>
      'Aile planını silmek istediğinize emin misiniz? Tüm üyeler ayrılacak.';

  @override
  String get familyPlanNoMembers => 'Henüz başka üye yok';

  @override
  String get familyPlanCopied => 'Davet kodu kopyalandı';
}
