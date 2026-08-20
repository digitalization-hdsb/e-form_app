import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/approval_remark.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/approval_overview.dart';
import '../../widgets/approval_stages.dart';
import '../../widgets/employee_info_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/submission_data_view.dart';
import '../../widgets/underline_tab_bar.dart';
import '../../widgets/void_submission_control.dart';

enum _Tab { actionRequired, inProgress, history }

/// Mirrors pages/AdminDashboard.tsx's "Form Approvals" table — the HR
/// Admin's final approval step for car_rental after HOS + HOD have signed
/// off. Vehicle checkout/check-in itself lives in Car Management.
class HrAdminDashboardScreen extends ConsumerStatefulWidget {
  const HrAdminDashboardScreen({super.key});

  @override
  ConsumerState<HrAdminDashboardScreen> createState() => _HrAdminDashboardScreenState();
}

class _HrAdminDashboardScreenState extends ConsumerState<HrAdminDashboardScreen> {
  _Tab _tab = _Tab.actionRequired;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final carRentals = state.submissions.where((s) => s.formType == 'car_rental').toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final actionRequired = carRentals.where((s) => s.status == 'approved_hod').toList();
    final inProgress = carRentals.where((s) => ['pending', 'approved_hos'].contains(s.status)).toList();
    final history = carRentals.where((s) => ['approved', 'completed', 'rejected', 'voided'].contains(s.status)).toList();

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
                        itemBuilder: (context, index) => _CarRentalTile(submission: visible[index]),
                      ),
          ),
        ],
      ),
    );
  }

}

class _CarRentalTile extends StatelessWidget {
  final Submission submission;

  const _CarRentalTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateTime.tryParse(submission.submittedAt);
    final actionable = submission.status == 'approved_hod';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _CarRentalDetailSheet(submission: submission),
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
                StatusBadge(status: submission.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${submission.data['destination'] ?? '—'} · ${submission.refNo ?? submission.id.substring(0, 8)}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
              style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 10),
            ApprovalOverview(formType: 'car_rental', status: submission.status, rejectedStage: submission.data['rejectedStage'] as String?),
          ],
        ),
      ),
    );
  }
}

class _CarRentalDetailSheet extends ConsumerStatefulWidget {
  final Submission submission;

  const _CarRentalDetailSheet({required this.submission});

  @override
  ConsumerState<_CarRentalDetailSheet> createState() => _CarRentalDetailSheetState();
}

class _CarRentalDetailSheetState extends ConsumerState<_CarRentalDetailSheet> {
  final _remarkController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _act(bool approve) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    final history = appendApprovalRemark(
      widget.submission.data['approvalRemarksHistory'] as List?,
      actorName: user.name,
      actorRole: 'HR Admin',
      action: approve ? 'approved' : 'rejected',
      remark: _remarkController.text.trim(),
    );

    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: approve ? 'approved' : 'rejected',
      dataToMerge: {
        'remarks': _remarkController.text.trim(),
        'approvalRemarksHistory': history,
        if (!approve) 'rejectedStage': 'admin',
        'hrAdminReviewedByName': user.name,
        'hrAdminReviewedById': user.id,
        'hrAdminReviewedAt': DateTime.now().toIso8601String(),
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      if (approve) {
        showSuccessSnackBar(context, 'Approved — ready for vehicle checkout.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected.')));
      }
    } else {
      showErrorSnackBar(context, result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final actionable = s.status == 'approved_hod';

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
                Expanded(child: Text('Company Car Request', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                StatusBadge(status: s.status),
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
                    SubmissionDataView(data: s.data, extraHiddenKeys: identityDataKeys),
                    const SizedBox(height: 14),
                    ApprovalStages(submission: s),
                  ],
                ),
              ),
            ),
            if (actionable) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _remarkController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remark', hintText: 'Add a note for this decision...'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _act(false),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _act(true),
                      child: _isSubmitting
                          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                          : const Text('Approve'),
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
}
