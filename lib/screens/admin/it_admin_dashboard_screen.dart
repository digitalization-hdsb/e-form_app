import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/approval_stages.dart';
import '../../widgets/employee_info_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/underline_tab_bar.dart';
import '../../widgets/void_submission_control.dart';

enum _Tab { actionRequired, inProgress, history }

const _facilitiesFormTypes = {'it_admin_request', 'it_application_request', 'it_facilities_requisition'};

({String label, Color color}) _requestStatus(String status, String formType) {
  if (status == 'pending' && formType == 'it_help_desk') return (label: 'ACTION REQUIRED', color: const Color(0xFF8B5CF6));
  if (status == 'reopened') return (label: 'REOPENED', color: AppColors.gold);
  if (status == 'awaiting_confirmation') return (label: 'AWAITING EMPLOYEE', color: const Color(0xFF0EA5E9));
  if (status == 'pending') return (label: 'PENDING HOS', color: AppColors.gold);
  if (status == 'approved_hos') return (label: 'PENDING HOD', color: const Color(0xFF0EA5E9));
  if (status == 'approved_hod') return (label: 'PENDING IT ADMIN', color: const Color(0xFF8B5CF6));
  if (status == 'voided') return (label: 'VOIDED', color: AppColors.mutedForeground);
  if (['approved', 'completed'].contains(status)) return (label: formType == 'it_help_desk' ? 'RESOLVED' : 'APPROVED', color: AppColors.success);
  return (label: 'REJECTED', color: AppColors.destructive);
}

bool _isActionRequired(Submission s) {
  if (s.formType == 'cctv_access_request' && s.status == 'approved_hod') return true;
  if (_facilitiesFormTypes.contains(s.formType) && ['approved_hod', 'reopened'].contains(s.status)) return true;
  if (s.formType == 'it_help_desk' && ['pending', 'reopened'].contains(s.status)) return true;
  return false;
}

/// Mirrors pages/ITAdminDashboard.tsx, reused for all three modes (CCTV,
/// Help Desk, Facilities) exactly like the website does via a `mode` prop.
class ItAdminDashboardScreen extends ConsumerStatefulWidget {
  final String mode; // cctv | helpdesk | facilities

  const ItAdminDashboardScreen({super.key, this.mode = 'cctv'});

  @override
  ConsumerState<ItAdminDashboardScreen> createState() => _ItAdminDashboardScreenState();
}

class _ItAdminDashboardScreenState extends ConsumerState<ItAdminDashboardScreen> {
  _Tab _tab = _Tab.actionRequired;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final targetFormType = widget.mode == 'helpdesk' ? 'it_help_desk' : 'cctv_access_request';
    final itRequests = state.submissions.where((s) => widget.mode == 'facilities' ? _facilitiesFormTypes.contains(s.formType) : s.formType == targetFormType).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final actionRequired = itRequests.where(_isActionRequired).toList();
    final inProgress = itRequests
        .where((s) =>
            (['cctv_access_request', ..._facilitiesFormTypes].contains(s.formType) && ['pending', 'approved_hos'].contains(s.status)) ||
            s.status == 'awaiting_confirmation')
        .toList();
    final history = itRequests.where((s) => ['approved', 'rejected', 'completed', 'voided'].contains(s.status)).toList();

    final visible = switch (_tab) {
      _Tab.actionRequired => actionRequired,
      _Tab.inProgress => inProgress,
      _Tab.history => history,
    };

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: Column(
        children: [
          UnderlineTabBar<_Tab>(
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
            tabs: [
              TabBarItem(value: _Tab.actionRequired, label: 'Action Required', count: actionRequired.length),
              TabBarItem(value: _Tab.inProgress, label: 'In Progress', count: inProgress.length),
              TabBarItem(value: _Tab.history, label: 'History'),
            ],
          ),
          Expanded(
            child: state.isLoading && state.submissions.isEmpty
                ? const ListRowsSkeleton()
                : visible.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [SizedBox(height: 80), Center(child: Text('No requests here.', style: TextStyle(color: AppColors.mutedForeground)))],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _RequestTile(submission: visible[index]),
                      ),
          ),
        ],
      ),
    );
  }

}

class _RequestTile extends StatelessWidget {
  final Submission submission;

  const _RequestTile({required this.submission});

  String get _requestType {
    if (_facilitiesFormTypes.contains(submission.formType)) {
      final facilities = (submission.data['facilities'] as List?)?.join(', ');
      return (facilities?.isNotEmpty ?? false) ? facilities! : 'IT Request';
    }
    if (submission.formType == 'it_help_desk') return (submission.data['issueType'] as String?) ?? 'IT Help Desk';
    return (submission.data['cameraLocation'] as String?) ?? 'CCTV Access';
  }

