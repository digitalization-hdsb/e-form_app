import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/approver_dropdown.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/modern_time_picker.dart';

const _requestOptions = ['View CCTV Recording', 'Export CCTV Footage', 'Live CCTV Monitoring', 'Screenshot Capture'];
const _purposeOptions = [
  'Security Investigation',
  'Safety Investigation',
  'HR Investigation',
  'Property Damage',
  'Theft Investigation',
  'Accident Investigation',
  'Customer Investigation',
  'Legal Requirement',
  'Audit',
  'Other',
];
const _declarationItems = [
  'CCTV recordings are confidential company information.',
  'Access is strictly limited to the purpose stated in this request.',
  'I shall not copy, distribute, or disclose the footage without written approval.',
  'Any misuse of CCTV footage may result in disciplinary action and/or legal action.',
  "All accessed information will be handled in accordance with the Company's Information Security Policy and applicable personal data protection requirements.",
];

class CctvAccessRequestFormScreen extends ConsumerStatefulWidget {
  const CctvAccessRequestFormScreen({super.key});

  @override
  ConsumerState<CctvAccessRequestFormScreen> createState() => _CctvAccessRequestFormScreenState();
}

class _CctvAccessRequestFormScreenState extends ConsumerState<CctvAccessRequestFormScreen> {
  final Set<String> _requestTypes = {};
  final _cameraLocationController = TextEditingController();
  DateTime? _fromDateTime;
  DateTime? _toDateTime;
  String? _purpose;
  final _otherPurposeController = TextEditingController();
  String? _hos;
  String? _hod;
  bool _declarationAgreed = false;
  bool _isSubmitting = false;

  final _dateFmt = DateFormat('d MMM yyyy, h:mm a');

  @override
  void dispose() {
    _cameraLocationController.dispose();
    _otherPurposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isFrom}) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 365)), lastDate: DateTime(now.year + 1));
    if (date == null || !mounted) return;
    final time = await showModernTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _fromDateTime = combined;
      } else {
        _toDateTime = combined;
      }
    });
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_requestTypes.isEmpty) return _showError('Select at least one type of request.');
    if (_cameraLocationController.text.trim().isEmpty) return _showError('Enter the camera location.');
    if (_fromDateTime == null || _toDateTime == null) return _showError('Select the incident start and end date and time.');
    if (!_toDateTime!.isAfter(_fromDateTime!)) return _showError('The end date and time must be after the start date and time.');
    if (_purpose == null) return _showError('Select the purpose of access.');
    if (_purpose == 'Other' && _otherPurposeController.text.trim().isEmpty) return _showError('Enter the other purpose of access.');
    if (_hos == null || _hod == null) return _showError('Select both the Head of Section and Head of Department.');
    if (!_declarationAgreed) return _showError('Acknowledge the confidentiality declaration before submitting.');

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'cctv_access_request',
      status: _hos == 'N/A' ? 'approved_hos' : 'pending',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'staffId': user.employeeId,
        'position': user.position,
        'employeeInfo': {'employeeNumber': user.employeeId, 'position': user.position},
        'requestTypes': _requestTypes.toList(),
        'cameraLocation': _cameraLocationController.text.trim(),
        'fromDateTime': _fromDateTime!.toIso8601String(),
        'toDateTime': _toDateTime!.toIso8601String(),
        'purpose': _purpose == 'Other' ? _otherPurposeController.text.trim() : _purpose,
        'purposeCategory': _purpose,
        'hosName': _hos,
        'hodName': _hod,
        'confidentialityAcknowledged': true,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'CCTV access request submitted successfully.');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(usersProvider);
    final hosUsers = usersState.byRole('hos');
    final hodUsers = usersState.byRole('hod');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('CCTV Access Request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.check_box_outlined,
            title: 'Type of Request',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _requestOptions.map((option) {
                final selected = _requestTypes.contains(option);
                return FilterChip(
                  label: Text(option),
                  selected: selected,
                  onSelected: (v) => setState(() => v ? _requestTypes.add(option) : _requestTypes.remove(option)),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: TextStyle(fontSize: 12, color: selected ? AppColors.primary : AppColors.foreground, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.location_on_outlined,
            title: 'Camera and Incident Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _cameraLocationController, decoration: const InputDecoration(labelText: 'Camera Location', hintText: 'e.g. Plant 1, Camera 03')),
                const SizedBox(height: 12),
                _dateField('From Date & Time', _fromDateTime, () => _pickDateTime(isFrom: true)),
                const SizedBox(height: 12),
                _dateField('To Date & Time', _toDateTime, () => _pickDateTime(isFrom: false)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.description_outlined,
            title: 'Purpose of Access',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _purpose,
                  isExpanded: true,
                  hint: const Text('Select the purpose of access'),
                  items: _purposeOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) => setState(() => _purpose = v),
                ),
                if (_purpose == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(controller: _otherPurposeController, decoration: const InputDecoration(labelText: 'Other Purpose')),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '04',
            icon: Icons.shield_outlined,
            title: 'Confidentiality Declaration',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in _declarationItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ', style: TextStyle(color: AppColors.mutedForeground)),
                        Expanded(child: Text(item, style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground))),
                      ],
                    ),
                  ),
                CheckboxListTile(
                  value: _declarationAgreed,
                  onChanged: (v) => setState(() => _declarationAgreed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I have read, understood, and agree to the confidentiality declaration.', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '05',
            icon: Icons.person_outline,
            title: 'Approval',
            child: Column(
              children: [
                ApproverDropdown(label: 'Head of Section', options: hosUsers, value: _hos, isLoading: usersState.isLoading, includeNotApplicable: true, onChanged: (v) => setState(() => _hos = v)),
                const SizedBox(height: 12),
                ApproverDropdown(label: 'Head of Department', options: hodUsers, value: _hod, isLoading: usersState.isLoading, onChanged: (v) => setState(() => _hod = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Request'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(value == null ? 'Select date & time' : _dateFmt.format(value)),
          ),
        ),
      ],
    );
  }
}
