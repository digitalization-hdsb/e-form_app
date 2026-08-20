import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/form_section_card.dart';

const _urgencyOptions = ['Low', 'Medium', 'High'];
const _issueTypeOptions = [
  'Administration (e.g. Hardware, Laptop, PC, Printing)',
  'ERP LN (BAAN)',
  'ERP Monitor',
  'Internet Downtime',
  'Email Downtime',
  'Cyber Attacks / Spam / Phishing',
  'Data Recovery',
];
const _superiorEmailOptions = [
  'azmi@hidsb.com', 'Hairulnizam@hidsb.com', 'Zaini@hidsb.com', 'Ismail.ibrahim@hidsb.com',
  'Huzaimi@hidsb.com', 'Norhafiza@hidsb.com', 'Norhaza@hidsb.com', 'Fairuz.hasnan@hidsb.com',
  'Fikri@hidsb.com', 'Akmal.hisham@hidsb.com', 'Ashraf.mustaffa@hidsb.com', 'Zulhafez@hidsb.com',
  'Adib@hidsb.com', 'Shahrilfarizal@hidsb.com', 'Mohdrosli@hidsb.com', 'Zaidei.sanusi@hidsb.com',
  'Lokman.salehuddin@hidsb.com', 'Salleh.hamid@hidsb.com', 'Abdkarnain@hidsb.com', 'Suparman.subhan@hidsb.com',
  'Saiful.hazrin@hidsb.com', 'Zaharahomar@hidsb.com', 'Nantha@hidsb.com', 'Akif@hidsb.com',
  'Khairuddin@hidsb.com', 'Norazlee@hidsb.com', 'Zulkernine@hidsb.com', 'Zairi.amirodin@hidsb.com', 'Jasni@hidsb.com',
];

class ItHelpDeskFormScreen extends ConsumerStatefulWidget {
  const ItHelpDeskFormScreen({super.key});

  @override
  ConsumerState<ItHelpDeskFormScreen> createState() => _ItHelpDeskFormScreenState();
}

class _ItHelpDeskFormScreenState extends ConsumerState<ItHelpDeskFormScreen> {
  String? _superiorEmail;
  String? _urgency;
  String? _issueType;
  final _issueExplanationController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _issueExplanationController.dispose();
    super.dispose();
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (user.department.isEmpty) return _showError('Your department is required before submitting. Please update your profile.');
    if (_superiorEmail == null) return _showError('Select the superior email.');
    if (_urgency == null) return _showError('Select the urgency level.');
    if (_issueType == null) return _showError('Select the type of issue or request.');
    if (_issueExplanationController.text.trim().isEmpty) return _showError('Explain the issue or request.');

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'it_help_desk',
      status: 'pending',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'staffId': user.employeeId,
        'position': user.position,
        'employeeInfo': {'employeeNumber': user.employeeId, 'position': user.position},
        'requesterName': user.name,
        'divisionDepartment': user.department,
        'contactEmail': user.email,
        'superiorEmail': _superiorEmail,
        'urgency': _urgency,
        'reportFor': 'IT Issues / Troubleshooting / Request',
        'issueType': _issueType,
        'issueExplanation': _issueExplanationController.text.trim(),
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'IT Help Desk ticket submitted successfully.');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('IT Help Desk Ticket')),
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
            icon: Icons.report_gmailerrorred_outlined,
            title: 'Ticket Classification',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Urgency *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _urgency,
                  hint: const Text('Select urgency'),
                  items: _urgencyOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                  onChanged: (v) => setState(() => _urgency = v),
                ),
                const SizedBox(height: 12),
                const Text('Superior Email *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _superiorEmail,
                  isExpanded: true,
                  hint: const Text('Select superior email'),
                  items: _superiorEmailOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _superiorEmail = v),
                ),
                const SizedBox(height: 12),
                const Text('Type of Issue / Request *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _issueType,
                  isExpanded: true,
                  hint: const Text('Select type of issue or request'),
                  items: _issueTypeOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _issueType = v),
                ),
                const SizedBox(height: 12),
                const Text('Issue Explanation or Request *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _issueExplanationController,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Describe the issue, troubleshooting details, or request...'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Ticket'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
