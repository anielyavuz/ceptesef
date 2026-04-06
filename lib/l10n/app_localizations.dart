import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('tr'),
  ];

  /// Uygulama başlığı
  ///
  /// In en, this message translates to:
  /// **'Cepte Sef'**
  String get appTitle;

  /// Karşılama mesajı
  ///
  /// In en, this message translates to:
  /// **'Welcome to Cepte Sef!'**
  String get welcomeMessage;

  /// Yükleniyor metni
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Genel hata mesajı
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneral;

  /// Tekrar dene butonu
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Ayarlar
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Dil seçimi
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Türkçe dil adı
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// İngilizce dil adı
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// Giriş yap başlığı
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// Giriş yap alt başlığı
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to continue'**
  String get loginSubtitle;

  /// Giriş ekranı hero başlığı
  ///
  /// In en, this message translates to:
  /// **'Welcome back to\nthe Kitchen.'**
  String get loginHeroTitle;

  /// E-posta etiketi
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// E-posta placeholder
  ///
  /// In en, this message translates to:
  /// **'example@mail.com'**
  String get emailHint;

  /// Şifre etiketi
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Şifre placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get passwordHint;

  /// Giriş yap butonu
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// Şifremi unuttum bağlantısı
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgotPassword;

  /// Veya ayırıcı
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get or;

  /// Google ile devam et
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get continueWithGoogle;

  /// Apple ile devam et
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get continueWithApple;

  /// Hesabınız yok mu?
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get noAccount;

  /// Kayıt ol bağlantısı
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// Hesap oluştur başlığı
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// Hesap oluştur alt başlığı
  ///
  /// In en, this message translates to:
  /// **'Join Cepte Sef and start your journey.'**
  String get registerSubtitle;

  /// Kayıt ekranı hero başlığı
  ///
  /// In en, this message translates to:
  /// **'Your Kitchen\'s\nNew Rhythm.'**
  String get registerHeroTitle;

  /// Kayıt ekranı hero alt başlığı
  ///
  /// In en, this message translates to:
  /// **'Fresh ingredients, flawless recipes and your personal nutrition assistant.'**
  String get registerHeroSubtitle;

  /// Ad soyad etiketi
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// Ad soyad placeholder
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get fullNameHint;

  /// Koşullar metni başlangıcı
  ///
  /// In en, this message translates to:
  /// **'I have read and accept the '**
  String get termsText;

  /// Kullanım koşulları
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// ve bağlacı
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// Gizlilik politikası
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Kayıt ol butonu
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get register;

  /// Veya şununla devam et
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// Zaten hesabınız var mı?
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// Şifremi unuttum başlığı
  ///
  /// In en, this message translates to:
  /// **'Forgot Your\nPassword?'**
  String get forgotPasswordTitle;

  /// Şifremi unuttum açıklama
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a password reset link.'**
  String get forgotPasswordSubtitle;

  /// Bağlantı gönder butonu
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// Giriş ekranına dön
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get backToLogin;

  /// Şifre sıfırlama e-postası gönderildi
  ///
  /// In en, this message translates to:
  /// **'Password reset link has been sent to your email.'**
  String get resetEmailSent;

  /// Geçersiz email hatası
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errorInvalidEmail;

  /// Zayıf şifre hatası
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get errorWeakPassword;

  /// Email zaten kullanımda hatası
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get errorEmailInUse;

  /// Yanlış şifre hatası
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get errorWrongPassword;

  /// Kullanıcı bulunamadı hatası
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get errorUserNotFound;

  /// Çok fazla deneme hatası
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get errorTooManyRequests;

  /// Boş alan hatası
  ///
  /// In en, this message translates to:
  /// **'This field cannot be empty.'**
  String get errorEmptyField;

  /// Koşulları kabul et hatası
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms and conditions.'**
  String get errorAcceptTerms;

  /// Yakında gelecek bildirimi
  ///
  /// In en, this message translates to:
  /// **'Coming soon!'**
  String get comingSoon;

  /// Çıkış yap
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Yasal popup kapat butonu
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get legalClose;

  /// Kullanım koşulları popup başlığı
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfServiceTitle;

  /// Kullanım koşulları içeriği
  ///
  /// In en, this message translates to:
  /// **'CEPTE SEF — TERMS OF SERVICE\n\nLast Updated: March 2026\n\n1. ACCEPTANCE OF TERMS\n\nBy creating an account or using Cepte Sef (\"Application\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree with any part of these Terms, you must not use the Application.\n\n2. SERVICE DESCRIPTION\n\nCepte Sef is a smart kitchen assistant that provides personalized weekly meal plans, recipe suggestions, and nutritional guidance using artificial intelligence technology. The Application is provided \"as is\" and \"as available.\"\n\n3. AI-GENERATED CONTENT DISCLAIMER\n\nThe Application uses artificial intelligence (Google Gemini) to generate meal plans, recipes, and nutritional information. YOU EXPRESSLY ACKNOWLEDGE AND AGREE THAT:\n\n(a) AI-generated content may contain inaccuracies, errors, or omissions;\n(b) Recipes and meal plans are generated automatically and have NOT been reviewed, verified, or approved by licensed nutritionists, dietitians, or medical professionals;\n(c) Nutritional values, calorie counts, and ingredient information provided are approximate estimates and may be inaccurate;\n(d) You are solely responsible for verifying all ingredients, cooking instructions, temperatures, and preparation methods before use;\n(e) The Application does not replace professional medical, nutritional, or dietary advice.\n\n4. ALLERGY AND HEALTH WARNING\n\nCRITICAL WARNING: While the Application attempts to consider user-specified allergies and dietary restrictions, NO GUARANTEE IS MADE that AI-generated recipes will be free from allergens or ingredients that may pose health risks.\n\n(a) You must independently verify all ingredients in every recipe for potential allergens;\n(b) Cross-contamination risks are not accounted for in AI-generated content;\n(c) If you have severe allergies, food intolerances, or medical dietary requirements, consult a qualified healthcare professional before following any recipe or meal plan;\n(d) The Company shall not be liable for any allergic reaction, adverse health effect, or injury resulting from the use of AI-generated recipes.\n\n5. USER ACCOUNTS\n\n(a) You must provide accurate and complete registration information;\n(b) You are responsible for maintaining the confidentiality of your account credentials;\n(c) You are responsible for all activities that occur under your account;\n(d) You must be at least 13 years old to create an account;\n(e) We reserve the right to suspend or terminate accounts that violate these Terms.\n\n6. USER CONDUCT\n\nYou agree not to:\n(a) Use the Application for any unlawful purpose;\n(b) Attempt to gain unauthorized access to the Application\'s systems;\n(c) Reverse engineer, decompile, or disassemble the Application;\n(d) Use automated systems to access the Application;\n(e) Share your account with third parties.\n\n7. INTELLECTUAL PROPERTY\n\nAll content, trademarks, logos, and intellectual property within the Application are owned by or licensed to Cepte Sef. You may not copy, modify, distribute, or create derivative works without explicit written permission.\n\n8. LIMITATION OF LIABILITY\n\nTO THE MAXIMUM EXTENT PERMITTED BY LAW:\n\n(a) THE COMPANY SHALL NOT BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES;\n(b) THE COMPANY SHALL NOT BE LIABLE FOR ANY LOSS OR DAMAGE ARISING FROM RELIANCE ON AI-GENERATED CONTENT;\n(c) THE COMPANY SHALL NOT BE LIABLE FOR ANY HEALTH ISSUES, ALLERGIC REACTIONS, OR INJURIES RESULTING FROM FOLLOWING RECIPES OR MEAL PLANS;\n(d) THE COMPANY\'S TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT PAID BY YOU FOR THE APPLICATION IN THE PRECEDING 12 MONTHS;\n(e) THE COMPANY SHALL NOT BE LIABLE FOR ANY SERVICE INTERRUPTIONS, DATA LOSS, OR SYSTEM FAILURES.\n\n9. INDEMNIFICATION\n\nYou agree to indemnify and hold harmless Cepte Sef, its officers, directors, employees, and agents from any claims, damages, losses, or expenses arising from your use of the Application or violation of these Terms.\n\n10. THIRD-PARTY SERVICES\n\nThe Application integrates with third-party services (Firebase, Google Gemini). These services are governed by their own terms and privacy policies. The Company is not responsible for the availability, accuracy, or practices of third-party services.\n\n11. MODIFICATIONS\n\nWe reserve the right to modify these Terms at any time. Continued use of the Application after modifications constitutes acceptance of the updated Terms. Material changes will be notified through the Application.\n\n12. TERMINATION\n\nWe may terminate or suspend your access to the Application at any time, with or without cause, with or without notice. Upon termination, your right to use the Application ceases immediately.\n\n13. GOVERNING LAW\n\nThese Terms shall be governed by and construed in accordance with the laws of the Republic of Turkey. Any disputes shall be resolved in the courts of Istanbul, Turkey.\n\n14. SEVERABILITY\n\nIf any provision of these Terms is held invalid or unenforceable, the remaining provisions shall continue in full force and effect.\n\n15. CONTACT\n\nFor questions about these Terms, contact us through the Application.'**
  String get termsOfServiceContent;

  /// Gizlilik politikası popup başlığı
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicyTitle;

  /// Haftalık plan modu
  ///
  /// In en, this message translates to:
  /// **'Weekly Plan'**
  String get homeWeeklyMode;

  /// Günlük plan modu
  ///
  /// In en, this message translates to:
  /// **'Daily Plan'**
  String get homeDailyMode;

  /// Günlük plan başlığı
  ///
  /// In en, this message translates to:
  /// **'Daily Plan'**
  String get homeDailyTitle;

  /// Günlük plan alt başlığı
  ///
  /// In en, this message translates to:
  /// **'Add meals to your slots and plan the day.'**
  String get homeDailySubtitle;

  /// Yemek ekle butonu
  ///
  /// In en, this message translates to:
  /// **'Add Meal'**
  String get homeDailyAddMeal;

  /// Günlük plan boş durum
  ///
  /// In en, this message translates to:
  /// **'No meal added yet.\nTap the + button below and find a recipe with AI!'**
  String get homeDailyEmpty;

  /// Öğün seçimi
  ///
  /// In en, this message translates to:
  /// **'Which meal slot?'**
  String get homeDailyPickSlot;

  /// Tarif tara butonu
  ///
  /// In en, this message translates to:
  /// **'Scan Recipe'**
  String get homeScanRecipe;

  /// Tarif tara açıklama
  ///
  /// In en, this message translates to:
  /// **'Take a photo of a dish or pick from gallery, and AI will recognize the recipe and add it to your saved recipes.'**
  String get homeScanRecipeDesc;

  /// Kamera seçeneği
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get homeScanCamera;

  /// Galeri seçeneği
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get homeScanGallery;

  /// Tarif analiz ediliyor
  ///
  /// In en, this message translates to:
  /// **'Analyzing recipe...'**
  String get homeScanAnalyzing;

  /// Tarif kaydedildi
  ///
  /// In en, this message translates to:
  /// **'{recipeName} added to your saved recipes!'**
  String homeScanSaved(Object recipeName);

  /// Detay butonu
  ///
  /// In en, this message translates to:
  /// **'Detail'**
  String get homeScanViewDetail;

  /// Tarif analiz hatası
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the recipe. Please try again.'**
  String get homeScanError;

  /// Tarif kaydedildi popup başlık
  ///
  /// In en, this message translates to:
  /// **'Recipe Saved!'**
  String get homeScanSuccessTitle;

  /// Tarif kaydedildi popup açıklama
  ///
  /// In en, this message translates to:
  /// **'{recipeName} has been added to your saved recipes.'**
  String homeScanSuccessDesc(Object recipeName);

  /// Plana ekle butonu
  ///
  /// In en, this message translates to:
  /// **'Add to Plan'**
  String get homeScanAddToPlan;

  /// Tarifi görüntüle butonu
  ///
  /// In en, this message translates to:
  /// **'View Recipe'**
  String get homeScanViewRecipe;

  /// Yemek alışkanlıkları başlığı
  ///
  /// In en, this message translates to:
  /// **'My Food Habits'**
  String get profileFoodNoteTitle;

  /// Yemek alışkanlıkları açıklama
  ///
  /// In en, this message translates to:
  /// **'Describe your eating habits and we\'ll consider them when suggesting recipes.'**
  String get profileFoodNoteSubtitle;

  /// Yemek alışkanlıkları placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. I eat light in the evening, I love spicy food, eggs are a must for breakfast...'**
  String get profileFoodNoteHint;

  /// Kaydedilen tarifler
  ///
  /// In en, this message translates to:
  /// **'Saved Recipes'**
  String get profileSavedRecipes;

  /// Boş arşiv
  ///
  /// In en, this message translates to:
  /// **'No saved recipes yet.\nRecipes you add with AI will appear here.'**
  String get profileSavedEmpty;

  /// Gizlilik politikası içeriği
  ///
  /// In en, this message translates to:
  /// **'CEPTE SEF — PRIVACY POLICY\n\nLast Updated: March 2026\n\n1. INTRODUCTION\n\nThis Privacy Policy explains how Cepte Sef (\"we\", \"us\", \"our\") collects, uses, stores, and protects your personal data when you use our Application. By using the Application, you consent to the data practices described in this policy.\n\n2. DATA WE COLLECT\n\n2.1 Information You Provide:\n(a) Account information: name, email address, password (encrypted);\n(b) Profile preferences: dietary restrictions, allergies, food preferences;\n(c) User-generated content: saved recipes, meal plan preferences.\n\n2.2 Automatically Collected Information:\n(a) Device information: device type, operating system, unique device identifiers;\n(b) Usage data: app interactions, features used, timestamps;\n(c) Performance data: crash reports, error logs.\n\n2.3 AI Interaction Data:\n(a) Queries and prompts sent to the AI system;\n(b) AI-generated responses and recommendations;\n(c) User feedback on AI-generated content.\n\n3. HOW WE USE YOUR DATA\n\nWe use your data for the following purposes:\n(a) To provide and personalize meal plans and recipe suggestions;\n(b) To create and manage your account;\n(c) To improve AI recommendation accuracy;\n(d) To analyze usage patterns and improve the Application;\n(e) To communicate service updates and important notices;\n(f) To ensure security and prevent fraud;\n(g) To comply with legal obligations.\n\n4. DATA STORAGE AND SECURITY\n\n(a) Your data is stored on Firebase (Google Cloud) servers;\n(b) Passwords are encrypted and never stored in plain text;\n(c) We implement industry-standard security measures including encryption in transit and at rest;\n(d) Despite our efforts, no method of transmission or storage is 100% secure. We cannot guarantee absolute security;\n(e) Data may be stored and processed in various countries where Google Cloud operates.\n\n5. THIRD-PARTY DATA SHARING\n\n5.1 We share data with the following third-party services:\n(a) Firebase (Google) — authentication, data storage, analytics;\n(b) Google Gemini AI — to process AI queries and generate personalized content.\n\n5.2 Data shared with AI services:\n(a) Your dietary preferences, allergies, and food preferences are sent to Google Gemini to generate personalized recommendations;\n(b) This data is processed according to Google\'s Privacy Policy;\n(c) We do not control how Google processes data sent to its AI services.\n\n5.3 We will NOT sell, rent, or trade your personal data to third parties for marketing purposes.\n\n5.4 We may disclose your data if required by law, regulation, legal process, or governmental request.\n\n6. YOUR RIGHTS\n\nSubject to applicable law, you have the right to:\n(a) Access your personal data;\n(b) Correct inaccurate data;\n(c) Delete your account and associated data;\n(d) Export your data in a portable format;\n(e) Withdraw consent for data processing;\n(f) Object to processing of your personal data;\n(g) Lodge a complaint with a supervisory authority.\n\nTo exercise these rights, contact us through the Application.\n\n7. DATA RETENTION\n\n(a) We retain your data for as long as your account is active;\n(b) Upon account deletion, your personal data will be deleted within 30 days;\n(c) Some data may be retained longer if required by law or for legitimate business purposes;\n(d) Anonymized and aggregated data may be retained indefinitely for analytics.\n\n8. CHILDREN\'S PRIVACY\n\nThe Application is not intended for children under 13. We do not knowingly collect personal data from children under 13. If we become aware of such collection, we will promptly delete the data.\n\n9. COOKIES AND TRACKING\n\nThe Application may use local storage and similar technologies for functionality and analytics purposes. These are essential for the Application to function properly.\n\n10. INTERNATIONAL DATA TRANSFERS\n\nYour data may be transferred to and processed in countries outside your country of residence, including countries that may not provide the same level of data protection. By using the Application, you consent to such transfers.\n\n11. CHANGES TO THIS POLICY\n\nWe may update this Privacy Policy from time to time. We will notify you of material changes through the Application. Continued use after changes constitutes acceptance.\n\n12. DATA BREACH NOTIFICATION\n\nIn the event of a data breach that poses a high risk to your rights and freedoms, we will notify affected users and relevant authorities as required by applicable law.\n\n13. CONTACT\n\nFor privacy-related questions or to exercise your data rights, contact us through the Application.\n\n14. GOVERNING LAW\n\nThis Privacy Policy is governed by the laws of the Republic of Turkey, including the Personal Data Protection Law (KVKK, Law No. 6698).'**
  String get privacyPolicyContent;

  /// Bildirim gelen kutusu
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// Bildirim yok
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// Bugün
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// Dün
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// Bildirim silindi
  ///
  /// In en, this message translates to:
  /// **'Notification deleted'**
  String get notificationDeleted;

  /// Onboarding ilerleme başlığı
  ///
  /// In en, this message translates to:
  /// **'Onboarding Progress'**
  String get onboardingProgress;

  /// Adım X / Y
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStepOf(Object current, Object total);

  /// Devam et butonu
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// Geri butonu
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// Şimdilik atla
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkip;

  /// Mutfak tercihi başlığı
  ///
  /// In en, this message translates to:
  /// **'What do you love?'**
  String get onboardingCuisineTitle;

  /// Mutfak tercihi açıklama
  ///
  /// In en, this message translates to:
  /// **'Choose your favorite cuisines so we can create a personalized plan for you.'**
  String get onboardingCuisineSubtitle;

  /// Türk Mutfağı
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get cuisineTurkish;

  /// Akdeniz
  ///
  /// In en, this message translates to:
  /// **'Mediterranean'**
  String get cuisineMediterranean;

  /// Ev Yemekleri
  ///
  /// In en, this message translates to:
  /// **'Home Cooking'**
  String get cuisineHomeCooking;

  /// Uzak Doğu
  ///
  /// In en, this message translates to:
  /// **'Asian'**
  String get cuisineAsian;

  /// Fit & Sağlıklı
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get cuisineHealthy;

  /// Dünya Mutfağı
  ///
  /// In en, this message translates to:
  /// **'World'**
  String get cuisineWorld;

  /// Deniz Ürünleri
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get cuisineSeafood;

  /// Sokak Lezzetleri
  ///
  /// In en, this message translates to:
  /// **'Street Food'**
  String get cuisineStreetFood;

  /// Izgara & Mangal
  ///
  /// In en, this message translates to:
  /// **'Grill & BBQ'**
  String get cuisineGrill;

  /// İtalyan
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get cuisineItalian;

  /// Meksika
  ///
  /// In en, this message translates to:
  /// **'Mexican'**
  String get cuisineMexican;

  /// Fast Food
  ///
  /// In en, this message translates to:
  /// **'Fast Food'**
  String get cuisineFastFood;

  /// Vegan Mutfak
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get cuisineVegan;

  /// Tatlılar
  ///
  /// In en, this message translates to:
  /// **'Desserts'**
  String get cuisineDesserts;

  /// Çorbalar
  ///
  /// In en, this message translates to:
  /// **'Soups'**
  String get cuisineSoups;

  /// Salatalar
  ///
  /// In en, this message translates to:
  /// **'Salads'**
  String get cuisineSalads;

  /// Hamur İşleri
  ///
  /// In en, this message translates to:
  /// **'Pastry'**
  String get cuisinePastry;

  /// Fransız
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get cuisineFrench;

  /// Ortadoğu
  ///
  /// In en, this message translates to:
  /// **'Middle Eastern'**
  String get cuisineMiddleEast;

  /// Tek Tencere
  ///
  /// In en, this message translates to:
  /// **'One Pot'**
  String get cuisineOnePot;

  /// Atıştırmalıklar
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get cuisineSnacks;

  /// Bebek & Çocuk
  ///
  /// In en, this message translates to:
  /// **'Kids Menu'**
  String get cuisineKids;

  /// Glutensiz
  ///
  /// In en, this message translates to:
  /// **'Gluten Free'**
  String get cuisineGlutenFree;

  /// Hızlı Kahvaltı
  ///
  /// In en, this message translates to:
  /// **'Quick Breakfast'**
  String get cuisineQuickBreakfast;

  /// Güney Amerika
  ///
  /// In en, this message translates to:
  /// **'South American'**
  String get cuisineSouthAmerican;

  /// Alerji/diyet başlığı
  ///
  /// In en, this message translates to:
  /// **'Any diets or allergies?'**
  String get onboardingAllergyTitle;

  /// Alerji/diyet açıklama
  ///
  /// In en, this message translates to:
  /// **'Set your nutritional preferences so we can suggest the most suitable recipes.'**
  String get onboardingAllergySubtitle;

  /// Alerjiler başlığı
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get allergiesSection;

  /// Diyetler başlığı
  ///
  /// In en, this message translates to:
  /// **'Diets'**
  String get dietsSection;

  /// Gluten alerjeni
  ///
  /// In en, this message translates to:
  /// **'Gluten'**
  String get allergyGluten;

  /// Yer fıstığı alerjeni
  ///
  /// In en, this message translates to:
  /// **'Peanut'**
  String get allergyPeanut;

  /// Süt alerjeni
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get allergyDairy;

  /// Yumurta alerjeni
  ///
  /// In en, this message translates to:
  /// **'Egg'**
  String get allergyEgg;

  /// Soya alerjeni
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get allergySoy;

  /// Deniz ürünleri alerjeni
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get allergySeafood;

  /// Vejetaryen
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get dietVegetarian;

  /// Vegan
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get dietVegan;

  /// Keto
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get dietKeto;

  /// Sağlıklı Kilo Verme
  ///
  /// In en, this message translates to:
  /// **'Healthy Weight Loss'**
  String get dietWeightLoss;

  /// Sağlıklı Kilo Alma
  ///
  /// In en, this message translates to:
  /// **'Healthy Weight Gain'**
  String get dietWeightGain;

  /// Yüksek Protein
  ///
  /// In en, this message translates to:
  /// **'High Protein'**
  String get dietHighProtein;

  /// Düşük Karbonhidrat
  ///
  /// In en, this message translates to:
  /// **'Low Carb'**
  String get dietLowCarb;

  /// Diyabet Dostu
  ///
  /// In en, this message translates to:
  /// **'Diabetic Friendly'**
  String get dietDiabetic;

  /// Kendi alerjenini ekle
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get allergyAddCustom;

  /// Özel alerji ekle başlığı
  ///
  /// In en, this message translates to:
  /// **'Add Custom Allergy'**
  String get allergyAddCustomTitle;

  /// Özel alerji placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Sesame, Mustard...'**
  String get allergyAddCustomHint;

  /// Ekle butonu
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get allergyAddCustomButton;

  /// İptal
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get allergyAddCustomCancel;

  /// Kişiselleştirilmiş mutfak
  ///
  /// In en, this message translates to:
  /// **'Personalized Kitchen'**
  String get onboardingAllergyInfoTitle;

  /// Kişiselleştirilmiş mutfak açıklama
  ///
  /// In en, this message translates to:
  /// **'Based on your choices, we\'ll filter 2,000+ recipes to suggest the safest and most delicious menus for you.'**
  String get onboardingAllergyInfoDesc;

  /// Öğün tercihleri başlığı
  ///
  /// In en, this message translates to:
  /// **'MEAL PREFERENCES'**
  String get onboardingMealTitle;

  /// Öğün sorusu
  ///
  /// In en, this message translates to:
  /// **'How many meals a day?'**
  String get onboardingMealQuestion;

  /// Öğün açıklama
  ///
  /// In en, this message translates to:
  /// **'Choose the meal plan that fits your lifestyle, and we\'ll prepare your list accordingly.'**
  String get onboardingMealSubtitle;

  /// Kahvaltı slot adı
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealSlotKahvalti;

  /// Öğle slot adı
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealSlotOgle;

  /// Akşam slot adı
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealSlotAksam;

  /// Ara öğün slot adı
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealSlotAraOgun;

  /// Öğün seçimi başlığı
  ///
  /// In en, this message translates to:
  /// **'Which meals should we plan?'**
  String get onboardingMealSlotTitle;

  /// Öğün seçimi açıklaması
  ///
  /// In en, this message translates to:
  /// **'Select which meals you want in your daily plan. You can change this later.'**
  String get onboardingMealSlotDesc;

  /// Min 1 öğün uyarısı
  ///
  /// In en, this message translates to:
  /// **'At least one meal must be selected'**
  String get mealSlotMinimumWarning;

  /// Öğün motivasyon sözü
  ///
  /// In en, this message translates to:
  /// **'\"Balanced nutrition is the kitchen\'s greatest helper.\"'**
  String get onboardingMealQuote;

  /// Hane halkı başlığı
  ///
  /// In en, this message translates to:
  /// **'Cooking for how many?'**
  String get onboardingHouseholdTitle;

  /// Hane halkı açıklama
  ///
  /// In en, this message translates to:
  /// **'Select your household size so we can prepare the right portions and grocery list.'**
  String get onboardingHouseholdSubtitle;

  /// Tek kişi
  ///
  /// In en, this message translates to:
  /// **'Just Me'**
  String get householdSolo;

  /// Çiftler
  ///
  /// In en, this message translates to:
  /// **'Couple'**
  String get householdCouple;

  /// Küçük aile
  ///
  /// In en, this message translates to:
  /// **'Small Family'**
  String get householdSmallFamily;

  /// Kalabalık
  ///
  /// In en, this message translates to:
  /// **'Large Family'**
  String get householdLargeFamily;

  /// Özel sayı girişi
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get householdCustom;

  /// Özel kişi sayısı placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. 6, 8, 10...'**
  String get householdCustomHint;

  /// Alt bilgi metni
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime from settings.'**
  String get householdInfoText;

  /// Sevmedikleri başlığı
  ///
  /// In en, this message translates to:
  /// **'What don\'t you like?'**
  String get onboardingDislikesTitle;

  /// Sevmedikleri açıklama
  ///
  /// In en, this message translates to:
  /// **'Select ingredients you don\'t want to see in your meal plan so we can suggest the best recipes for you.'**
  String get onboardingDislikesSubtitle;

  /// Opsiyonel
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get onboardingDislikesOptional;

  /// Sebzeler
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get dislikesVegetables;

  /// Meyveler
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get dislikesFruits;

  /// Proteinler
  ///
  /// In en, this message translates to:
  /// **'Proteins'**
  String get dislikesProteins;

  /// Patlıcan
  ///
  /// In en, this message translates to:
  /// **'Eggplant'**
  String get dislikeEggplant;

  /// Kereviz
  ///
  /// In en, this message translates to:
  /// **'Celery'**
  String get dislikeCelery;

  /// Bamya
  ///
  /// In en, this message translates to:
  /// **'Okra'**
  String get dislikeOkra;

  /// Lahana
  ///
  /// In en, this message translates to:
  /// **'Cabbage'**
  String get dislikeCabbage;

  /// Brokoli
  ///
  /// In en, this message translates to:
  /// **'Broccoli'**
  String get dislikeBroccoli;

  /// Ispanak
  ///
  /// In en, this message translates to:
  /// **'Spinach'**
  String get dislikeSpinach;

  /// Avokado
  ///
  /// In en, this message translates to:
  /// **'Avocado'**
  String get dislikeAvocado;

  /// Ananas
  ///
  /// In en, this message translates to:
  /// **'Pineapple'**
  String get dislikePineapple;

  /// İncir
  ///
  /// In en, this message translates to:
  /// **'Fig'**
  String get dislikeFig;

  /// Hindistan cevizi
  ///
  /// In en, this message translates to:
  /// **'Coconut'**
  String get dislikeCoconut;

  /// Deniz ürünü
  ///
  /// In en, this message translates to:
  /// **'Seafood'**
  String get dislikeSeafood;

  /// Kırmızı et
  ///
  /// In en, this message translates to:
  /// **'Red Meat'**
  String get dislikeRedMeat;

  /// Tavuk
  ///
  /// In en, this message translates to:
  /// **'Chicken'**
  String get dislikeChicken;

  /// Baklagil
  ///
  /// In en, this message translates to:
  /// **'Legumes'**
  String get dislikeLegumes;

  /// Sakatat
  ///
  /// In en, this message translates to:
  /// **'Organ Meat'**
  String get dislikeOrgan;

  /// Kendi malzemeni ekle
  ///
  /// In en, this message translates to:
  /// **'Add your own'**
  String get dislikeAddCustom;

  /// Sevmediğin malzeme ekle başlığı
  ///
  /// In en, this message translates to:
  /// **'Add Disliked Ingredient'**
  String get dislikeAddCustomTitle;

  /// Sevmediğin malzeme placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Mushroom, Olive...'**
  String get dislikeAddCustomHint;

  /// Planımı oluştur butonu
  ///
  /// In en, this message translates to:
  /// **'Create My Plan'**
  String get onboardingComplete;

  /// Plan oluşturuluyor başlığı
  ///
  /// In en, this message translates to:
  /// **'Preparing Your Plan...'**
  String get mealPlanGeneratingTitle;

  /// Plan oluşturuluyor açıklama
  ///
  /// In en, this message translates to:
  /// **'Our AI chef is creating your personalized weekly meal plan'**
  String get mealPlanGeneratingSubtitle;

  /// Plan oluşturma hatası
  ///
  /// In en, this message translates to:
  /// **'Could not generate meal plan. Please try again.'**
  String get mealPlanGeneratingError;

  /// Tekrar dene butonu
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get mealPlanRetry;

  /// Haftalık plan başlığı
  ///
  /// In en, this message translates to:
  /// **'Your Weekly Plan'**
  String get mealPlanPreviewTitle;

  /// Planı onayla butonu
  ///
  /// In en, this message translates to:
  /// **'Confirm Plan'**
  String get mealPlanConfirm;

  /// Yeniden oluştur
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get mealPlanRegenerate;

  /// Tek tarif değiştir butonu
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get mealPlanChangeRecipe;

  /// Tarif değiştirme hint metni
  ///
  /// In en, this message translates to:
  /// **'What would you like instead? (optional)'**
  String get mealPlanChangeRecipeHint;

  /// Dakika
  ///
  /// In en, this message translates to:
  /// **'{count} min'**
  String mealPlanMinutes(Object count);

  /// Porsiyon
  ///
  /// In en, this message translates to:
  /// **'{count} servings'**
  String mealPlanServings(Object count);

  /// Kahvaltı
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get slotKahvalti;

  /// Öğle
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get slotOgle;

  /// Akşam
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get slotAksam;

  /// Ara öğün
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get slotAraOgun;

  /// Ana öğün
  ///
  /// In en, this message translates to:
  /// **'Main Meal'**
  String get slotAnaOgun;

  /// Atıştırmalık
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get slotAtistirmalik;

  /// Bu haftanın planı
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Plan'**
  String get homeWeeklyPlan;

  /// Plan alt başlığı
  ///
  /// In en, this message translates to:
  /// **'Healthy choices, happy days.'**
  String get homeWeeklyPlanSubtitle;

  /// Plan yok
  ///
  /// In en, this message translates to:
  /// **'No meal plan yet'**
  String get homeNoPlan;

  /// Plan yok açıklama
  ///
  /// In en, this message translates to:
  /// **'Start by creating your first weekly meal plan!'**
  String get homeNoPlanDesc;

  /// Plan oluştur
  ///
  /// In en, this message translates to:
  /// **'Create Plan'**
  String get homeCreatePlan;

  /// Kolay zorluk
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get homeDifficultyKolay;

  /// Orta zorluk
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get homeDifficultyOrta;

  /// Zor zorluk
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get homeDifficultyZor;

  /// Navbar ana sayfa
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Navbar profil
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Navbar tarifler
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get navRecipes;

  /// Navbar alışveriş
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get navShopping;

  /// Alışveriş başlığı
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingTitle;

  /// Öğün seç
  ///
  /// In en, this message translates to:
  /// **'Select Meals'**
  String get shoppingSelectMeals;

  /// Tümünü seç
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get shoppingSelectAll;

  /// Tümünü kaldır
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get shoppingDeselectAll;

  /// Liste oluştur
  ///
  /// In en, this message translates to:
  /// **'Generate List'**
  String get shoppingGenerateList;

  /// Plan yok
  ///
  /// In en, this message translates to:
  /// **'Create a weekly meal plan first to generate a shopping list.'**
  String get shoppingEmptyPlan;

  /// Seçim yok
  ///
  /// In en, this message translates to:
  /// **'Select at least one meal'**
  String get shoppingNoSelection;

  /// Malzeme sayısı
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String shoppingItemCount(Object count);

  /// Liste kopyalandı
  ///
  /// In en, this message translates to:
  /// **'Shopping list copied!'**
  String get shoppingCopied;

  /// Listeyi sil başlık
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get shoppingDeleteTitle;

  /// Listeyi sil mesaj
  ///
  /// In en, this message translates to:
  /// **'This shopping list will be permanently deleted.'**
  String get shoppingDeleteMessage;

  /// Liste kaydedildi
  ///
  /// In en, this message translates to:
  /// **'Shopping list saved!'**
  String get shoppingSaved;

  /// Listelerim
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get shoppingMyLists;

  /// Yeni liste
  ///
  /// In en, this message translates to:
  /// **'New List'**
  String get shoppingNewList;

  /// Malzeme ekle placeholder
  ///
  /// In en, this message translates to:
  /// **'Add item (e.g. 2 kg tomatoes)'**
  String get shoppingAddItemHint;

  /// Eklendi
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get shoppingItemAdded;

  /// Silindi
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get shoppingItemDeleted;

  /// Manuel liste
  ///
  /// In en, this message translates to:
  /// **'Manual List'**
  String get shoppingManualList;

  /// Manuel liste açıklama
  ///
  /// In en, this message translates to:
  /// **'Create an empty list, add items yourself'**
  String get shoppingManualListDesc;

  /// Profil ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Çıkış yap butonu
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogout;

  /// Hesabı sil butonu
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccount;

  /// Hesap silme dialog başlığı
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get profileDeleteAccountTitle;

  /// Hesap silme onay mesajı
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? All your data will be permanently deleted. This action cannot be undone.'**
  String get profileDeleteAccountMessage;

  /// Hesap silme onay butonu
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDeleteAccountConfirm;

  /// Hesap silme iptal butonu
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileDeleteAccountCancel;

  /// Hesap silme başarılı mesajı
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get profileDeleteAccountSuccess;

  /// Hesap silme hata mesajı
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get profileDeleteAccountError;

  /// Çıkış dialog başlığı
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogoutTitle;

  /// Çıkış onay mesajı
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get profileLogoutMessage;

  /// Çıkış onay butonu
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get profileLogoutConfirm;

  /// Çıkış iptal butonu
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileLogoutCancel;

  /// Hesap bölümü başlığı
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountSection;

  /// E-posta etiketi
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// İsim etiketi
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// Navbar yemek önerisi
  ///
  /// In en, this message translates to:
  /// **'Suggest'**
  String get navSuggest;

  /// Öneri modal başlığı
  ///
  /// In en, this message translates to:
  /// **'What would you like to eat?'**
  String get suggestTitle;

  /// Öneri input placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. A light dinner, something with chicken...'**
  String get suggestHint;

  /// Varsayılan chatbot mesajı
  ///
  /// In en, this message translates to:
  /// **'What kind of meal would you like? Share your details and I\'ll suggest a personalized recipe! 🍳'**
  String get suggestDefault;

  /// Gönder butonu
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get suggestSend;

  /// Tarif hazırlanıyor
  ///
  /// In en, this message translates to:
  /// **'Preparing recipe...'**
  String get suggestGenerating;

  /// Plana ekle butonu
  ///
  /// In en, this message translates to:
  /// **'Add to Plan'**
  String get suggestAddToPlan;

  /// Gün seçimi
  ///
  /// In en, this message translates to:
  /// **'Which day?'**
  String get suggestPickDay;

  /// Öğün seçimi
  ///
  /// In en, this message translates to:
  /// **'Which meal?'**
  String get suggestPickSlot;

  /// Plana eklendi mesajı
  ///
  /// In en, this message translates to:
  /// **'Recipe added to plan!'**
  String get suggestAdded;

  /// Değiştirme onayı
  ///
  /// In en, this message translates to:
  /// **'There\'s already a recipe in this slot. What would you like to do?'**
  String get suggestReplaceConfirm;

  /// Değiştir butonu
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get suggestReplace;

  /// Mevcut tarifin yanına ekleme
  ///
  /// In en, this message translates to:
  /// **'Add Alongside'**
  String get suggestAddAlongside;

  /// İptal butonu
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get suggestCancel;

  /// Öğüne ekleme kaynak seçici başlık
  ///
  /// In en, this message translates to:
  /// **'How would you like to add?'**
  String get addMealSourceTitle;

  /// AI ile ekle seçeneği
  ///
  /// In en, this message translates to:
  /// **'Add with AI'**
  String get addMealSourceAI;

  /// AI ile ekle açıklama
  ///
  /// In en, this message translates to:
  /// **'Let the assistant suggest a recipe'**
  String get addMealSourceAIDesc;

  /// Kaydedilenlerden ekle seçeneği
  ///
  /// In en, this message translates to:
  /// **'From Saved Recipes'**
  String get addMealSourceSaved;

  /// Kaydedilenlerden ekle açıklama
  ///
  /// In en, this message translates to:
  /// **'Pick from your saved recipes'**
  String get addMealSourceSavedDesc;

  /// Kaydedilen tarif yok mesajı
  ///
  /// In en, this message translates to:
  /// **'No saved recipes yet'**
  String get addMealSourceSavedEmpty;

  /// Tarif arama placeholder
  ///
  /// In en, this message translates to:
  /// **'Search recipes...'**
  String get addMealSourceSavedSearch;

  /// Profil tercihler bölümü başlığı
  ///
  /// In en, this message translates to:
  /// **'My Preferences'**
  String get profilePreferencesSection;

  /// Mutfak tercihleri
  ///
  /// In en, this message translates to:
  /// **'Cuisine Preferences'**
  String get profileCuisines;

  /// Alerjiler
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get profileAllergies;

  /// Diyetler
  ///
  /// In en, this message translates to:
  /// **'Diets'**
  String get profileDiets;

  /// Öğün planı
  ///
  /// In en, this message translates to:
  /// **'Meal Plan'**
  String get profileMealPlan;

  /// Kişi sayısı
  ///
  /// In en, this message translates to:
  /// **'Household Size'**
  String get profileHousehold;

  /// Sevmedikleri
  ///
  /// In en, this message translates to:
  /// **'Dislikes'**
  String get profileDislikes;

  /// Seçim yapılmadı
  ///
  /// In en, this message translates to:
  /// **'None selected'**
  String get profileNoneSelected;

  /// Kişi sayısı
  ///
  /// In en, this message translates to:
  /// **'{count} People'**
  String profilePersonCount(Object count);

  /// Kaydet butonu
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileEditSave;

  /// Tercihler güncellendi
  ///
  /// In en, this message translates to:
  /// **'Your preferences have been updated.'**
  String get profilePreferencesSaved;

  /// Tercih güncelleme hatası
  ///
  /// In en, this message translates to:
  /// **'Failed to update preferences. Please try again.'**
  String get profilePreferencesError;

  /// Uygulama versiyon etiketi
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get profileAppVersion;

  /// Kaynak seçimi başlığı
  ///
  /// In en, this message translates to:
  /// **'How would you like to add?'**
  String get homeDailySourceTitle;

  /// Kaydedilenlerden seç
  ///
  /// In en, this message translates to:
  /// **'Choose from Saved'**
  String get homeDailySourceSaved;

  /// Kaydedilenlerden seç açıklama
  ///
  /// In en, this message translates to:
  /// **'Add from your previously saved recipes'**
  String get homeDailySourceSavedDesc;

  /// AI ile tarif al
  ///
  /// In en, this message translates to:
  /// **'Get Recipe with AI'**
  String get homeDailySourceAI;

  /// AI ile tarif al açıklama
  ///
  /// In en, this message translates to:
  /// **'Get a new recipe suggestion from chatbot'**
  String get homeDailySourceAIDesc;

  /// Kaydedilen tarifler seçici başlığı
  ///
  /// In en, this message translates to:
  /// **'Saved Recipes'**
  String get homeDailySavedPickerTitle;

  /// Boş kaydedilen tarifler
  ///
  /// In en, this message translates to:
  /// **'No saved recipes yet.\nScan recipes or get AI suggestions to build your collection.'**
  String get homeDailySavedPickerEmpty;

  /// Kaydedilen tarif eklendi
  ///
  /// In en, this message translates to:
  /// **'{recipeName} added to meal!'**
  String homeDailySavedAdded(Object recipeName);

  /// Tarif silme başlığı
  ///
  /// In en, this message translates to:
  /// **'Delete Recipe'**
  String get homeDailyDeleteTitle;

  /// Tarif silme mesajı
  ///
  /// In en, this message translates to:
  /// **'{recipeName} will be removed from this meal. Are you sure?'**
  String homeDailyDeleteMessage(Object recipeName);

  /// Tarif silme onay
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get homeDailyDeleteConfirm;

  /// Tarif silme iptal
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeDailyDeleteCancel;

  /// Tarif silindi mesajı
  ///
  /// In en, this message translates to:
  /// **'{recipeName} removed.'**
  String homeDailyDeleted(Object recipeName);

  /// Paylaşılan görsel analiz ediliyor
  ///
  /// In en, this message translates to:
  /// **'Analyzing shared image...'**
  String get shareReceived;

  /// Paylaşılan tarif kaydedildi
  ///
  /// In en, this message translates to:
  /// **'{recipeName} added to your saved recipes!'**
  String shareSuccess(Object recipeName);

  /// Paylaşım analiz hatası
  ///
  /// In en, this message translates to:
  /// **'Could not analyze the shared image.'**
  String get shareError;

  /// Giriş gerekli
  ///
  /// In en, this message translates to:
  /// **'Please sign in to save the recipe.'**
  String get shareLoginRequired;

  /// Plan sona erdi
  ///
  /// In en, this message translates to:
  /// **'This week\'s plan has ended'**
  String get homePlanExpired;

  /// Plan sona erdi açıklama
  ///
  /// In en, this message translates to:
  /// **'Create a new plan for this week!'**
  String get homePlanExpiredDesc;

  /// Yeni hafta planla butonu
  ///
  /// In en, this message translates to:
  /// **'Plan New Week'**
  String get homeNewWeekPlan;

  /// Plan geri sayım
  ///
  /// In en, this message translates to:
  /// **'Plan ends in {count} days'**
  String homePlanCountdown(Object count);

  /// Plan yarın bitiyor
  ///
  /// In en, this message translates to:
  /// **'Plan ends tomorrow!'**
  String get homePlanCountdownTomorrow;

  /// Kalan günleri yenile
  ///
  /// In en, this message translates to:
  /// **'Refresh Remaining Days'**
  String get homeRegenerateRemaining;

  /// Kalan günler yenileniyor
  ///
  /// In en, this message translates to:
  /// **'Refreshing remaining days...'**
  String get homeRegeneratingRemaining;

  /// Kalan günler yenilendi
  ///
  /// In en, this message translates to:
  /// **'Remaining days refreshed!'**
  String get homeRegenerateSuccess;

  /// Gün yenileniyor
  ///
  /// In en, this message translates to:
  /// **'Refreshing day...'**
  String get homeRegeneratingDay;

  /// Gün yenileniyor alt metin
  ///
  /// In en, this message translates to:
  /// **'Our AI chef is preparing new recipes'**
  String get homeRegeneratingDaySubtitle;

  /// Slot yenileniyor
  ///
  /// In en, this message translates to:
  /// **'Refreshing recipe...'**
  String get homeRegeneratingSlot;

  /// Slot yenileniyor alt metin
  ///
  /// In en, this message translates to:
  /// **'Preparing a new recipe for you'**
  String get homeRegeneratingSlotSubtitle;

  /// Slot yenilendi
  ///
  /// In en, this message translates to:
  /// **'{recipeName} refreshed!'**
  String homeSlotRefreshed(Object recipeName);

  /// Planı düzenle
  ///
  /// In en, this message translates to:
  /// **'Edit Plan'**
  String get homeWeeklyEdit;

  /// Plan düzenleme başlığı
  ///
  /// In en, this message translates to:
  /// **'Edit Plan'**
  String get homeWeeklyEditTitle;

  /// Kalan günleri yenile
  ///
  /// In en, this message translates to:
  /// **'Refresh Remaining Days'**
  String get homeWeeklyEditRegenRemaining;

  /// Kalan günleri yenile açıklama
  ///
  /// In en, this message translates to:
  /// **'Regenerate meals from today onward'**
  String get homeWeeklyEditRegenRemainingDesc;

  /// Yeni hafta planla
  ///
  /// In en, this message translates to:
  /// **'Plan New Week'**
  String get homeWeeklyEditNewPlan;

  /// Yeni hafta planla açıklama
  ///
  /// In en, this message translates to:
  /// **'Create the whole week from scratch'**
  String get homeWeeklyEditNewPlanDesc;

  /// Bu günü yenile
  ///
  /// In en, this message translates to:
  /// **'Refresh This Day'**
  String get homeWeeklyEditRegenDay;

  /// Bu günü yenile açıklama
  ///
  /// In en, this message translates to:
  /// **'Regenerate only the selected day\'s meals'**
  String get homeWeeklyEditRegenDayDesc;

  /// Tarif yenileme dialog başlığı
  ///
  /// In en, this message translates to:
  /// **'Refresh Recipe'**
  String get homeRefreshDialogTitle;

  /// Tarif yenileme dialog açıklaması
  ///
  /// In en, this message translates to:
  /// **'A new recipe will be suggested instead of {recipeName}.'**
  String homeRefreshDialogDesc(Object recipeName);

  /// Tarif yenileme opsiyonel açıklama hint
  ///
  /// In en, this message translates to:
  /// **'e.g. Something lighter, more protein...'**
  String get homeRefreshDialogHint;

  /// Otomatik yenile butonu
  ///
  /// In en, this message translates to:
  /// **'Auto Refresh'**
  String get homeRefreshAutoButton;

  /// AI ile açıklamalı yenile butonu
  ///
  /// In en, this message translates to:
  /// **'Refresh with AI'**
  String get homeRefreshWithDescButton;

  /// Tümü filtre
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get savedFilterAll;

  /// Hızlı filtre
  ///
  /// In en, this message translates to:
  /// **'Quick (≤30m)'**
  String get savedFilterQuick;

  /// Orta filtre
  ///
  /// In en, this message translates to:
  /// **'Medium (30-60m)'**
  String get savedFilterMedium;

  /// Uzun filtre
  ///
  /// In en, this message translates to:
  /// **'Long (60m+)'**
  String get savedFilterLong;

  /// Favoriler
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get savedStarred;

  /// Favoriye eklendi
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get savedStarAdded;

  /// Favoriden çıkarıldı
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get savedStarRemoved;

  /// Bayıldım bölümü başlığı
  ///
  /// In en, this message translates to:
  /// **'Loved It'**
  String get savedRatedLoved;

  /// Güzel bölümü başlığı
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get savedRatedGood;

  /// Profil değerlendirmelerim başlığı
  ///
  /// In en, this message translates to:
  /// **'My Ratings'**
  String get profileMyRatings;

  /// Değerlendirme yok
  ///
  /// In en, this message translates to:
  /// **'No rated recipes yet'**
  String get profileMyRatingsEmpty;

  /// Değerlendirme kaldırıldı
  ///
  /// In en, this message translates to:
  /// **'Rating removed'**
  String get profileRatingRemoved;

  /// Değerlendirme güncellendi
  ///
  /// In en, this message translates to:
  /// **'Rating updated'**
  String get profileRatingUpdated;

  /// Alışveriş listesine ekle
  ///
  /// In en, this message translates to:
  /// **'Add to Shopping List'**
  String get addToShoppingList;

  /// Yeni liste oluştur
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get createNewList;

  /// Listeye eklendi
  ///
  /// In en, this message translates to:
  /// **'Added to list'**
  String get addedToList;

  /// Plana ekle
  ///
  /// In en, this message translates to:
  /// **'Add to Plan'**
  String get addToPlan;

  /// Tarifi kaydet butonu
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveRecipeButton;

  /// Tarif zaten kayıtlı
  ///
  /// In en, this message translates to:
  /// **'Already saved!'**
  String get recipeAlreadySaved;

  /// Tarif kaydedildi
  ///
  /// In en, this message translates to:
  /// **'Recipe saved!'**
  String get recipeSavedSuccess;

  /// Gün seç
  ///
  /// In en, this message translates to:
  /// **'Select Day'**
  String get selectDay;

  /// Öğün seç
  ///
  /// In en, this message translates to:
  /// **'Select Meal'**
  String get selectMeal;

  /// Plana eklendi
  ///
  /// In en, this message translates to:
  /// **'Added to plan'**
  String get addedToPlan;

  /// Bu hafta için plan yok
  ///
  /// In en, this message translates to:
  /// **'No plan for this week. Create one first.'**
  String get noPlanAvailable;

  /// Tarihe göre grupla
  ///
  /// In en, this message translates to:
  /// **'By Date'**
  String get savedGroupDate;

  /// Süreye göre grupla
  ///
  /// In en, this message translates to:
  /// **'By Duration'**
  String get savedGroupDuration;

  /// Mutfağa göre grupla
  ///
  /// In en, this message translates to:
  /// **'By Cuisine'**
  String get savedGroupCuisine;

  /// Bugün grubu
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get savedGroupToday;

  /// Dün grubu
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get savedGroupYesterday;

  /// Bu hafta grubu
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get savedGroupThisWeek;

  /// Bu ay grubu
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get savedGroupThisMonth;

  /// Daha eski grubu
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get savedGroupOlder;

  /// Hızlı tarifler grubu
  ///
  /// In en, this message translates to:
  /// **'Quick (≤30m)'**
  String get savedGroupQuickRecipes;

  /// Orta süreli tarifler grubu
  ///
  /// In en, this message translates to:
  /// **'Medium (30-60m)'**
  String get savedGroupMediumRecipes;

  /// Uzun süreli tarifler grubu
  ///
  /// In en, this message translates to:
  /// **'Long (60m+)'**
  String get savedGroupLongRecipes;

  /// Bu gün için plan yok
  ///
  /// In en, this message translates to:
  /// **'No plan for this day'**
  String get homeNoPlanForDay;

  /// Bu güne plan ekle açıklama
  ///
  /// In en, this message translates to:
  /// **'Would you like to add a plan for this day?'**
  String get homeNoPlanForDayDesc;

  /// Sonraki hafta için plan yok
  ///
  /// In en, this message translates to:
  /// **'No plan for this week'**
  String get homeNextWeekNoPlan;

  /// Sonraki hafta planı oluştur açıklama
  ///
  /// In en, this message translates to:
  /// **'Would you like to generate a meal plan for this week?'**
  String get homeNextWeekNoPlanDesc;

  /// Haftalık plan oluştur butonu
  ///
  /// In en, this message translates to:
  /// **'Generate Weekly Plan'**
  String get homeNextWeekGenerate;

  /// Seçim modu sayaç
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String savedSelectMode(Object count);

  /// Seçilenleri sil butonu
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get savedDeleteSelected;

  /// Silme onay başlığı
  ///
  /// In en, this message translates to:
  /// **'Delete Recipes'**
  String get savedDeleteConfirmTitle;

  /// Silme onay mesajı
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{This recipe will be permanently deleted.} other{These {count} recipes will be permanently deleted.}}'**
  String savedDeleteConfirmMessage(num count);

  /// Silme onay butonu
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get savedDeleteConfirmButton;

  /// Silme başarılı mesajı
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Recipe deleted.} other{{count} recipes deleted.}}'**
  String savedDeleteSuccess(num count);

  /// Tek tarif silme başlığı
  ///
  /// In en, this message translates to:
  /// **'Delete Recipe'**
  String get savedDeleteSingleTitle;

  /// Tek tarif silme mesajı
  ///
  /// In en, this message translates to:
  /// **'This recipe will be permanently removed from your saved recipes.'**
  String get savedDeleteSingleMessage;

  /// Tüm etiketler filtresi
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tagAll;

  /// Etiket yönetimi başlığı
  ///
  /// In en, this message translates to:
  /// **'Manage Tags'**
  String get tagManage;

  /// Etiket ekle butonu
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get tagAdd;

  /// Etiket adı placeholder
  ///
  /// In en, this message translates to:
  /// **'Tag name'**
  String get tagName;

  /// Renk seçimi etiketi
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get tagColor;

  /// Etiket kaydet butonu
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tagSave;

  /// Etiket sil butonu
  ///
  /// In en, this message translates to:
  /// **'Delete Tag'**
  String get tagDelete;

  /// Etiket silme onay mesajı
  ///
  /// In en, this message translates to:
  /// **'This tag will be removed from all recipes. Continue?'**
  String get tagDeleteConfirm;

  /// Etiket boş durumu
  ///
  /// In en, this message translates to:
  /// **'No tags created yet'**
  String get tagEmpty;

  /// Tarife etiket ekle
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get tagEditRecipe;

  /// Etiket oluşturuldu
  ///
  /// In en, this message translates to:
  /// **'Tag created'**
  String get tagCreated;

  /// Etiket silindi
  ///
  /// In en, this message translates to:
  /// **'Tag deleted'**
  String get tagDeleted;

  /// Etiketler güncellendi
  ///
  /// In en, this message translates to:
  /// **'Tags updated'**
  String get tagUpdated;

  /// Etiketsiz tarif filtresi
  ///
  /// In en, this message translates to:
  /// **'Untagged'**
  String get tagNoTag;

  /// İptal butonu
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Fiyat karşılaştırma başlığı
  ///
  /// In en, this message translates to:
  /// **'Price Comparison'**
  String get priceComparisonTitle;

  /// Fiyat yükleme hatası
  ///
  /// In en, this message translates to:
  /// **'Could not load price data. Please try again.'**
  String get priceComparisonError;

  /// Akıllı alışveriş planı başlığı
  ///
  /// In en, this message translates to:
  /// **'Smart Shopping Plan'**
  String get priceComparisonOptimalPlan;

  /// Tahmini toplam
  ///
  /// In en, this message translates to:
  /// **'Estimated Total'**
  String get priceComparisonEstimatedTotal;

  /// Bulunan ürün sayısı
  ///
  /// In en, this message translates to:
  /// **'{found} / {total} items found'**
  String priceComparisonFoundCount(Object found, Object total);

  /// Market sayısı
  ///
  /// In en, this message translates to:
  /// **'across {count} stores'**
  String priceComparisonMarketCount(Object count);

  /// Akıllı öneri modu
  ///
  /// In en, this message translates to:
  /// **'Smart Pick'**
  String get priceComparisonViewOptimal;

  /// Market bazlı mod
  ///
  /// In en, this message translates to:
  /// **'By Store'**
  String get priceComparisonViewByMarket;

  /// Ürün bazlı mod
  ///
  /// In en, this message translates to:
  /// **'By Item'**
  String get priceComparisonViewByItem;

  /// Fiyat bulunamadı
  ///
  /// In en, this message translates to:
  /// **'Price not found'**
  String get priceComparisonNotFound;

  /// En uygun etiketi
  ///
  /// In en, this message translates to:
  /// **'CHEAPEST'**
  String get priceComparisonCheapest;

  /// Fiyat verisi boş
  ///
  /// In en, this message translates to:
  /// **'No current price data found for items in your list.'**
  String get priceComparisonEmpty;

  /// Fiyat karşılaştır butonu
  ///
  /// In en, this message translates to:
  /// **'Compare Prices'**
  String get priceComparisonButton;

  /// Fiyat karşılaştırma buton açıklaması
  ///
  /// In en, this message translates to:
  /// **'Find the best store, shop smart'**
  String get priceComparisonButtonDesc;

  /// Veri kaynağı
  ///
  /// In en, this message translates to:
  /// **'Data source: marketfiyati.org.tr'**
  String get priceComparisonDataSource;

  /// Son güncelleme tarihi
  ///
  /// In en, this message translates to:
  /// **'Last update: {date}'**
  String priceComparisonLastUpdate(Object date);

  /// Dünün verisi
  ///
  /// In en, this message translates to:
  /// **'(yesterday)'**
  String get priceComparisonLastUpdateYesterday;

  /// X gün önceki veri
  ///
  /// In en, this message translates to:
  /// **'({days} days ago)'**
  String priceComparisonLastUpdateDaysAgo(Object days);

  /// Disclaimer başlığı
  ///
  /// In en, this message translates to:
  /// **'About Data Source'**
  String get priceComparisonDisclaimerTitle;

  /// Yasal uyarı metni
  ///
  /// In en, this message translates to:
  /// **'Price data displayed on this screen is sourced from marketfiyati.org.tr, a platform developed by TÜBİTAK BİLGEM under the coordination of the Republic of Turkey Ministry of Industry and Technology.\n\nData is based on information provided by A101, BİM, CarrefourSA, Hakmar, Migros, Tarım Kredi Cooperatives, and ŞOK supermarkets.\n\nCepte Şef does not guarantee the accuracy, timeliness, or completeness of price data. Prices shown are for informational purposes only. Actual store prices may vary based on location, stock availability, and promotions.\n\nCepte Şef cannot be held responsible for any damages arising from the use of this data.'**
  String get priceComparisonDisclaimer;

  /// Çoklu tarif tarama ilerleme mesajı
  ///
  /// In en, this message translates to:
  /// **'Scanning recipe ({current}/{total})...'**
  String homeScanProgress(Object current, Object total);

  /// Çoklu tarif tarama başarı mesajı
  ///
  /// In en, this message translates to:
  /// **'{count} recipes scanned successfully'**
  String homeScanMultiSuccess(Object count);

  /// Çoklu tarif tarama kısmi başarı mesajı
  ///
  /// In en, this message translates to:
  /// **'{success}/{total} recipes scanned ({failed} failed)'**
  String homeScanMultiPartial(Object success, Object total, Object failed);

  /// Manuel plan ekranı başlığı
  ///
  /// In en, this message translates to:
  /// **'Create Your Own Plan'**
  String get manualPlanTitle;

  /// Manuel plan açıklama metni
  ///
  /// In en, this message translates to:
  /// **'Write your meal names and let AI fill in the details'**
  String get manualPlanSubtitle;

  /// Yemek adı placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g., Lentil Soup'**
  String get manualPlanMealHint;

  /// Planı tamamla butonu
  ///
  /// In en, this message translates to:
  /// **'Complete Plan'**
  String get manualPlanComplete;

  /// Boş plan uyarısı
  ///
  /// In en, this message translates to:
  /// **'Enter at least one meal name'**
  String get manualPlanEmpty;

  /// Manuel plan zenginleştirme yükleniyor
  ///
  /// In en, this message translates to:
  /// **'Enriching your recipes...'**
  String get manualPlanEnriching;

  /// Gün seçim sheet'inde manuel plan seçeneği
  ///
  /// In en, this message translates to:
  /// **'Write Your Own Plan'**
  String get daySelectionManualOption;

  /// Gün seçim sheet'inde AI plan seçeneği
  ///
  /// In en, this message translates to:
  /// **'Generate with AI'**
  String get daySelectionAIOption;

  /// No description provided for @familyPlan.
  ///
  /// In en, this message translates to:
  /// **'Family Plan'**
  String get familyPlan;

  /// No description provided for @familyPlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share meal plans, shopping lists and recipes with your family'**
  String get familyPlanSubtitle;

  /// No description provided for @familyPlanCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Family Plan'**
  String get familyPlanCreate;

  /// No description provided for @familyPlanJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Family Plan'**
  String get familyPlanJoin;

  /// No description provided for @familyPlanName.
  ///
  /// In en, this message translates to:
  /// **'Plan Name'**
  String get familyPlanName;

  /// No description provided for @familyPlanNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Smith Family'**
  String get familyPlanNameHint;

  /// No description provided for @familyPlanCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get familyPlanCode;

  /// No description provided for @familyPlanCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get familyPlanCodeHint;

  /// No description provided for @familyPlanCreated.
  ///
  /// In en, this message translates to:
  /// **'Family plan created!'**
  String get familyPlanCreated;

  /// No description provided for @familyPlanJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined family plan!'**
  String get familyPlanJoined;

  /// No description provided for @familyPlanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid or expired code'**
  String get familyPlanInvalidCode;

  /// No description provided for @familyPlanMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get familyPlanMembers;

  /// No description provided for @familyPlanOwner.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get familyPlanOwner;

  /// No description provided for @familyPlanLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave Plan'**
  String get familyPlanLeave;

  /// No description provided for @familyPlanLeaveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this family plan?'**
  String get familyPlanLeaveConfirm;

  /// No description provided for @familyPlanLeft.
  ///
  /// In en, this message translates to:
  /// **'Left the family plan'**
  String get familyPlanLeft;

  /// No description provided for @familyPlanInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get familyPlanInviteCode;

  /// No description provided for @familyPlanInviteCodeExpiry.
  ///
  /// In en, this message translates to:
  /// **'Code valid for 24 hours'**
  String get familyPlanInviteCodeExpiry;

  /// No description provided for @familyPlanRefreshCode.
  ///
  /// In en, this message translates to:
  /// **'Generate New Code'**
  String get familyPlanRefreshCode;

  /// No description provided for @familyPlanShareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get familyPlanShareCode;

  /// No description provided for @familyPlanDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this family plan? All members will be removed.'**
  String get familyPlanDeleteConfirm;

  /// No description provided for @familyPlanNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No other members yet'**
  String get familyPlanNoMembers;

  /// No description provided for @familyPlanCopied.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get familyPlanCopied;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
