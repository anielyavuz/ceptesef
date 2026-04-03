import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Kullanım Koşulları ve Gizlilik Politikası popup'ı
class LegalPopup {
  LegalPopup._();

  /// Kullanım Koşulları popup'ını gösterir
  static void showTermsOfService(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _showLegalSheet(
      context: context,
      title: l10n.termsOfServiceTitle,
      content: l10n.termsOfServiceContent,
    );
  }

  /// Gizlilik Politikası popup'ını gösterir
  static void showPrivacyPolicy(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    _showLegalSheet(
      context: context,
      title: l10n.privacyPolicyTitle,
      content: l10n.privacyPolicyContent,
    );
  }

  static void _showLegalSheet({
    required BuildContext context,
    required String title,
    required String content,
  }) {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sürükleme çubuğu
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Başlık ve kapat butonu
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        l10n.legalClose,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),

              // İçerik
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                  child: Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal.withValues(alpha: 0.75),
                          height: 1.7,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
