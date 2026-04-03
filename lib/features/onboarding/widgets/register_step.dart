import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../../auth/widgets/legal_popup.dart';

/// Onboarding Adım 6: Hesap oluşturma formu
/// Onboarding akışının son adımı olarak gömülü çalışır.
class RegisterStep extends StatefulWidget {
  final String? nameError;
  final String? emailError;
  final String? passwordError;

  const RegisterStep({
    super.key,
    this.nameError,
    this.emailError,
    this.passwordError,
  });

  @override
  State<RegisterStep> createState() => RegisterStepState();
}

class RegisterStepState extends State<RegisterStep> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Parent tarafından GlobalKey ile erişilir
  String get name => _nameController.text.trim();
  String get email => _emailController.text.trim();
  String get password => _passwordController.text;
  bool get hasAcceptedTerms => _acceptedTerms;

  /// Basit validasyon — boş alan kontrolü
  bool validate(AppLocalizations l10n) {
    if (name.isEmpty || email.isEmpty || password.isEmpty) return false;
    if (password.length < 6) return false;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorAcceptTerms),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.registerHeroTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.registerHeroSubtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),

          // Form kartı
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.charcoal.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ad Soyad
                AuthTextField(
                  controller: _nameController,
                  label: l10n.fullName,
                  hint: l10n.fullNameHint,
                  prefixIcon: Icons.person_outline_rounded,
                  errorText: widget.nameError,
                ),
                const SizedBox(height: 18),

                // E-posta
                AuthTextField(
                  controller: _emailController,
                  label: l10n.email,
                  hint: l10n.emailHint,
                  prefixIcon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  errorText: widget.emailError,
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
                  errorText: widget.passwordError,
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
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
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: _acceptedTerms,
                        onChanged: (v) =>
                            setState(() => _acceptedTerms = v ?? false),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        children: [
                          Text(
                            l10n.termsText,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.charcoal
                                          .withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                LegalPopup.showTermsOfService(context),
                            child: Text(
                              l10n.termsOfService,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                          Text(
                            l10n.and,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.charcoal
                                          .withValues(alpha: 0.6),
                                      height: 1.4,
                                    ),
                          ),
                          GestureDetector(
                            onTap: () => LegalPopup.showPrivacyPolicy(context),
                            child: Text(
                              l10n.privacyPolicy,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
