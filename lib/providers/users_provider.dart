import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_config.dart';
import '../models/app_user.dart';
import 'auth_provider.dart';

class UsersState {
  final List<DirectoryUser> users; // active only — used for approver dropdowns
  final List<DirectoryUser> allUsers; // active + inactive — used by Super Admin directory
  final bool isLoading;

  const UsersState({this.users = const [], this.allUsers = const [], this.isLoading = true});

  UsersState copyWith({List<DirectoryUser>? users, List<DirectoryUser>? allUsers, bool? isLoading}) {
    return UsersState(users: users ?? this.users, allUsers: allUsers ?? this.allUsers, isLoading: isLoading ?? this.isLoading);
  }

  List<DirectoryUser> byRole(String role) =>
      users.where((u) => u.hasRole(role)).toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Mirrors src/contexts/UsersContext.tsx — the approver directory used to
/// populate HOS/HOD/Manco/Head-of-Purchasing/Head-of-Finance dropdowns, plus
/// the Super Admin user-management actions from SuperAdminDashboard.tsx.
class UsersNotifier extends StateNotifier<UsersState> {
  UsersNotifier(this._ref) : super(const UsersState()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await supabase.from('users').select('*');
      final all = (data as List).map((e) => DirectoryUser.fromMap(e as Map<String, dynamic>)).toList();
      final active = all.where((u) => u.status == 'active').toList();
      state = state.copyWith(users: active, allUsers: all, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<({bool success, String? error})> updateUser({
    required String userId,
    required String role,
    required String department,
    required List<String> secondaryRoles,
  }) async {
    final actor = _ref.read(authProvider).user;
    final target = state.allUsers.where((u) => u.id == userId);
    try {
      await supabase.from('users').update({
        'role': role,
        'department': department,
        'secondary_roles': secondaryRoles.where((r) => r != role).toList(),
      }).eq('id', userId);

      await supabase.from('permission_audit_logs').insert({
        'actor_user_id': actor?.id,
        'actor_name': actor?.name,
        'target_user_id': userId,
        'target_user_name': target.isNotEmpty ? target.first.name : null,
        'action': 'permissions_updated',
        'new_values': {'role': role, 'department': department, 'secondary_roles': secondaryRoles},
      });

      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<({bool success, String? error})> setUserStatus({required String userId, required bool active}) async {
    final actor = _ref.read(authProvider).user;
    if (active == false && actor?.id == userId) {
      return (success: false, error: 'You cannot deactivate your own account.');
    }
    final target = state.allUsers.where((u) => u.id == userId);
    try {
      final now = DateTime.now().toIso8601String();
      if (active) {
        await supabase.from('users').update({'status': 'active', 'reactivated_at': now, 'reactivated_by': actor?.id, 'reactivated_by_name': actor?.name}).eq('id', userId);
        await supabase.from('permission_audit_logs').insert({'actor_user_id': actor?.id, 'actor_name': actor?.name, 'target_user_id': userId, 'target_user_name': target.isNotEmpty ? target.first.name : null, 'action': 'user_reactivated'});
      } else {
        await supabase.from('users').update({'status': 'inactive', 'deactivated_at': now, 'deactivated_by': actor?.id, 'deactivated_by_name': actor?.name}).eq('id', userId);
        await supabase.from('permission_audit_logs').insert({'actor_user_id': actor?.id, 'actor_name': actor?.name, 'target_user_id': userId, 'target_user_name': target.isNotEmpty ? target.first.name : null, 'action': 'user_deactivated'});
      }
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }
}

final usersProvider = StateNotifierProvider<UsersNotifier, UsersState>((ref) {
  return UsersNotifier(ref);
});

/// Primary role choices in the Super Admin "Manage" sheet — a subset of the
/// full UserRole union (head_of_purchasing/head_of_finance are secondary-only).
const primaryRoleOptions = [
  'employee', 'security_guard', 'hos', 'hod', 'manco_member',
  'hr_admin', 'finance_admin', 'it_admin', 'safety_admin', 'super_admin',
];

const secondaryRoleOptions = [
  'hos', 'hod', 'manco_member', 'hr_admin', 'finance_admin',
  'safety_admin', 'it_admin', 'security_guard', 'head_of_purchasing', 'head_of_finance',
];

/// Verbatim from ROLE_OPTIONS' `description` field in
/// pages/SuperAdminDashboard.tsx — shown under the Primary Role dropdown.
const roleDescriptions = {
  'employee': 'Standard submission access',
  'security_guard': 'Approve pass exit forms',
  'hos': 'Approve section submissions',
  'hod': 'Approve department submissions',
  'manco_member': 'Approve Gate Pass requests after HOD',
  'hr_admin': 'Manage HR forms & fleet',
  'finance_admin': 'Manage finance & claims',
  'it_admin': 'Manage CCTV access requests',
  'safety_admin': 'View safety dashboards & reports',
  'super_admin': 'Full system access & user management',
};

const roleLabels = {
  'employee': 'Employee',
  'hod': 'Head of Department',
  'manco_member': 'Manco Member',
  'hos': 'Head of Section',
  'hr_admin': 'HR Admin',
  'finance_admin': 'Finance Admin',
  'it_admin': 'IT Admin',
  'head_of_purchasing': 'Head of Purchasing',
  'head_of_finance': 'Head of Finance',
  'super_admin': 'Super Admin',
  'security_guard': 'Security Guard',
  'safety_admin': 'Safety Admin',
};
