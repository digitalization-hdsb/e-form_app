import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../providers/notifications_provider.dart';
import 'app_bottom_nav.dart';
import 'app_drawer.dart';

const _departmentRoutes = {'/hr', '/finance', '/it', '/safety'};

/// Wraps every top-level "destination" screen (Home, forms lists, My
/// Submissions, Profile, and every admin dashboard) in a consistent AppBar +
/// Drawer, mirroring src/components/AppLayout.tsx + AppSidebar.tsx. Screens
/// reached via `context.push` (individual forms, detail/edit views) are NOT
/// wrapped — they keep their own back-button AppBar for a focused, full-
/// screen task flow, which is the more natural mobile pattern.
class AppShell extends StatelessWidget {
  final Widget child;
  final String title;
  final String route;

  const AppShell({super.key, required this.child, required this.title, required this.route});

  static const Map<String, String> titles = {
    '/home': 'HDSB e-Form',
    '/hr': 'Human Resources',
    '/finance': 'Finance',
    '/it': 'IT Department',
    '/safety': 'Safety Department',
    '/submissions': 'My Submissions',
    '/notifications': 'Notifications',
    '/profile': 'My Profile',
    '/admin/hr': 'Form Approvals',
    '/admin/hr/inventory': 'Inventory Tracker',
    '/admin/hr/purchases': 'Purchases',
    '/admin/cars': 'Car Management',
    '/admin/finance': 'Finance Dashboard',
    '/admin/it': 'CCTV Requests',
    '/admin/it/help-desk': 'IT Help Desk',
    '/admin/it/facilities': 'IT Requests',
    '/admin/approvals': 'Approvals',
    '/admin/security': 'Security Dashboard',
    '/admin/safety/discharge': 'Final Discharge',
    '/admin/safety/mixing': 'Mixing & Chemical',
    '/admin/safety/waste': 'Scheduled Waste',
    '/admin/safety/waste-records': 'Safety Records',
    '/admin/users': 'User Directory',
    '/admin/submissions': 'All Submissions',
    '/admin/analytics': 'Analytics',
    '/admin/settings': 'System Settings',
  };

  @override
  Widget build(BuildContext context) {
    final showBackToHome = _departmentRoutes.contains(route);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        leading: showBackToHome
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back to Home',
                onPressed: () => context.go('/home'),
              )
            : null,
        actions: [
          if (route == '/notifications')
            Consumer(
              builder: (context, ref, _) {
                final notifications = ref.watch(notificationsProvider);
                final unread = ref.watch(unreadNotificationCountProvider);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unread > 0)
                      IconButton(
                        tooltip: 'Mark all as read',
                        icon: const Icon(Icons.done_all),
                        onPressed: () => ref.read(notificationStatesProvider.notifier).markAllRead(notifications.map((n) => n.id).toList()),
                      ),
                    if (notifications.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear all',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref.read(notificationStatesProvider.notifier).clearAll(notifications.map((n) => n.id).toList()),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      drawer: const AppDrawer(),
      body: child,
      bottomNavigationBar: AppBottomNav(currentRoute: route),
    );
  }
}
