import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/role_nav.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Mirrors src/components/AppSidebar.tsx: a persistent "Menu" section for
/// every user, plus a role-specific "Admin" section. Grows as more
/// dashboards are ported — see router.dart for what currently exists.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  static const _employeeNav = [
    NavItem('Home', '/home', Icons.home_outlined),
    NavItem('My Submissions', '/submissions', Icons.description_outlined),
    NavItem('My Profile', '/profile', Icons.person_outline),
  ];

  static const _formsNav = [
    NavItem('Human Resources', '/hr', Icons.groups_outlined),
    NavItem('Finance', '/finance', Icons.attach_money),
    NavItem('IT Department', '/it', Icons.dns_outlined),
  ];

  static const _safetyFormsNav = NavItem('Safety Department', '/safety', Icons.shield_outlined);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const Drawer();

    final location = GoRouterState.of(context).matchedLocation;
    final adminNav = adminNavFor(user);
    final isAdmin = adminNav.isNotEmpty;
    final hasSafetyAccess = user.role == 'safety_admin' || user.role == 'super_admin' || user.secondaryRoles.contains('safety_admin');

    return Drawer(
      backgroundColor: AppColors.primaryDark,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', height: 34),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('HDSB e-Form', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _sectionLabel('Menu'),
                  for (final item in _employeeNav) _tile(context, item, location),
                  // HOS/HOD/admins already reach the same form list from
                  // Home, so skip the redundant section here — keep it only
                  // for plain employees with no admin destinations.
                  if (!isAdmin) ...[
                    const SizedBox(height: 8),
                    _sectionLabel('Submit a Form'),
                    for (final item in _formsNav) _tile(context, item, location),
                    if (hasSafetyAccess) _tile(context, _safetyFormsNav, location),
                  ],
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    _sectionLabel('Admin'),
                    for (final item in adminNav) _tile(context, item, location),
                  ],
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.gold, Colors.white.withValues(alpha: 0.4)]),
                          ),
                          child: CircleAvatar(
                            radius: 17,
                            backgroundColor: AppColors.primaryDark,
                            backgroundImage: user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                            child: user.avatar.isNotEmpty ? null : Text(user.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5), overflow: TextOverflow.ellipsis),
                              Text(user.role.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 0.3), overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      splashColor: AppColors.destructive.withValues(alpha: 0.2),
                      highlightColor: AppColors.destructive.withValues(alpha: 0.12),
                      onTap: () async {
                        Navigator.of(context).pop();
                        await ref.read(authProvider.notifier).logout();
                        if (context.mounted) context.go('/login');
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout, color: Colors.white70, size: 18),
                            const SizedBox(width: 8),
                            const Text('Sign out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Text(text, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.6)),
      );

  Widget _tile(BuildContext context, NavItem item, String location) {
    final selected = location == item.route;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          leading: Icon(item.icon, color: selected ? AppColors.gold : Colors.white70, size: 20),
          title: Text(item.title, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 13.5)),
          onTap: () {
            Navigator.of(context).pop();
            if (!selected) context.go(item.route);
          },
        ),
      ),
    );
  }
}
