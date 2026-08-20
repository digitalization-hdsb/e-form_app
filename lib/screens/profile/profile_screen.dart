import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/feedback.dart';
import '../../core/supabase_config.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/users_provider.dart';
import 'change_password_screen.dart';

/// Mirrors pages/ProfilePage.tsx: a read-only summary card with an Edit
/// button that swaps in an editable form (rather than always showing the
/// form with a Save button). Password changes open only on request.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  final _nameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _positionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _icNoController = TextEditingController();
  final _licenseController = TextEditingController();
  String? _department;

  List<String> _departments = [];
  bool _loadingDepartments = true;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _employeeIdController.dispose();
    _positionController.dispose();
    _phoneController.dispose();
    _icNoController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await supabase
          .from('departments')
          .select('name')
          .order('name');
      if (!mounted) return;
      setState(() {
        _departments = (data as List).map((e) => e['name'] as String).toList();
        _loadingDepartments = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDepartments = false);
    }
  }

  void _startEdit(AppUser user) {
    _nameController.text = user.name;
    _employeeIdController.text = user.employeeId;
    _positionController.text = user.position;
    _phoneController.text = user.phone;
    _icNoController.text = user.icNo;
    _licenseController.text = user.drivingLicenseNo;
    _department = user.department;
    setState(() => _isEditing = true);
  }

  void _showSnack(String message, {bool error = false}) {
    if (error) {
      showErrorSnackBar(context, message);
    } else {
      showSuccessSnackBar(context, message);
    }
  }

  Future<void> _pickAndUploadAvatar(AppUser user) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    setState(() => _isUploadingAvatar = true);
    try {
      // Mirrors ProfilePage.tsx: public/{userId}/avatar_{timestamp}_{filename}, upsert.
      final path =
          'public/${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_')}';
      if (file.bytes != null) {
        await supabase.storage
            .from('form-attachments')
            .uploadBinary(
              path,
              file.bytes!,
              fileOptions: const FileOptions(upsert: true),
            );
      } else if (file.path != null) {
        await supabase.storage
            .from('form-attachments')
            .upload(
              path,
              File(file.path!),
              fileOptions: const FileOptions(upsert: true),
            );
      }
      final url = supabase.storage.from('form-attachments').getPublicUrl(path);
      final success = await ref.read(authProvider.notifier).updateProfile({
        'avatar': url,
      });
      if (!mounted) return;
      _showSnack(
        success ? 'Profile photo updated.' : 'Failed to save profile photo.',
        error: !success,
      );
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _save(AppUser user) async {
    setState(() => _isSaving = true);
    final success = await ref.read(authProvider.notifier).updateProfile({
      'name': _nameController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'position': _positionController.text.trim(),
      'department': _department ?? user.department,
      'phone': _phoneController.text.trim(),
      'ic_no': _icNoController.text.trim(),
      'driving_license_no': _licenseController.text.trim(),
    });
    setState(() => _isSaving = false);
    if (!mounted) return;
    if (success) setState(() => _isEditing = false);
    _showSnack(
      success ? 'Profile updated successfully!' : 'Failed to update profile.',
      error: !success,
    );
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/login');
  }

  String? _maskIc(String value) {
    if (value.isEmpty) return null;
    final visible = value.length > 4
        ? value.substring(value.length - 4)
        : value;
    final maskLen = (value.length - 4).clamp(4, 20);
    return '${'•' * maskLen}$visible';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'My Profile',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          'Manage your personal information and security settings.',
          style: TextStyle(color: AppColors.mutedForeground, fontSize: 13),
        ),
        const SizedBox(height: 18),
        _isEditing ? _editCard(user) : _viewCard(user),
        if (!_isEditing) ...[
          const SizedBox(height: 16),
          _appearanceCard(),
          const SizedBox(height: 16),
          _passwordSettingsCard(),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _logout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.destructive.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: AppColors.destructive, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Sign out',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatar(AppUser user, {double radius = 36}) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            const Color(0xFF3B82F6),
            const Color(0xFF22D3EE),
          ],
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.card,
        child: CircleAvatar(
          radius: radius - 2.5,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: user.avatar.isNotEmpty
              ? NetworkImage(user.avatar)
              : null,
          child: user.avatar.isEmpty
              ? Text(
                  user.initials,
                  style: TextStyle(
                    fontSize: radius * 0.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _cardShell({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );

  Widget _viewCard(AppUser user) {
    final roles = {user.role, ...user.secondaryRoles}.toList();

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(user),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < roles.length; i++)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              (i > 0 ? '+ ' : '') +
                                  (roleLabels[roles[i]] ?? roles[i]),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _startEdit(user),
                tooltip: 'Edit Profile',
                icon: Icon(
                  Icons.edit_outlined,
                  color: AppColors.mutedForeground,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _sectionLabel('ACCOUNT & CONTACT'),
          _infoRow(Icons.mail_outline, 'Email Address', user.email),
          const SizedBox(height: 6),
          _sectionLabel('EMPLOYMENT & CONTACT'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoRow(
                  Icons.badge_outlined,
                  'Staff ID',
                  user.employeeId,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoRow(
                  Icons.apartment_outlined,
                  'Department',
                  user.department,
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoRow(Icons.work_outline, 'Position', user.position),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoRow(
                  Icons.phone_outlined,
                  'Phone Number',
                  user.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _sectionLabel('IDENTIFICATION'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoRow(
                  Icons.credit_card_outlined,
                  'IC Number',
                  _maskIc(user.icNo),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _infoRow(
                  Icons.credit_card_outlined,
                  'License Number',
                  user.drivingLicenseNo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.6,
        ),
      ),
    ),
  );

  Widget _infoRow(IconData icon, String label, String? value) {
    final hasValue = value != null && value.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.mutedForeground,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 15,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  hasValue ? value : 'Not set',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                    color: hasValue
                        ? AppColors.foreground
                        : AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceCard() {
    final mode = ref.watch(themeModeProvider);

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose how HDSB e-Form looks on this device.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                label: Text('Dark'),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.settings_suggest_outlined),
                label: Text('System'),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (v) =>
                ref.read(themeModeProvider.notifier).setMode(v.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.foreground,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
              side: BorderSide(color: AppColors.border),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editCard(AppUser user) {
    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isSaving
                    ? null
                    : () => setState(() => _isEditing = false),
                tooltip: 'Cancel',
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.background,
                  shape: const CircleBorder(),
                ),
              ),
            ],
          ),
          Divider(height: 28, color: AppColors.border),
          Center(
            child: GestureDetector(
              onTap: _isUploadingAvatar
                  ? null
                  : () => _pickAndUploadAvatar(user),
              child: Stack(
                children: [
                  _avatar(user, radius: 40),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 28,
                      width: 28,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: _isUploadingAvatar
                          ? SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryDark,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 13,
                              color: AppColors.primaryDark,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Tap the photo to upload a new image',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Email Address',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.mail_outline),
              filled: true,
              fillColor: AppColors.background,
            ),
            child: Text(
              user.email,
              style: TextStyle(color: AppColors.mutedForeground),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Your email is used for login and cannot be changed.',
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Full Name',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(controller: _nameController),
          const SizedBox(height: 14),
          const Text(
            'Staff ID',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(controller: _employeeIdController),
          const SizedBox(height: 14),
          const Text(
            'Position',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _positionController,
            decoration: const InputDecoration(
              hintText: 'e.g. Assistant Manager',
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Department',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            borderRadius: BorderRadius.circular(14),
            dropdownColor: AppColors.card,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.mutedForeground,
            ),
            initialValue: _departments.contains(_department)
                ? _department
                : null,
            isExpanded: true,
            hint: Text(
              _loadingDepartments
                  ? 'Loading departments…'
                  : 'Select Department',
            ),
            items: _departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: _loadingDepartments
                ? null
                : (v) => setState(() => _department = v),
          ),
          const SizedBox(height: 14),
          const Text(
            'Phone Number',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'e.g. +60123456789'),
          ),
          const SizedBox(height: 14),
          const Text(
            'IC Number',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _icNoController,
            decoration: const InputDecoration(hintText: 'e.g. 900101-01-1111'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Driving Licence No.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(controller: _licenseController),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _save(user),
                  icon: _isSaving
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryDark,
                          ),
                        )
                      : const Icon(Icons.save_outlined, size: 18),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _passwordSettingsCard() {
    return _cardShell(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.key_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Update your password when you need to.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
