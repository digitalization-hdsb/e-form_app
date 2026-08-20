import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/app_loading_indicator.dart';
import '../../widgets/skeleton.dart';

/// Mirrors pages/SuperAdminDashboard.tsx's User Directory (`admin/users`).
class UserDirectoryScreen extends ConsumerStatefulWidget {
  const UserDirectoryScreen({super.key});

  @override
  ConsumerState<UserDirectoryScreen> createState() => _UserDirectoryScreenState();
}

class _UserDirectoryScreenState extends ConsumerState<UserDirectoryScreen> {
  bool _showActive = true;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(usersProvider);
    final query = _searchController.text.trim().toLowerCase();
    final pool = state.allUsers.where((u) => (u.status == 'active') == _showActive);
    final filtered = pool.where((u) {
      if (query.isEmpty) return true;
      return u.name.toLowerCase().contains(query) || u.email.toLowerCase().contains(query) || u.staffId.toLowerCase().contains(query) || u.role.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) {
        final aEmpty = a.name.trim().isEmpty;
        final bEmpty = b.name.trim().isEmpty;
        if (aEmpty != bEmpty) return aEmpty ? 1 : -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final activeCount = state.allUsers.where((u) => u.status == 'active').length;
    final inactiveCount = state.allUsers.where((u) => u.status != 'active').length;

    return RefreshIndicator(
      onRefresh: () => ref.read(usersProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text('Active ($activeCount)')),
              ButtonSegment(value: false, label: Text('Inactive ($inactiveCount)')),
            ],
            selected: {_showActive},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _showActive = v.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.foreground,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
              side: BorderSide(color: AppColors.border),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search name, email, staff ID, role...', isDense: true),
          ),
          const SizedBox(height: 14),
          if (state.isLoading && state.allUsers.isEmpty)
            Column(children: [for (var i = 0; i < 6; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 60, borderRadius: BorderRadius.circular(14)))])
          else if (filtered.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No users found.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final user in filtered) _UserTile(user: user),
        ],
      ),
    );
  }

}

