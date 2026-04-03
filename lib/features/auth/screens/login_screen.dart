import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../main.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_gradient_button.dart';
import '../widgets/social_login_button.dart';
import 'forgot_password_screen.dart';
import '../../onboarding/screens/onboarding_screen.dart';

/// Giriş yap ekranı — Stitch tasarımına uygun
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  /// Google/Apple butonları gösterilsin mi?
  bool get _showSocialButtons {
    final config = globalAppConfig.googleAppleButtons;
    if (config == 'open') return true;
    if (config == 'test') {
      final email = _emailController.text.trim().toLowerCase();
      return email == 'a@a.com' || email == 'mtmt@gmail.com';
    }
    return false; // "close" veya bilinmeyen değer
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Validasyon
    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = l10n.errorEmptyField);
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = l10n.errorEmptyField);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _emailError = l10n.errorInvalidEmail;
          case 'user-not-found':
            _emailError = l10n.errorUserNotFound;
          case 'wrong-password':
          case 'invalid-credential':
            _passwordError = l10n.errorWrongPassword;
          case 'too-many-requests':
            _passwordError = l10n.errorTooManyRequests;
          default:
            _passwordError = l10n.errorGeneral;
        }
      });
    } catch (_) {
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
            // Hero bölümü — üstte yemek görseli ve başlık
            SizedBox(
              height: size.height * 0.38,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Arka plan görseli
                  Image.asset(
                    'assets/system/welcomePage.jpeg',
                    fit: BoxFit.cover,
                  ),
                  // Koyu gradient overlay (metin okunabilirliği için)
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
                  // Başlık metni
                  Positioned(
                    bottom: 48,
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
                          l10n.loginHeroTitle,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form kartı — hero'nun üzerine biner
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
                    // Başlık
                    Text(
                      l10n.loginTitle,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.loginSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.charcoal.withValues(alpha: 0.5),
                          ),
                    ),
                    const SizedBox(height: 28),

                    // Email
                    AuthTextField(
                      controller: _emailController,
                      label: l10n.email,
                      hint: l10n.emailHint,
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: globalAppConfig.googleAppleButtons == 'test'
                          ? (_) => setState(() {})
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Şifre
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            l10n.password.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                  color: AppColors.charcoal.withValues(alpha: 0.5),
                                ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              l10n.forgotPassword,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signIn(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.charcoal,
                          ),
                      decoration: InputDecoration(
                        hintText: l10n.passwordHint,
                        hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.charcoal.withValues(alpha: 0.3),
                            ),
                        errorText: _passwordError,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 12),
                          child: Icon(Icons.lock_outline_rounded,
                              color: AppColors.charcoal.withValues(alpha: 0.4), size: 22),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.charcoal.withValues(alpha: 0.4),
                            size: 22,
                          ),
                        ),
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              BorderSide(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 1),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Giriş Yap butonu
                    PrimaryGradientButton(
                      label: l10n.signIn,
                      isLoading: _isLoading,
                      onTap: _signIn,
                    ),
                  ],
                ),
              ),
            ),

            // VEYA ayırıcı + Sosyal giriş butonları (config'e göre)
            if (_showSocialButtons) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.or,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: AppColors.charcoal.withValues(alpha: 0.3),
                            ),
                      ),
                    ),
                    Expanded(child: Divider(color: AppColors.border, thickness: 1)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
            ],
            const SizedBox(height: 28),

            // Kayıt ol bağlantısı
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.noAccount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.charcoal.withValues(alpha: 0.5),
                      ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ),
                  child: Text(
                    l10n.signUp,
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
