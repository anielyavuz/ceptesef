import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/models/app_user.dart';
import '../../../core/models/household.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/household_service.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Aile Planı ekrani — Olustur / Katil / Yonet
class FamilyPlanScreen extends StatefulWidget {
  const FamilyPlanScreen({super.key});

  @override
  State<FamilyPlanScreen> createState() => _FamilyPlanScreenState();
}

class _FamilyPlanScreenState extends State<FamilyPlanScreen> {
  bool _loading = true;
  Household? _household;
  List<AppUser> _members = [];
  late final HouseholdService _householdService;

  @override
  void initState() {
    super.initState();
    RemoteLoggerService.setScreen('family_plan');
    RemoteLoggerService.info('family_plan_screen_opened', screen: 'family_plan');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _householdService = HouseholdService();
    _loadHousehold();
  }

  // ---------------------------------------------------------------------------
  // Veri yukleme
  // ---------------------------------------------------------------------------

  Future<void> _loadHousehold() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loading = true);

    try {
      final firestoreService = context.read<FirestoreService>();
      final appUser = await firestoreService.getUser(user.uid);
      final householdId = appUser?.householdId;

      if (householdId != null) {
        final household = await _householdService.getHousehold(householdId);
        if (household != null) {
          final members =
              await _householdService.getHouseholdMembers(householdId);
          if (mounted) {
            setState(() {
              _household = household;
              _members = members;
              _loading = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _household = null;
          _members = [];
          _loading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('family_plan_load_error', error: e);
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Olustur
  // ---------------------------------------------------------------------------

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.familyPlanCreate),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: l10n.familyPlanName,
            hintText: l10n.familyPlanNameHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(l10n.familyPlanCreate),
          ),
        ],
      ),
    );

    if (result != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _loading = true);
      final household = await _householdService.createHousehold(user.uid, name);
      RemoteLoggerService.userAction('family_plan_created',
          screen: 'family_plan');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.familyPlanCreated)),
        );
        setState(() {
          _household = household;
          _loading = false;
        });
        _loadHousehold(); // uyeleri de yukle
      }
    } catch (e) {
      RemoteLoggerService.error('family_plan_create_error', error: e);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Katil
  // ---------------------------------------------------------------------------

  Future<void> _showJoinDialog() async {
    final l10n = AppLocalizations.of(context);
    final codeController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.familyPlanJoin),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText: l10n.familyPlanCode,
            hintText: l10n.familyPlanCodeHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: Text(l10n.familyPlanJoin),
          ),
        ],
      ),
    );

    if (result != true) return;

    final code = codeController.text.trim().toUpperCase();
    if (code.length != 6) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _loading = true);
      await _householdService.joinHousehold(user.uid, code);
      RemoteLoggerService.userAction('family_plan_joined',
          screen: 'family_plan');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.familyPlanJoined)),
        );
        _loadHousehold();
      }
    } catch (e) {
      RemoteLoggerService.error('family_plan_join_error', error: e);
      if (mounted) {
        setState(() => _loading = false);
        final message = e.toString().contains('süresi dolmuş') ||
                e.toString().contains('Geçersiz')
            ? l10n.familyPlanInvalidCode
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Ayril
  // ---------------------------------------------------------------------------

  Future<void> _leaveHousehold() async {
    final l10n = AppLocalizations.of(context);
    final isOwner =
        _household?.ownerUid == FirebaseAuth.instance.currentUser?.uid;

    final confirmMessage =
        isOwner ? l10n.familyPlanDeleteConfirm : l10n.familyPlanLeaveConfirm;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.familyPlanLeave),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.familyPlanLeave),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      setState(() => _loading = true);
      await _householdService.leaveHousehold(user.uid);
      RemoteLoggerService.userAction('family_plan_left',
          screen: 'family_plan');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.familyPlanLeft)),
        );
        setState(() {
          _household = null;
          _members = [];
          _loading = false;
        });
      }
    } catch (e) {
      RemoteLoggerService.error('family_plan_leave_error', error: e);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Davet kodu islemleri
  // ---------------------------------------------------------------------------

  void _copyCode(String code) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.familyPlanCopied)),
    );
    RemoteLoggerService.userAction('family_plan_code_copied',
        screen: 'family_plan');
  }

  Future<void> _refreshCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _household == null) return;

    try {
      final newCode = await _householdService.refreshInviteCode(
        _household!.id,
        user.uid,
      );
      RemoteLoggerService.userAction('family_plan_code_refreshed',
          screen: 'family_plan');
      if (mounted) {
        setState(() {
          _household = _household!.copyWith(
            inviteCode: newCode,
            inviteCodeExpiresAt: DateTime.now().add(const Duration(hours: 24)),
          );
        });
      }
    } catch (e) {
      RemoteLoggerService.error('family_plan_refresh_code_error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.familyPlan),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _household == null
              ? _buildEmptyState(l10n)
              : _buildActiveState(l10n),
    );
  }

  // ---------------------------------------------------------------------------
  // Durum A — Bos durum
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.family_restroom_rounded,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.familyPlan,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.familyPlanSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.charcoal.withValues(alpha:0.6),
                  ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showCreateDialog,
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.familyPlanCreate),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showJoinDialog,
                icon: const Icon(Icons.group_add_rounded),
                label: Text(l10n.familyPlanJoin),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Durum B — Aktif aile plani
  // ---------------------------------------------------------------------------

  Widget _buildActiveState(AppLocalizations l10n) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = _household!.ownerUid == currentUid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Plan adi
          Text(
            _household!.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 20),

          // Davet kodu karti
          _buildInviteCodeCard(l10n, isOwner),
          const SizedBox(height: 24),

          // Uyeler basligi
          Text(
            l10n.familyPlanMembers,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
          ),
          const SizedBox(height: 12),

          // Uye listesi
          if (_members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  l10n.familyPlanNoMembers,
                  style: TextStyle(
                    color: AppColors.charcoal.withValues(alpha:0.5),
                  ),
                ),
              ),
            )
          else
            ..._members.map((member) => _buildMemberTile(member, l10n)),

          const SizedBox(height: 32),

          // Ayril butonu
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _leaveHousehold,
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.familyPlanLeave),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Davet kodu karti
  // ---------------------------------------------------------------------------

  Widget _buildInviteCodeCard(AppLocalizations l10n, bool isOwner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha:0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha:0.15)),
      ),
      child: Column(
        children: [
          Text(
            l10n.familyPlanInviteCode,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.charcoal.withValues(alpha:0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _household!.inviteCode,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppColors.primary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.familyPlanInviteCodeExpiry,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.charcoal.withValues(alpha:0.4),
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildCodeActionButton(
                icon: Icons.copy_rounded,
                label: l10n.familyPlanShareCode,
                onTap: () => _copyCode(_household!.inviteCode),
              ),
              if (isOwner) ...[
                const SizedBox(width: 12),
                _buildCodeActionButton(
                  icon: Icons.refresh_rounded,
                  label: l10n.familyPlanRefreshCode,
                  onTap: _refreshCode,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Uye satirlari
  // ---------------------------------------------------------------------------

  Widget _buildMemberTile(AppUser member, AppLocalizations l10n) {
    final isOwner = member.uid == _household!.ownerUid;
    final initial = member.displayName.isNotEmpty
        ? member.displayName[0].toUpperCase()
        : member.email[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha:0.15),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName.isNotEmpty
                      ? member.displayName
                      : member.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                if (member.displayName.isNotEmpty)
                  Text(
                    member.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.charcoal.withValues(alpha:0.5),
                    ),
                  ),
              ],
            ),
          ),
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.familyPlanOwner,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