class _UserTile extends StatelessWidget {
  final DirectoryUser user;

  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final isActive = user.status == 'active';
    final hasName = user.name.trim().isNotEmpty;
    final displayName = hasName ? user.name : (user.email.isNotEmpty ? user.email : 'Unnamed profile');
    final initials = user.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ManageUserSheet(user: user),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
              child: user.avatar.isNotEmpty
                  ? null
                  : hasName
                      ? Text(initials, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))
                      : Icon(Icons.person_outline, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, fontStyle: hasName ? FontStyle.normal : FontStyle.italic, color: hasName ? AppColors.foreground : AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 2),
                  Text('${user.staffId} · ${user.department}', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _roleBadge(roleLabels[user.role] ?? user.role, true),
                      for (final r in user.secondaryRoles) _roleBadge(roleLabels[r] ?? r, false),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(isActive ? 'Manage' : 'View', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                Icon(Icons.chevron_right, color: AppColors.mutedForeground, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleBadge(String label, bool primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: primary ? AppColors.primary.withValues(alpha: 0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(999),
        border: primary ? null : Border.all(color: AppColors.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: primary ? AppColors.primary : AppColors.mutedForeground)),
    );
  }
}

class _ManageUserSheet extends ConsumerStatefulWidget {
  final DirectoryUser user;

  const _ManageUserSheet({required this.user});

  @override
  ConsumerState<_ManageUserSheet> createState() => _ManageUserSheetState();
}

class _ManageUserSheetState extends ConsumerState<_ManageUserSheet> {
  late String _role;
  late String _department;
  late Set<String> _secondaryRoles;
  List<String> _departments = [];
  bool _isSaving = false;
  bool _isTogglingStatus = false;

  bool get _isActive => widget.user.status == 'active';
  bool get _isSelf => ref.read(authProvider).user?.id == widget.user.id;
  String get _displayName => widget.user.name.trim().isNotEmpty ? widget.user.name : (widget.user.email.isNotEmpty ? widget.user.email : 'this account');

  bool get _hasChanges =>
      _role != widget.user.role || _department != widget.user.department || !setEquals(_secondaryRoles, widget.user.secondaryRoles.toSet());

  @override
  void initState() {
    super.initState();
    _role = widget.user.role;
    _department = widget.user.department;
    _secondaryRoles = widget.user.secondaryRoles.toSet();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await supabase.from('departments').select('name').order('name');
      setState(() => _departments = (data as List).map((e) => e['name'] as String).toList());
    } catch (_) {}
  }

  Future<bool> _confirm(String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (_role == 'super_admin' && widget.user.role != 'super_admin') {
      final confirmed = await _confirm('Grant Super Admin access to $_displayName? This provides full system access.');
      if (!confirmed) return;
    }
    setState(() => _isSaving = true);
    final result = await ref.read(usersProvider.notifier).updateUser(
      userId: widget.user.id,
      role: _role,
      department: _department,
      secondaryRoles: _secondaryRoles.toList(),
    );
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, 'User updated.');
    } else {
      showErrorSnackBar(context, result.error ?? 'Failed to update user.');
    }
  }

  Future<void> _toggleStatus() async {
    final confirmed = await _confirm(_isActive ? 'Deactivate $_displayName\'s account?' : 'Reactivate $_displayName\'s account?');
    if (!confirmed) return;
    setState(() => _isTogglingStatus = true);
    final result = await ref.read(usersProvider.notifier).setUserStatus(userId: widget.user.id, active: !_isActive);
    setState(() => _isTogglingStatus = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, _isActive ? 'User deactivated.' : 'User reactivated.');
    } else {
      showErrorSnackBar(context, result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final viewOnly = !_isActive;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            const Text('Manage User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              viewOnly ? 'Review this archived account and its retained access history.' : 'Review account details and update access permissions.',
              style: TextStyle(color: AppColors.mutedForeground, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // USER INFORMATION — read-only.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                backgroundImage: u.avatar.isNotEmpty ? NetworkImage(u.avatar) : null,
                                child: u.avatar.isNotEmpty
                                    ? null
                                    : u.name.trim().isNotEmpty
                                        ? Text(
                                            u.name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase(),
                                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                          )
                                        : Icon(Icons.person_outline, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName,
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontStyle: u.name.trim().isEmpty ? FontStyle.italic : FontStyle.normal),
                                    ),
                                    if (u.name.trim().isNotEmpty) Text(u.email, style: TextStyle(color: AppColors.mutedForeground, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_isActive ? AppColors.success : AppColors.mutedForeground).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _isActive ? 'ACTIVE' : 'INACTIVE',
                                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: _isActive ? AppColors.success : AppColors.mutedForeground),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              _infoField('Staff ID', u.staffId),
                              _infoField('Position', u.position),
                              _infoField('Department', u.department),
                              _infoField('Phone', u.phone),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('DEPARTMENT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: AppColors.card,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                      initialValue: _departments.contains(_department) ? _department : null,
                      isExpanded: true,
                      hint: Text(_department.isNotEmpty ? _department : 'Select department'),
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: viewOnly ? null : (v) => setState(() => _department = v ?? _department),
                    ),
                    const SizedBox(height: 16),
                    Text('PRIMARY ROLE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: AppColors.card,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                      initialValue: _role,
                      isExpanded: true,
                      items: primaryRoleOptions.map((r) => DropdownMenuItem(value: r, child: Text(roleLabels[r] ?? r))).toList(),
                      onChanged: viewOnly ? null : (v) => setState(() => _role = v ?? _role),
                    ),
                    if (roleDescriptions[_role] != null) ...[
                      const SizedBox(height: 6),
                      Text(roleDescriptions[_role]!, style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                    ],
                    const SizedBox(height: 16),
                    Text('ADDITIONAL ACCESS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                    const SizedBox(height: 4),
                    Text('A user may have multiple additional roles.', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                    const SizedBox(height: 8),
                    if (!viewOnly)
                      DropdownButtonFormField<String>(
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: AppColors.card,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                        // Re-keying on the selection set makes the field forget its
                        // last pick once that role is added, instead of appearing
                        // to still show it as selected.
                        key: ValueKey(_secondaryRoles.length),
                        initialValue: null,
                        isExpanded: true,
                        hint: const Text('Add a secondary role...', style: TextStyle(fontSize: 12.5)),
                        items: secondaryRoleOptions.where((r) => r != _role && !_secondaryRoles.contains(r)).map((r) => DropdownMenuItem(value: r, child: Text(roleLabels[r] ?? r))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _secondaryRoles.add(v));
                        },
                      ),
                    const SizedBox(height: 10),
                    if (_secondaryRoles.isEmpty)
                      Text('No additional roles assigned.', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground, fontStyle: FontStyle.italic))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _secondaryRoles.map((r) {
                          return viewOnly
                              ? Chip(label: Text(roleLabels[r] ?? r, style: const TextStyle(fontSize: 11)), backgroundColor: AppColors.background, side: BorderSide(color: AppColors.border))
                              : InputChip(
                                  label: Text(roleLabels[r] ?? r, style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => setState(() => _secondaryRoles.remove(r)),
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  deleteIconColor: AppColors.primary,
                                  side: BorderSide.none,
                                );
                        }).toList(),
                      ),
                    if (viewOnly && (u.deactivatedAt != null || u.deactivatedByName != null)) ...[
                      const SizedBox(height: 18),
                      Text('ACCOUNT HISTORY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (u.deactivatedAt != null) _infoField('Deactivated', _formatDate(u.deactivatedAt!)),
                            if (u.deactivatedByName != null) _infoField('Deactivated By', u.deactivatedByName!),
                            const SizedBox(height: 4),
                            Text(
                              'The profile, submissions, approvals, and audit history remain stored under the same user ID.',
                              style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground, fontStyle: FontStyle.italic),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 11.5, color: AppColors.foreground),
                          children: [
                            const TextSpan(text: 'Primary: ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: roleLabels[_role] ?? _role),
                            if (_secondaryRoles.isNotEmpty) ...[
                              const TextSpan(text: ' · Additional: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: _secondaryRoles.map((r) => roleLabels[r] ?? r).join(', ')),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isActive)
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (_hasChanges && !_isSaving) ? _save : null,
                      child: _isSaving ? AppLoadingIndicator(size: 20, color: AppColors.primaryDark) : const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: _isSelf ? 'You cannot deactivate your own account' : 'Deactivate this account',
                    child: IconButton.filled(
                      onPressed: (_isSelf || _isTogglingStatus) ? null : _toggleStatus,
                      icon: _isTogglingStatus ? AppLoadingIndicator(size: 18, color: AppColors.destructive) : const Icon(Icons.person_off_outlined),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.destructive.withValues(alpha: 0.1),
                        foregroundColor: AppColors.destructive,
                        disabledBackgroundColor: AppColors.destructive.withValues(alpha: 0.04),
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isTogglingStatus ? null : _toggleStatus,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                      child: _isTogglingStatus ? AppLoadingIndicator(size: 20, color: Colors.white) : const Text('Reactivate Account'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoField(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value.isEmpty ? '—' : value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    if (date == null) return iso;
    return DateFormat('d MMM yyyy, h:mm a').format(date.toLocal());
  }
}
