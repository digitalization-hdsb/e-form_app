import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/admin/all_submissions_screen.dart';
import '../screens/admin/analytics_screen.dart';
import '../screens/admin/car_management_screen.dart';
import '../screens/admin/discharge_dashboard_screen.dart';
import '../screens/admin/finance_admin_dashboard_screen.dart';
import '../screens/admin/hr_admin_dashboard_screen.dart';
import '../screens/admin/inventory_dashboard_screen.dart';
import '../screens/admin/it_admin_dashboard_screen.dart';
import '../screens/admin/mixing_dashboard_screen.dart';
import '../screens/admin/purchases_dashboard_screen.dart';
import '../screens/admin/security_dashboard_screen.dart';
import '../screens/admin/system_settings_screen.dart';
import '../screens/admin/user_directory_screen.dart';
import '../screens/admin/waste_dashboard_screen.dart';
import '../screens/admin/waste_records_screen.dart';
import '../screens/approvals/approver_dashboard_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/finance/finance_forms_screen.dart';
import '../screens/finance/petty_cash_form_screen.dart';
import '../screens/finance/receipt_upload_form_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/hr/car_booking_form_screen.dart';
import '../screens/hr/gate_pass_form_screen.dart';
import '../screens/hr/hr_forms_screen.dart';
import '../screens/hr/ppe_request_form_screen.dart';
import '../screens/it/cctv_access_request_form_screen.dart';
import '../screens/it/it_facilities_requisition_form_screen.dart';
import '../screens/it/it_forms_screen.dart';
import '../screens/it/it_help_desk_form_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/safety/daily_operation_monitoring_form_screen.dart';
import '../screens/safety/safety_forms_screen.dart';
import '../screens/safety/waste_inventory_form_screen.dart';
import '../screens/submissions/my_submissions_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    refreshListenable: _AuthRefreshStream(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      if (auth.isInitializing) return null;

      final isAuthRoute = ['/login', '/register', '/verify-otp', '/forgot-password'].contains(state.matchedLocation);
      if (!auth.isAuthenticated && !isAuthRoute) return '/login';
      if (auth.isAuthenticated && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/verify-otp',
        builder: (context, state) => VerifyOtpScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordScreen(initialEmail: state.extra as String?),
      ),

      // Destinations reachable from the drawer — each wrapped in the shared
      // AppBar + Drawer chrome (see widgets/app_shell.dart).
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          final title = AppShell.titles[state.matchedLocation] ?? 'HDSB e-Form';
          return AppShell(title: title, route: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(path: '/home', pageBuilder: (context, state) => NoTransitionPage(child: const HomeScreen())),
          GoRoute(path: '/hr', pageBuilder: (context, state) => NoTransitionPage(child: const HrFormsScreen())),
          GoRoute(path: '/finance', pageBuilder: (context, state) => NoTransitionPage(child: const FinanceFormsScreen())),
          GoRoute(path: '/it', pageBuilder: (context, state) => NoTransitionPage(child: const ItFormsScreen())),
          GoRoute(path: '/safety', pageBuilder: (context, state) => NoTransitionPage(child: const SafetyFormsScreen())),
          GoRoute(path: '/submissions', pageBuilder: (context, state) => NoTransitionPage(child: const MySubmissionsScreen())),
          GoRoute(path: '/notifications', pageBuilder: (context, state) => NoTransitionPage(child: const NotificationsScreen())),
          GoRoute(path: '/profile', pageBuilder: (context, state) => NoTransitionPage(child: const ProfileScreen())),
          GoRoute(path: '/admin/hr', pageBuilder: (context, state) => NoTransitionPage(child: const HrAdminDashboardScreen())),
          GoRoute(path: '/admin/finance', pageBuilder: (context, state) => NoTransitionPage(child: const FinanceAdminDashboardScreen())),
          GoRoute(path: '/admin/approvals', pageBuilder: (context, state) => NoTransitionPage(child: const ApproverDashboardScreen())),
          GoRoute(path: '/admin/cars', pageBuilder: (context, state) => NoTransitionPage(child: const CarManagementScreen())),
          GoRoute(path: '/admin/hr/inventory', pageBuilder: (context, state) => NoTransitionPage(child: const InventoryDashboardScreen())),
          GoRoute(path: '/admin/hr/purchases', pageBuilder: (context, state) => NoTransitionPage(child: const PurchasesDashboardScreen())),
          GoRoute(path: '/admin/it', pageBuilder: (context, state) => NoTransitionPage(child: const ItAdminDashboardScreen(mode: 'cctv'))),
          GoRoute(path: '/admin/it/help-desk', pageBuilder: (context, state) => NoTransitionPage(child: const ItAdminDashboardScreen(mode: 'helpdesk'))),
          GoRoute(path: '/admin/it/facilities', pageBuilder: (context, state) => NoTransitionPage(child: const ItAdminDashboardScreen(mode: 'facilities'))),
          GoRoute(path: '/admin/safety/discharge', pageBuilder: (context, state) => NoTransitionPage(child: const DischargeDashboardScreen())),
          GoRoute(path: '/admin/safety/mixing', pageBuilder: (context, state) => NoTransitionPage(child: const MixingDashboardScreen())),
          GoRoute(path: '/admin/safety/waste', pageBuilder: (context, state) => NoTransitionPage(child: const WasteDashboardScreen())),
          GoRoute(path: '/admin/safety/waste-records', pageBuilder: (context, state) => NoTransitionPage(child: const WasteRecordsScreen())),
          GoRoute(path: '/admin/security', pageBuilder: (context, state) => NoTransitionPage(child: const SecurityDashboardScreen())),
          GoRoute(path: '/admin/users', pageBuilder: (context, state) => NoTransitionPage(child: const UserDirectoryScreen())),
          GoRoute(path: '/admin/submissions', pageBuilder: (context, state) => NoTransitionPage(child: const AllSubmissionsScreen())),
          GoRoute(path: '/admin/analytics', pageBuilder: (context, state) => NoTransitionPage(child: const AnalyticsScreen())),
          GoRoute(path: '/admin/settings', pageBuilder: (context, state) => NoTransitionPage(child: const SystemSettingsScreen())),
        ],
      ),

      // Individual forms — pushed full-screen on top of the shell with their
      // own back-button AppBar, matching a focused mobile task flow.
      GoRoute(path: '/hr/car-rental', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const CarBookingFormScreen()),
      GoRoute(path: '/hr/leave', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const GatePassFormScreen()),
      GoRoute(path: '/hr/ppe-request', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const PpeRequestFormScreen()),
      GoRoute(path: '/finance/claim', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const PettyCashFormScreen()),
      GoRoute(path: '/finance/receipt-upload', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ReceiptUploadFormScreen()),
      GoRoute(path: '/it/cctv-access-request', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const CctvAccessRequestFormScreen()),
      GoRoute(path: '/it/help-desk', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ItHelpDeskFormScreen()),
      GoRoute(path: '/it/request-admin', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ItFacilitiesRequisitionFormScreen(variant: 'admin')),
      GoRoute(path: '/it/request-application', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const ItFacilitiesRequisitionFormScreen(variant: 'application')),
      GoRoute(path: '/safety/mixing', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const DailyOperationMonitoringFormScreen(variant: 'mixing')),
      GoRoute(path: '/safety/discharge', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const DailyOperationMonitoringFormScreen(variant: 'discharge')),
      GoRoute(path: '/safety/waste-inventory', parentNavigatorKey: _rootNavigatorKey, builder: (context, state) => const WasteInventoryFormScreen()),
    ],
  );
});

/// Bridges Riverpod's AuthState changes into a Listenable so GoRouter
/// re-evaluates `redirect` whenever sign-in state changes.
class _AuthRefreshStream extends ChangeNotifier {
  _AuthRefreshStream(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated || previous?.isInitializing != next.isInitializing) {
        notifyListeners();
      }
    });
  }
}
