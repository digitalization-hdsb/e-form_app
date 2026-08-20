import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/approver_dropdown.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/modern_time_picker.dart';

class GatePassFormScreen extends ConsumerStatefulWidget {
  const GatePassFormScreen({super.key});

  @override
  ConsumerState<GatePassFormScreen> createState() => _GatePassFormScreenState();
}

class _GatePassFormScreenState extends ConsumerState<GatePassFormScreen> {
  String _purposeType = 'company';
  final _companyLocationController = TextEditingController();
  final _companyPurposeController = TextEditingController();
  final _personalLocationController = TextEditingController();
  final _personalPurposeController = TextEditingController();
  String? _hos;
  String? _hod;
  String? _mancoMemberId;
  TimeOfDay? _timeOut;
  TimeOfDay? _timeIn;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _companyLocationController.dispose();
    _companyPurposeController.dispose();
    _personalLocationController.dispose();
    _personalPurposeController.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool isOut}) async {
    final result = await showModernTimePicker(context: context, initialTime: TimeOfDay.now(), title: isOut ? 'Time Out' : 'Time In');
    if (result == null) return;
    setState(() {
      if (isOut) {
        _timeOut = result;
      } else {
        _timeIn = result;
      }
    });
  }

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_hos == null || _hod == null || _mancoMemberId == null) {
      _showError('Please select the Head of Section, Head of Department, and Manco Member.');
      return;
    }
    if (_timeOut == null || _timeIn == null) {
      _showError('Please provide both estimated Time Out and Time In.');
      return;
    }

    final mancoMember = ref.read(usersProvider).users.firstWhere((u) => u.id == _mancoMemberId);

    final initialStatus = _hos == 'N/A' ? (_hod == 'N/A' ? 'approved_hod' : 'approved_hos') : 'pending';

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'leave',
      status: initialStatus,
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'employeeInfo': {
          'name': user.name,
          'staffNo': user.employeeId,
          'department': user.department,
          'position': user.position,
          'avatar': user.avatar,
          'phone': user.phone,
        },
        'purposeType': _purposeType,
        'companyDetails': {'location': _companyLocationController.text.trim(), 'purpose': _companyPurposeController.text.trim()},
        'personalDetails': {'location': _personalLocationController.text.trim(), 'purpose': _personalPurposeController.text.trim()},
        'hosName': _hos,
        'hodName': _hod,
        'mancoMemberName': mancoMember.name,
        'mancoMemberUserId': mancoMember.id,
        'estimatedTime': {'timeOut': _fmtTime(_timeOut!), 'timeIn': _fmtTime(_timeIn!)},
      },
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Gate Pass submitted successfully!');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final usersState = ref.watch(usersProvider);
    final hosUsers = usersState.byRole('hos');
    final hodUsers = usersState.byRole('hod');
    final mancoMembers = usersState.byRole('manco_member');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gate Pass')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.person_outline,
            title: 'Employee Details',
            child: PrefilledDetailsBox(rows: {
              'Name': user?.name ?? '',
              'Position': user?.position ?? '',
              'Staff ID': user?.employeeId ?? '',
              'Department': user?.department ?? '',
            }),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.info_outline,
            title: 'Purpose of Exit',
            child: Column(
              children: [
                _purposeOption(
                  value: 'company',
                  title: '(A) Company Business',
                  locationController: _companyLocationController,
                  purposeController: _companyPurposeController,
                ),
                const SizedBox(height: 10),
                _purposeOption(
                  value: 'personal',
                  title: '(B) Personal Matter',
                  locationController: _personalLocationController,
                  purposeController: _personalPurposeController,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.shield_outlined,
            title: 'Digital Approvals',
            child: Column(
              children: [
                ApproverDropdown(label: 'Head of Section', options: hosUsers, value: _hos, isLoading: usersState.isLoading, includeNotApplicable: true, onChanged: (v) => setState(() => _hos = v)),
                const SizedBox(height: 12),
                ApproverDropdown(label: 'Head of Department', options: hodUsers, value: _hod, isLoading: usersState.isLoading, includeNotApplicable: true, onChanged: (v) => setState(() => _hod = v)),
                const SizedBox(height: 12),
                ApproverDropdown(
                  label: 'Manco Member',
                  options: mancoMembers,
                  value: _mancoMemberId,
                  isLoading: usersState.isLoading,
                  useUserIdAsValue: true,
                  onChanged: (v) => setState(() => _mancoMemberId = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '04',
            icon: Icons.access_time,
            title: 'Security & HR Log',
            child: Row(
              children: [
                Expanded(child: _timeField('Time Out', _timeOut, () => _pickTime(isOut: true))),
                const SizedBox(width: 12),
                Expanded(child: _timeField('Time In', _timeIn, () => _pickTime(isOut: false))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox() : const Icon(Icons.send, size: 16),
            label: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Gate Pass'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _purposeOption({
    required String value,
    required String title,
    required TextEditingController locationController,
    required TextEditingController purposeController,
  }) {
    final selected = _purposeType == value;
    return InkWell(
      onTap: () => setState(() => _purposeType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: locationController,
              enabled: selected,
              decoration: const InputDecoration(isDense: true, labelText: 'Location'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: purposeController,
              enabled: selected,
              decoration: const InputDecoration(isDense: true, labelText: 'Purpose'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeField(String label, TimeOfDay? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.access_time, size: 18)),
            child: Text(value == null ? '--:--' : _fmtTime(value)),
          ),
        ),
      ],
    );
  }
}
