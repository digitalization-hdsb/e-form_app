import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/role_nav.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';

/// A persistent Home / Dashboard / Notifications / Profile dock — the
/// pattern most mobile apps use for their most-reached destinations instead
/// of requiring the drawer for every trip back to Home. Shown on every
/// [AppShell]-wrapped screen, Notifications included, so all four tabs
/// behave identically (same instant transition, dock stays visible). The
/// second tab reads "Dashboard" and points at the user's primary admin page
/// for HOS/HOD/admin roles, or "Submissions" for plain employees.
class AppBottomNav extends ConsumerWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(unreadNotificationCountProvider);
    if (user == null) return const SizedBox.shrink();

    final adminNav = adminNavFor(user);
    final hasAdminHome = adminNav.isNotEmpty;
    final secondaryRoute = hasAdminHome ? adminNav.first.route : '/submissions';
    final adminRoutes = adminNav.map((i) => i.route).toSet();

    final int selectedIndex;
    if (currentRoute == secondaryRoute || (hasAdminHome && adminRoutes.contains(currentRoute))) {
      selectedIndex = 1;
    } else if (currentRoute == '/notifications') {
      selectedIndex = 2;
    } else if (currentRoute == '/profile') {
      selectedIndex = 3;
    } else if (currentRoute == '/home') {
      selectedIndex = 0;
    } else {
      selectedIndex = -1;
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.isDark
              ? const []
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            _NavButton(
              selected: selectedIndex == 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              onTap: () => context.go('/home'),
            ),
            _NavButton(
              selected: selectedIndex == 1,
              icon: hasAdminHome ? Icons.dashboard_outlined : Icons.description_outlined,
              selectedIcon: hasAdminHome ? Icons.dashboard_rounded : Icons.description_rounded,
              label: hasAdminHome ? 'Dashboard' : 'Submissions',
              onTap: () => context.go(secondaryRoute),
            ),
            _NavButton(
              selected: selectedIndex == 2,
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications_rounded,
              label: 'Alerts',
              badgeCount: unread,
              onTap: () => context.go('/notifications'),
            ),
            _NavButton(
              selected: selectedIndex == 3,
              icon: Icons.person_outline,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavButton({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.mutedForeground;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary.withValues(alpha: 0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(selected ? selectedIcon : icon, size: 25, color: color),
                      if (badgeCount > 0)
                        Positioned(
                          right: -8,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            constraints: const BoxConstraints(minWidth: 17),
                            decoration: BoxDecoration(
                              color: AppColors.destructive,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppColors.card, width: 1.5),
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold, height: 1.3),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontWeight: selected ? FontWeight.bold : FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
