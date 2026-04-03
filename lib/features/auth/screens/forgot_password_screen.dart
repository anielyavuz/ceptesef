import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_gradient_button.dart';

/// Şifre sıfırlama ekranı — Stitch tasarımına uygun
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _emailError = null);

    if (_emailController.text.trim().isEmpty) {
      setState(() => _emailError = l10n.errorEmptyField);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.sendPasswordResetEmail(email: _emailController.text.trim());

      if (!mounted) return;
      // Başarı mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.resetEmailSent),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        switch (e.code) {
          case 'invalid-email':
            _emailError = l10n.errorInvalidEmail;
          case 'user-not-found':
            _emailError = l10n.errorUserNotFound;
          case 'too-many-requests':
            _emailError = l10n.errorTooManyRequests;
          default:
            _emailError = l10n.errorGeneral;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _emailError = AppLocalizations.of(context).errorGeneral);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Kilit ikonu
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Hafif gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.05),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Icon(
                        Icons.lock_reset_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Başlık
                Text(
                  l10n.forgotPasswordTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.charcoal,
                        height: 1.2,
                      ),
                ),
                const SizedBox(height: 12),

                // Açıklama
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.forgotPasswordSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.5),
                          height: 1.5,
                        ),
                  ),
                ),
                const SizedBox(height: 40),

                // Form kartı
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
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
                    children: [
                      // E-posta alanı
                      AuthTextField(
                        controller: _emailController,
                        label: l10n.email,
                        hint: l10n.emailHint,
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        errorText: _emailError,
                      ),
                      const SizedBox(height: 28),

                      // Bağlantı Gönder butonu
                      PrimaryGradientButton(
                        label: l10n.sendResetLink,
                        isLoading: _isLoading,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onTap: _sendResetLink,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Giriş ekranına dön
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                  label: Text(
                    l10n.backToLogin,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
