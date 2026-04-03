import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/remote_logger_service.dart';
import '../../meal_plan/widgets/recipe_suggestion_sheet.dart';
import '../../profile/screens/profile_screen.dart';
import '../../profile/screens/saved_recipes_screen.dart';
import '../../shopping/screens/shopping_screen.dart';
import 'home_screen.dart';

/// Ana kabuk — 4 tab: Ana Sayfa, Tarifler, Alışveriş, Profil
/// Ortada belirgin AI bot FAB butonu.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    HomeScreen(key: HomeScreen.globalKey),
    const SavedRecipesScreen(),
    ShoppingScreen(key: ShoppingScreen.globalKey),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // FAB — ortada, navbar'ın üstünde
      floatingActionButton: SizedBox(
        width: 72,
        height: 72,
        child: FloatingActionButton(
          onPressed: () async {
            RemoteLoggerService.userAction('suggest_opened',
                screen: 'main_shell');
            final viewMode = HomeScreen.globalKey.currentState?.currentViewMode ?? 0;
            final changed = await RecipeSuggestionSheet.show(context, viewMode: viewMode);
            if (changed == true) {
              HomeScreen.globalKey.currentState?.refreshMealPlan();
            }
          },
          elevation: 0,
          highlightElevation: 0,
          backgroundColor: Colors.transparent,
          splashColor: Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/system/aiAgentIcon.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Bottom bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          color: Colors.white,
          elevation: 0,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                // Sol 1: Ana Sayfa
                _NavItem(
                  icon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  label: l10n.navHome,
                  isSelected: _currentIndex == 0,
                  onTap: () => _switchTab(0, 'nav_home'),
                ),
                // Sol 2: Tarifler
                _NavItem(
                  icon: Icons.menu_book_rounded,
                  inactiveIcon: Icons.menu_book_outlined,
                  label: l10n.navRecipes,
                  isSelected: _currentIndex == 1,
                  onTap: () => _switchTab(1, 'nav_recipes'),
                ),
                // Orta boşluk (FAB için)
                const SizedBox(width: 72),
                // Sağ 1: Alışveriş
                _NavItem(
                  icon: Icons.shopping_cart_rounded,
                  inactiveIcon: Icons.shopping_cart_outlined,
                  label: l10n.navShopping,
                  isSelected: _currentIndex == 2,
                  onTap: () => _switchTab(2, 'nav_shopping'),
                ),
                // Sağ 2: Profil
                _NavItem(
                  icon: Icons.person_rounded,
                  inactiveIcon: Icons.person_outline_rounded,
                  label: l10n.navProfile,
                  isSelected: _currentIndex == 3,
                  onTap: () => _switchTab(3, 'nav_profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _switchTab(int index, String logEvent) {
    if (_currentIndex != index) {
      RemoteLoggerService.userAction(logEvent, screen: 'main_shell');
      setState(() => _currentIndex = index);
      // Tab geçişlerinde veriyi yenile
      if (index == 2) {
        ShoppingScreen.globalKey.currentState?.refreshLists();
      }
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? icon : inactiveIcon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.charcoal.withValues(alpha: 0.4),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.charcoal.withValues(alpha: 0.4),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
