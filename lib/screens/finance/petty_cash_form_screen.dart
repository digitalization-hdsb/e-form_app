import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/approver_dropdown.dart';
import '../../widgets/form_section_card.dart';
import 'department_codes.dart';

class _ClaimRow {
  String description = '';
  String receiptNo = '';
  String amount = '';
}

class PettyCashFormScreen extends ConsumerStatefulWidget {
  const PettyCashFormScreen({super.key});

  @override
  ConsumerState<PettyCashFormScreen> createState() => _PettyCashFormScreenState();
}

class _PettyCashFormScreenState extends ConsumerState<PettyCashFormScreen> {
  String? _departmentCode;
  DateTime _date = DateTime.now();
  final List<_ClaimRow> _rows = [_ClaimRow(), _ClaimRow()];
  String? _hos;
  String? _hod;
  String? _hop;
  String? _hof;
  final List<PlatformFile> _files = [];
  bool _isSubmitting = false;

  double get _total => _rows.fold(0, (sum, row) => sum + (double.tryParse(row.amount) ?? 0));

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], allowMultiple: true);
    if (result != null) {
      setState(() => _files.addAll(result.files));
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_departmentCode == null) {
      _showError('Please select a Department Code.');
      return;
    }
    if (_hos == null || _hod == null || _hop == null || _hof == null) {
      _showError('Please select all approvers: HOS, HOD, Head of Purchasing, and Head of Finance.');
      return;
    }

    final populatedRows = _rows.where((r) => r.description.trim().isNotEmpty || r.amount.trim().isNotEmpty).toList();
    if (populatedRows.isEmpty) {
      _showError('Please enter at least one claim item.');
      return;
    }
    final incomplete = populatedRows.any((r) => r.description.trim().isEmpty || r.amount.trim().isEmpty);
    if (incomplete) {
      _showError('Every claim item needs both a description and an amount.');
      return;
    }
    final invalidAmount = populatedRows.any((r) => (double.tryParse(r.amount) ?? 0) <= 0);
    if (invalidAmount) {
      _showError('Every claim amount must be greater than RM 0.00.');
      return;
    }
    if (_total > 5000) {
      _showError('The total claim amount cannot exceed RM 5000.');
      return;
    }
    if (_files.isEmpty) {
      _showError('Please attach at least one receipt or supporting document.');
      return;
    }

    setState(() => _isSubmitting = true);

    final attachmentUrls = <String>[];
    try {
      for (final file in _files) {
        final path = 'public/${user.id}/${DateTime.now().microsecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
        if (file.bytes != null) {
          await supabase.storage.from('form-attachments').uploadBinary(path, file.bytes!);
        } else if (file.path != null) {
          await supabase.storage.from('form-attachments').upload(path, File(file.path!));
        }
        attachmentUrls.add(supabase.storage.from('form-attachments').getPublicUrl(path));
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Attachment upload failed: $e');
      return;
    }

    final usersState = ref.read(usersProvider);
    String? idFor(String? name) {
      if (name == null || name == 'N/A') return null;
      final match = usersState.users.where((u) => u.name == name);
      return match.isEmpty ? null : match.first.id;
    }

    final initialStatus = _hos == 'N/A' ? (_hod == 'N/A' ? 'approved_hod' : 'approved_hos') : 'pending';

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'claim',
      status: initialStatus,
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'employeeInfo': {
          'name': user.name,
          'phone': user.phone,
          'employeeNumber': user.employeeId,
          'avatar': user.avatar,
          'department': user.department,
          'position': user.position,
          'departmentCode': _departmentCode,
          'date': DateFormat('yyyy-MM-dd').format(_date),
        },
        'claimRows': populatedRows
            .map((r) => {'description': r.description.trim(), 'receiptNo': r.receiptNo.trim(), 'amount': (double.parse(r.amount)).toStringAsFixed(2)})
            .toList(),
        'hosName': _hos,
        'hodName': _hod,
        'hopName': _hop,
        'hofName': _hof,
        'totalAmount': double.parse(_total.toStringAsFixed(2)),
        'hosUserId': idFor(_hos),
        'hodUserId': idFor(_hod),
        'hopUserId': idFor(_hop),
        'hofUserId': idFor(_hof),
        'attachment': attachmentUrls.isNotEmpty ? attachmentUrls.first : null,
        'attachments': attachmentUrls,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Petty cash claim submitted successfully!');
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
    final hopUsers = usersState.byRole('head_of_purchasing');
    final hofUsers = usersState.byRole('head_of_finance');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Petty Cash Claim')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.person_outline,
            title: 'Employee Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrefilledDetailsBox(rows: {
                  'Name': user?.name ?? '',
                  'Position': user?.position ?? '',
                  'Staff ID': user?.employeeId ?? '',
                  'Department': user?.department ?? '',
                }),
                const SizedBox(height: 14),
                const Text('Department Code *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _departmentCode,
                  isExpanded: true,
                  hint: const Text('Select Department Code'),
                  items: departmentCodes.map((d) => DropdownMenuItem(value: d.code, child: Text('${d.code} | ${d.name}', overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _departmentCode = v),
                ),
                const SizedBox(height: 14),
                const Text('Date *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                    child: Text(DateFormat('d MMM yyyy').format(_date)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.receipt_long_outlined,
            title: 'Claim Details',
            trailing: IconButton(icon: Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => setState(() => _rows.add(_ClaimRow()))),
            child: Column(
              children: [
                for (int i = 0; i < _rows.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Item ${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.mutedForeground)),
                            const Spacer(),
                            if (_rows.length > 1)
                              IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => setState(() => _rows.removeAt(i))),
                          ],
                        ),
                        TextField(
                          decoration: const InputDecoration(isDense: true, labelText: 'Description'),
                          onChanged: (v) => _rows[i].description = v,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(isDense: true, labelText: 'Receipt No.'),
                                onChanged: (v) => _rows[i].receiptNo = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, labelText: 'Amount (RM)'),
                                onChanged: (v) => setState(() => _rows[i].amount = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total: RM ${_total.toStringAsFixed(2)}  (Max RM 5000)', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                ApproverDropdown(label: 'Head of Purchasing', options: hopUsers, value: _hop, isLoading: usersState.isLoading, onChanged: (v) => setState(() => _hop = v)),
                const SizedBox(height: 12),
                ApproverDropdown(label: 'Head of Finance', options: hofUsers, value: _hof, isLoading: usersState.isLoading, onChanged: (v) => setState(() => _hof = v)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '04',
            icon: Icons.attach_file,
            title: 'Supporting Documents',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final file in _files)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(file.name, overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _files.remove(file))),
                      ],
                    ),
                  ),
                OutlinedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.upload_outlined), label: const Text('Upload Receipt(s) (PDF/JPG/PNG)')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox() : const Icon(Icons.send, size: 16),
            label: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
