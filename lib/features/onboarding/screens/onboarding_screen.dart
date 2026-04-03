import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../auth/auth_wrapper.dart';
import '../widgets/cuisine_step.dart';
import '../widgets/allergy_diet_step.dart';
import '../widgets/meal_plan_step.dart';
import '../widgets/household_step.dart';
import '../widgets/dislikes_step.dart';
import '../widgets/register_step.dart';

/// Onboarding akışını yöneten ana ekran.
/// 6 adım: 5 tercih + 1 hesap oluşturma → MealPlan generation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _registerKey = GlobalKey<RegisterStepState>();
  int _currentPage = 0;
  bool _isRegistering = false;
  static const _totalPages = 6;

  // Tercih state'leri
  List<String> _mutfaklar = [];
  List<String> _alerjenler = [];
  List<String> _diyetler = [];
  List<String> _secilenOgunler = ['kahvalti', 'ogle', 'aksam'];
  int _kisiSayisi = 1;
  List<String> _sevmedikleri = [];

  // Register hata state'leri
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('onboarding');
    RemoteLoggerService.info('onboarding_started', screen: 'onboarding');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cancelOnboarding(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancel),
        content: const Text('Kayıt işlemini iptal edip giriş ekranına dönmek istiyor musunuz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: const Text('Evet, dön'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Login pushReplacement ile geldiği için pop yerine AuthWrapper'a dön
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _logStepCompleted();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Son adım: hesap oluştur
      _handleRegister();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  bool get _canContinue {
    switch (_currentPage) {
      case 0:
        return _mutfaklar.isNotEmpty;
      case 5:
        return !_isRegistering;
      default:
        return true;
    }
  }

  String _buttonLabel(AppLocalizations l10n) {
    switch (_currentPage) {
      case 5:
        return l10n.onboardingComplete;
      case 4:
        return l10n.onboardingContinue;
      default:
        return l10n.onboardingContinue;
    }
  }

  IconData _buttonIcon() {
    switch (_currentPage) {
      case 5:
        return Icons.auto_awesome_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  void _logStepCompleted() {
    final stepNames = [
      'cuisine', 'allergy_diet', 'meal_plan', 'household', 'dislikes', 'register',
    ];
    if (_currentPage >= stepNames.length) return;
    final stepName = stepNames[_currentPage];
    Map<String, Object> extra;

    switch (_currentPage) {
      case 0:
        extra = {'mutfaklar': _mutfaklar.join(', '), 'count': _mutfaklar.length};
      case 1:
        extra = {
          'alerjenler': _alerjenler.join(', '),
          'diyetler': _diyetler.join(', '),
          'alerjen_count': _alerjenler.length,
          'diyet_count': _diyetler.length,
        };
      case 2:
        extra = {'secilen_ogunler': _secilenOgunler.join(', ')};
      case 3:
        extra = {'kisi_sayisi': _kisiSayisi};
      case 4:
        extra = {
          'sevmedikleri': _sevmedikleri.join(', '),
          'count': _sevmedikleri.length,
        };
      default:
        extra = {};
    }

    RemoteLoggerService.userAction(
      'onboarding_step_${stepName}_completed',
      screen: 'onboarding',
      details: extra,
    );
  }

  UserPreferences _buildPreferences() {
    return UserPreferences(
      mutfaklar: _mutfaklar,
      alerjenler: _alerjenler,
      diyetler: _diyetler,
      secilenOgunler: _secilenOgunler,
      kisiSayisi: _kisiSayisi,
      sevmedikleri: _sevmedikleri,
      onboardingCompleted: true,
    );
  }

  void _printGeminiInput(UserPreferences prefs) {
    final standartAlerjenler =
        prefs.alerjenler.where((a) => !a.startsWith('custom:')).toList();
    final customAlerjenler = prefs.alerjenler
        .where((a) => a.startsWith('custom:'))
        .map((a) => a.replaceFirst('custom:', ''))
        .toList();
    final standartSevmedikleri =
        prefs.sevmedikleri.where((s) => !s.startsWith('custom:')).toList();
    final customSevmedikleri = prefs.sevmedikleri
        .where((s) => s.startsWith('custom:'))
        .map((s) => s.replaceFirst('custom:', ''))
        .toList();

    final geminiInput = const JsonEncoder.withIndent('  ').convert({
      'kullanici_tercihleri': {
        'mutfaklar': prefs.mutfaklar,
        'alerjenler': standartAlerjenler,
        'custom_alerjenler': customAlerjenler,
        'diyetler': prefs.diyetler,
        'secilen_ogunler': prefs.secilenOgunler,
        'kisi_sayisi': prefs.kisiSayisi,
        'sevmedikleri': standartSevmedikleri,
        'custom_sevmedikleri': customSevmedikleri,
      },
    });

    debugPrint('╔══════════════════════════════════════════');
    debugPrint('║  GEMINI INPUT — Kullanıcı Tercihleri');
    debugPrint('╠══════════════════════════════════════════');
    for (final line in geminiInput.split('\n')) {
      debugPrint('║  $line');
    }
    debugPrint('╚══════════════════════════════════════════');
  }

  Future<void> _handleRegister() async {
    final l10n = AppLocalizations.of(context);
    final registerState = _registerKey.currentState;
    if (registerState == null) return;

    // Validasyon
    if (!registerState.validate(l10n)) return;

    setState(() {
      _isRegistering = true;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    final prefs = _buildPreferences();
    _printGeminiInput(prefs);

    try {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();

      // Firebase Auth — hesap oluştur
      final credential = await authService.registerWithEmail(
        email: registerState.email,
        password: registerState.password,
      );

      if (credential.user != null) {
        final uid = credential.user!.uid;

        // Display name güncelle
        try {
          await authService.updateDisplayName(registerState.name);
        } catch (_) {}

        // Firestore: user doc + preferences
        try {
          final appUser = AppUser(
            uid: uid,
            email: registerState.email,
            displayName: registerState.name,
            createdAt: DateTime.now(),
          );
          await firestoreService.createUser(appUser);
          await firestoreService.saveUserPreferences(uid, prefs);
        } catch (_) {}

        RemoteLoggerService.authEvent('register_success');
        RemoteLoggerService.userAction('onboarding_completed',
            screen: 'onboarding');

        if (!mounted) return;

        // AuthWrapper'a dön — _UserGate yeniden kontrol edip doğru ekranı gösterecek
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isRegistering = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRegistering = false;
        _passwordError = AppLocalizations.of(context).errorGeneral;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(l10n),
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  CuisineStep(
                    selected: _mutfaklar,
                    onChanged: (v) => setState(() => _mutfaklar = v),
                  ),
                  AllergyDietStep(
                    selectedAllergies: _alerjenler,
                    selectedDiets: _diyetler,
                    onAllergiesChanged: (v) => setState(() => _alerjenler = v),
                    onDietsChanged: (v) => setState(() => _diyetler = v),
                  ),
                  MealPlanStep(
                    selected: _secilenOgunler,
                    onChanged: (v) => setState(() => _secilenOgunler = v),
                  ),
                  HouseholdStep(
                    selected: _kisiSayisi,
                    onChanged: (v) => setState(() => _kisiSayisi = v),
                  ),
                  DislikesStep(
                    selected: _sevmedikleri,
                    onChanged: (v) => setState(() => _sevmedikleri = v),
                  ),
                  RegisterStep(
                    key: _registerKey,
                    nameError: _nameError,
                    emailError: _emailError,
                    passwordError: _passwordError,
                  ),
                ],
              ),
            ),
            _buildBottomBar(l10n, bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (_currentPage > 0)
            IconButton(
              onPressed: _previousPage,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.charcoal,
              ),
            )
          else
            IconButton(
              onPressed: () => _cancelOnboarding(l10n),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.charcoal.withValues(alpha: 0.5),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              l10n.onboardingStepOf(
                (_currentPage + 1).toString(),
                _totalPages.toString(),
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = (_currentPage + 1) / _totalPages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBottomBar(AppLocalizations l10n, double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: Material(
              borderRadius: BorderRadius.circular(9999),
              elevation: _canContinue ? 4 : 0,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              child: InkWell(
                onTap: _canContinue ? _nextPage : null,
                borderRadius: BorderRadius.circular(9999),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    gradient: _canContinue
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.primaryDark],
                          )
                        : null,
                    color: _canContinue ? null : AppColors.border,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isRegistering)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        else ...[
                          Text(
                            _buttonLabel(l10n),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: _canContinue
                                      ? Colors.white
                                      : AppColors.charcoal
                                          .withValues(alpha: 0.4),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _buttonIcon(),
                            color: _canContinue
                                ? Colors.white
                                : AppColors.charcoal.withValues(alpha: 0.4),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Sevmedikleri adımında skip butonu
          if (_currentPage == 4) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _nextPage,
              child: Text(
                l10n.onboardingSkip,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
