import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_preferences.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_gradient_button.dart';
import '../widgets/social_login_button.dart';
import '../widgets/legal_popup.dart';
import '../../meal_plan/screens/meal_plan_generation_screen.dart';
import 'login_screen.dart';

/// Hesap oluştur ekranı — Stitch tasarımına uygun
class RegisterScreen extends StatefulWidget {
  final UserPreferences? preferences;

  const RegisterScreen({super.key, this.preferences});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  bool _isLoading = false;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    // Validasyon
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = l10n.errorEmptyField);
      return;
    }
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = l10n.errorEmptyField);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = l10n.errorEmptyField);
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _passwordError = l10n.errorWeakPassword);
      return;
    }
    if (!_acceptedTerms) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorAcceptTerms),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();

      // Firebase Auth ile kullanıcı oluştur
      final credential = await authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Auth başarılı — ek işlemler başarısız olsa bile kullanıcı oluşturuldu
      if (credential.user != null) {
        // Görünen adı güncelle (başarısız olursa auth etkilenmez)
        try {
          await authService.updateDisplayName(_nameController.text.trim());
        } catch (_) {}

        // Firestore'da kullanıcı dokümanı oluştur (başarısız olursa auth etkilenmez)
        try {
          final appUser = AppUser(
            uid: credential.user!.uid,
            email: _emailController.text.trim(),
            displayName: _nameController.text.trim(),
            createdAt: DateTime.now(),
          );
          await firestoreService.createUser(appUser);
        } catch (_) {}

        // Onboarding tercihleri varsa kaydet ve yemek planı oluşturma ekranına yönlendir
        if (widget.preferences != null) {
          try {
            await firestoreService.saveUserPreferences(
              credential.user!.uid,
              widget.preferences!,
            );
          } catch (_) {}

          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (_) => MealPlanGenerationScreen(
                  uid: credential.user!.uid,
                  preferences: widget.preferences!,
                ),
              ),
              (route) => false,
            );
          }
          return;
        }
      }
      // Preferences yoksa AuthWrapper otomatik olarak HomeScreen'e yönlendirecek
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _emailError = l10n.errorInvalidEmail;
          case 'email-already-in-use':
            _emailError = l10n.errorEmailInUse;
          case 'weak-password':
            _passwordError = l10n.errorWeakPassword;
          case 'too-many-requests':
            _passwordError = l10n.errorTooManyRequests;
          default:
            _passwordError = l10n.errorGeneral;
        }
      });
    } catch (e) {
      // Auth hatası değilse de göster
      if (!mounted) return;
      setState(() => _passwordError = AppLocalizations.of(context).errorGeneral);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.comingSoon),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.charcoal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero bölümü
            SizedBox(
              height: size.height * 0.30,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/system/welcomePage.jpeg',
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryDark.withValues(alpha: 0.3),
                          AppColors.primaryDark.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  // Başlık
                  Positioned(
                    bottom: 40,
                    left: 28,
                    right: 28,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CEPTE ŞEF',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                letterSpacing: 3,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.registerHeroTitle,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.registerHeroSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form kartı
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.charcoal.withValues(alpha: 0.06),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.registerTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.registerSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(height: 28),

                    // Ad Soyad
                    AuthTextField(
                      controller: _nameController,
                      label: l10n.fullName,
                      hint: l10n.fullNameHint,
                      prefixIcon: Icons.person_outline_rounded,
                      errorText: _nameError,
                    ),
                    const SizedBox(height: 18),

                    // E-posta
                    AuthTextField(
                      controller: _emailController,
                      label: l10n.email,
                      hint: l10n.emailHint,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                    ),
                    const SizedBox(height: 18),

                    // Şifre
                    AuthTextField(
                      controller: _passwordController,
                      label: l10n.password,
                      hint: l10n.passwordHint,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      errorText: _passwordError,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.charcoal.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Koşullar checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Checkbox(
                              value: _acceptedTerms,
                              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              side: BorderSide(
                                color: AppColors.charcoal.withValues(alpha: 0.25),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            children: [
                              Text(
                                l10n.termsText,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.charcoal.withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                              ),
                              GestureDetector(
                                onTap: () => LegalPopup.showTermsOfService(context),
                                child: Text(
                                  l10n.termsOfService,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                ),
                              ),
                              Text(
                                l10n.and,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.charcoal.withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                              ),
                              GestureDetector(
                                onTap: () => LegalPopup.showPrivacyPolicy(context),
                                child: Text(
                                  l10n.privacyPolicy,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Kayıt Ol butonu
                    PrimaryGradientButton(
                      label: l10n.register,
                      isLoading: _isLoading,
                      trailingIcon: Icons.arrow_forward_rounded,
                      onTap: _register,
                    ),
                  ],
                ),
              ),
            ),

            // VEYA ayırıcı
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      l10n.orContinueWith,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: AppColors.charcoal.withValues(alpha: 0.3),
                          ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Sosyal giriş butonları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: Row(
                children: [
                  Expanded(
                    child: SocialLoginButton(
                      label: l10n.continueWithGoogle,
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                      onTap: _showComingSoon,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SocialLoginButton(
                      label: l10n.continueWithApple,
                      icon: const Icon(Icons.apple_rounded, size: 24),
                      onTap: _showComingSoon,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Giriş yap bağlantısı
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.alreadyHaveAccount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(
                    l10n.signIn,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
