import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../widgets/preferences_section.dart';
import '../widgets/my_ratings_section.dart';
import '../../home/screens/home_screen.dart';
import '../../inbox/screens/inbox_screen.dart';

/// Profil ekranı — Hesap bilgileri, tercihler, çıkış ve hesap silme.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDeleting = false;
  UserPreferences? _preferences;
  bool _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('profile');
    RemoteLoggerService.info('profile_screen_opened', screen: 'profile');
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs =
          await context.read<FirestoreService>().getUserPreferences(user.uid);
      if (mounted) {
        setState(() {
          _preferences = prefs;
          _loadingPrefs = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('load_preferences_failed',
          error: e, screen: 'profile');
      if (mounted) setState(() => _loadingPrefs = false);
    }
  }

  Future<void> _savePreferences(UserPreferences updated) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final l10n = AppLocalizations.of(context);

    try {
      await context.read<FirestoreService>().saveUserPreferences(user.uid, updated);
      RemoteLoggerService.userAction('preferences_updated', screen: 'profile');
      if (mounted) {
        setState(() => _preferences = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePreferencesSaved)),
        );
      }
    } catch (e) {
      RemoteLoggerService.error('save_preferences_failed',
          error: e, screen: 'profile');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePreferencesError)),
        );
      }
    }
  }

  Future<void> _handleLogout() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileLogoutTitle),
        content: Text(l10n.profileLogoutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.profileLogoutCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            child: Text(l10n.profileLogoutConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    RemoteLoggerService.userAction('logout_confirmed', screen: 'profile');
    await context.read<AuthService>().signOut();
  }

  Future<void> _handleClearAllPlans() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm Planları Temizle'),
        content: const Text(
            'Haftalık yemek planlarınızın tamamı silinecek. Devam etmek istiyor musunuz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await context.read<FirestoreService>().deleteAllMealPlans(uid);
      RemoteLoggerService.userAction('all_plans_cleared', screen: 'profile');

      // Ana sayfayı yenile
      HomeScreen.globalKey.currentState?.refreshMealPlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Tüm planlar temizlendi'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      RemoteLoggerService.error('clear_all_plans_failed',
          error: e, screen: 'profile');
    }
  }

  Future<void> _handleDeleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.profileDeleteAccountTitle),
        content: Text(l10n.profileDeleteAccountMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.profileDeleteAccountCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.profileDeleteAccountConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      RemoteLoggerService.userAction('delete_account_confirmed',
          screen: 'profile');

      final firestoreService = context.read<FirestoreService>();
      final authService = context.read<AuthService>();

      // Önce Firestore verilerini sil
      await firestoreService.deleteUserData(user.uid);

      // Sonra Firebase Auth hesabını sil
      await authService.deleteAccount();

      // Auth state değişince AuthWrapper otomatik login'e yönlendirecek
    } catch (e) {
      RemoteLoggerService.error('delete_account_failed',
          error: e, screen: 'profile');
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileDeleteAccountError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: _isDeleting
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // Başlık
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Text(
                        l10n.profileTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.charcoal,
                            ),
                      ),
                    ),
                  ),

                  // Kullanıcı avatar + bilgi
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                _userInitials(user),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.displayName ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.charcoal,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.charcoal
                                              .withValues(alpha: 0.5),
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  FutureBuilder<String?>(
                                    future: FirebaseMessaging.instance.getToken(),
                                    builder: (ctx, snap) {
                                      final token = snap.data;
                                      if (token == null) return const SizedBox.shrink();
                                      return GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: token));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('FCM Token kopyalandı'),
                                              behavior: SnackBarBehavior.floating,
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          token,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.charcoal
                                                    .withValues(alpha: 0.3),
                                                fontSize: 9,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bildirimler
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildTile(
                          icon: Icons.notifications_outlined,
                          label: l10n.inbox,
                          iconColor: AppColors.secondary,
                          onTap: () {
                            RemoteLoggerService.userAction(
                                'inbox_opened',
                                screen: 'profile');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const InboxScreen()),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Tercihlerim bölümü
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Text(
                        l10n.profilePreferencesSection,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _loadingPrefs
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : PreferencesSection(
                              preferences: _preferences,
                              onSave: _savePreferences,
                            ),
                    ),
                  ),

                  // Değerlendirmelerim bölümü
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Text(
                        l10n.profileMyRatings,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: MyRatingsSection(),
                    ),
                  ),

                  // Hesap bölümü
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                      child: Text(
                        l10n.profileAccountSection,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.charcoal
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ),

                  // Tüm planları temizle (test)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _buildTile(
                          icon: Icons.delete_sweep_rounded,
                          label: 'Tüm Planları Temizle',
                          iconColor: const Color(0xFFE65100),
                          textColor: const Color(0xFFE65100),
                          onTap: _handleClearAllPlans,
                        ),
                      ),
                    ),
                  ),

                  // Çıkış yap
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTile(
                              icon: Icons.logout_rounded,
                              label: l10n.profileLogout,
                              iconColor: AppColors.charcoal,
                              onTap: _handleLogout,
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color: AppColors.border,
                            ),
                            _buildTile(
                              icon: Icons.delete_forever_rounded,
                              label: l10n.profileDeleteAccount,
                              iconColor: Colors.red,
                              textColor: Colors.red,
                              onTap: _handleDeleteAccount,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Uygulama versiyonu
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final info = snapshot.data!;
                          return Center(
                            child: Text(
                              '${l10n.profileAppVersion} ${info.version} (${info.buildNumber})',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.charcoal),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: textColor ?? AppColors.charcoal,
              fontWeight: FontWeight.w500,
            ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.charcoal.withValues(alpha: 0.3),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  String _userInitials(User? user) {
    final name = user?.displayName ?? user?.email ?? '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
