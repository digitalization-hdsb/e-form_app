import 'package:flutter/material.dart';

import '../models/app_user.dart';

class NavItem {
  final String title;
  final String route;
  final IconData icon;
  const NavItem(this.title, this.route, this.icon);
}

/// Per-role admin destinations — shared by [AppDrawer]'s "Admin" section and
/// the bottom nav's Dashboard tab (which always points at the first entry
/// for the user's role, treated as that role's primary landing page).
const Map<String, List<NavItem>> adminNavByRole = {
  'hr_admin': [
    NavItem('Form Approvals', '/admin/hr', Icons.dashboard_outlined),
    NavItem('Inventory Tracker', '/admin/hr/inventory', Icons.inventory_2_outlined),
    NavItem('Car Management', '/admin/cars', Icons.directions_car_outlined),
    NavItem('Purchases', '/admin/hr/purchases', Icons.shopping_cart_outlined),
  ],
  'finance_admin': [
    NavItem('Dashboard', '/admin/finance', Icons.dashboard_outlined),
  ],
  'it_admin': [
    NavItem('CCTV Requests', '/admin/it', Icons.videocam_outlined),
    NavItem('IT Help Desk', '/admin/it/help-desk', Icons.support_agent_outlined),
    NavItem('IT Requests', '/admin/it/facilities', Icons.dns_outlined),
  ],
  'safety_admin': [
    NavItem('Final Discharge', '/admin/safety/discharge', Icons.water_drop_outlined),
    NavItem('Mixing & Chemical', '/admin/safety/mixing', Icons.science_outlined),
    NavItem('Scheduled Waste', '/admin/safety/waste', Icons.recycling_outlined),
    NavItem('Records', '/admin/safety/waste-records', Icons.storage_outlined),
  ],
  'hod': [NavItem('Approvals', '/admin/approvals', Icons.dashboard_outlined)],
  'hos': [NavItem('Approvals', '/admin/approvals', Icons.dashboard_outlined)],
  'manco_member': [NavItem('Approvals', '/admin/approvals', Icons.dashboard_outlined)],
  'head_of_purchasing': [NavItem('Approvals', '/admin/approvals', Icons.dashboard_outlined)],
  'head_of_finance': [NavItem('Approvals', '/admin/approvals', Icons.dashboard_outlined)],
  'security_guard': [NavItem('Security Dashboard', '/admin/security', Icons.local_police_outlined)],
  'super_admin': [
    NavItem('User Directory', '/admin/users', Icons.people_outline),
    NavItem('All Submissions', '/admin/submissions', Icons.folder_open_outlined),
    NavItem('Analytics', '/admin/analytics', Icons.bar_chart_outlined),
    NavItem('System Settings', '/admin/settings', Icons.settings_outlined),
  ],
};

List<NavItem> adminNavFor(AppUser user) {
  final roles = {user.role, ...user.secondaryRoles};
  final seen = <String>{};
  final items = <NavItem>[];
  for (final role in roles) {
    for (final item in adminNavByRole[role] ?? const []) {
      if (seen.add(item.route)) items.add(item);
    }
  }
  return items;
}