  @override
  Widget build(BuildContext context) {
    final status = _requestStatus(submission.status, submission.formType);
    final submittedAt = DateTime.tryParse(submission.submittedAt);
    final actionable = _isActionRequired(submission);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _RequestDetailSheet(submission: submission),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: actionable ? AppColors.gold : AppColors.border, width: actionable ? 1.5 : 1),
        boxShadow: AppColors.cardShadow,
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(submission.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(status.label, style: TextStyle(color: status.color, fontSize: 9.5, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(_requestType, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(
              '${submission.refNo ?? submission.id.substring(0, 8)}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
              style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestDetailSheet extends ConsumerStatefulWidget {
  final Submission submission;

  const _RequestDetailSheet({required this.submission});

  @override
  ConsumerState<_RequestDetailSheet> createState() => _RequestDetailSheetState();
}

class _RequestDetailSheetState extends ConsumerState<_RequestDetailSheet> {
  final _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  bool get _isHelpDesk => widget.submission.formType == 'it_help_desk';
  bool get _isFacilities => _facilitiesFormTypes.contains(widget.submission.formType);
  bool get _requiresEmployeeConfirmation => _isHelpDesk || _isFacilities;

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _act(String status) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final s = widget.submission;
    if (!_isHelpDesk && s.submittedBy == user.id) return _showError('You cannot review your own IT request.');
    if (status == 'rejected' && _remarksController.text.trim().isEmpty) return _showError('Enter a reason before rejecting this request.');
    if (status == 'awaiting_confirmation' && _remarksController.text.trim().isEmpty) {
      return _showError('Enter a response or completion remark before sending this request to the employee.');
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now().toIso8601String();
    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      s.id,
      status: status,
      dataToMerge: {
        'remarks': _remarksController.text.trim(),
        'itAdminRemarks': _remarksController.text.trim(),
        'itAdminReviewedAt': now,
        'itAdminReviewedBy': user.name,
        'itAdminReviewedById': user.id,
        'reviewedAs': 'it_admin',
        if (status == 'rejected') 'rejectedStage': 'it_admin',
        if (status == 'awaiting_confirmation') ...{
          'resolutionSummary': _remarksController.text.trim(),
          'resolvedAt': now,
          'resolvedBy': user.name,
          'resolvedById': user.id,
        },
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request rejected.')));
      } else {
        showSuccessSnackBar(context, status == 'awaiting_confirmation' ? 'IT response sent to the employee for confirmation.' : 'IT request approved.');
      }
    } else {
      showErrorSnackBar(context, result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final status = _requestStatus(s.status, s.formType);
    final actionable = _isActionRequired(s);
    final data = s.data;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(s.formTypeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: status.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                  child: Text(status.label, style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                VoidSubmissionControl(submissionId: s.id, status: s.status, onVoided: () => Navigator.pop(context), compact: true),
              ],
            ),
            if (s.refNo != null) Text('Ref: ${s.refNo}', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmployeeInfoCard(submission: s),
                    const SizedBox(height: 14),
                    if (_isHelpDesk) ...[
                      _detail('Urgency', data['urgency']),
                      _detail('Type of Issue / Request', data['issueType']),
                      _detail('Issue Explained / Request', data['issueExplanation']),
                      _detail('Contact Email', data['contactEmail']),
                      _detail('Superior Email', data['superiorEmail']),
                    ] else if (_isFacilities) ...[
                      _detail('Facilities Required', (data['facilities'] as List?)?.join(', ')),
                      _detail('SharePoint Folder', data['sharePointFolder']),
                      _detail('Others', data['others']),
                      _detail('Head of Section', data['hosName']),
                      _detail('Head of Department', data['hodName']),
                      if ((data['erpAuthorizationRights'] as List?)?.isNotEmpty ?? false) _authorizationReview(data['erpAuthorizationRights'] as List),
                    ] else ...[
                      _detail('Camera Location', data['cameraLocation']),
                      _detail('Purpose of Access', data['purpose']),
                      _detail('From Date & Time', _fmtDate(data['fromDateTime'])),
                      _detail('To Date & Time', _fmtDate(data['toDateTime'])),
                      _detail('Head of Section', data['hosName']),
                      _detail('Head of Department', data['hodName']),
                      if ((data['requestTypes'] as List?)?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 6),
                        Text('TYPE OF REQUEST', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final type in (data['requestTypes'] as List))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                                child: Text(type.toString(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6))),
                              ),
                          ],
                        ),
                      ],
                      if (data['confidentialityAcknowledged'] == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 16, color: AppColors.success),
                              const SizedBox(width: 8),
                              Expanded(child: Text('Confidentiality declaration acknowledged', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success))),
                            ],
                          ),
                        ),
                      ],
                    ],
                    if (_isHelpDesk && data['resolvedAt'] != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Resolution Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success)),
                            const SizedBox(height: 6),
                            _detail('Resolved By', data['resolvedBy']),
                            _detail('Remarks', data['resolutionSummary']),
                          ],
                        ),
                      ),
                    ],
                    if (!_isHelpDesk) ...[
                      const SizedBox(height: 14),
                      ApprovalStages(submission: s),
                    ],
                  ],
                ),
              ),
            ),
            if (actionable) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _remarksController,
                maxLines: 3,
                decoration: InputDecoration(labelText: _requiresEmployeeConfirmation ? 'IT Response / Remarks' : 'IT Admin Remarks'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _act('rejected'),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _act(_requiresEmployeeConfirmation ? 'awaiting_confirmation' : 'approved'),
                      child: _isSubmitting
                          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                          : Text(_requiresEmployeeConfirmation ? 'Send to Employee' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _fmtDate(dynamic iso) {
    if (iso == null) return null;
    final d = DateTime.tryParse(iso.toString());
    return d == null ? null : DateFormat('d MMM yyyy, h:mm a').format(d);
  }

  Widget _detail(String label, dynamic value) {
    final stringValue = value?.toString();
    if (stringValue == null || stringValue.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground))),
          Expanded(child: Text(stringValue, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _authorizationReview(List rights) {
    final grouped = <String, List<Map>>{};
    for (final r in rights) {
      final map = r as Map;
      grouped.putIfAbsent(map['module'].toString(), () => []).add(map);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('ERP USER ACCESS AUTHORIZATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                child: Text('${rights.length} selected', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final entry in grouped.entries)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  childrenPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                      Text('${entry.value.length} rights', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final r in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: '#${r['id']}  ', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
                                    TextSpan(text: r['right'].toString(), style: TextStyle(fontSize: 13, color: AppColors.foreground)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
