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

enum _Tab { reviewRequired, paymentRequired, inProgress, history }

/// Mirrors pages/FinanceDashboard.tsx: reviews petty-cash claims once HOP
/// has signed off (`pending_finance_review`), then processes final payment
/// once HOF has signed off (`approved_hof`).
class FinanceAdminDashboardScreen extends ConsumerStatefulWidget {
  const FinanceAdminDashboardScreen({super.key});

  @override
  ConsumerState<FinanceAdminDashboardScreen> createState() => _FinanceAdminDashboardScreenState();
}

class _FinanceAdminDashboardScreenState extends ConsumerState<FinanceAdminDashboardScreen> {
  _Tab _tab = _Tab.reviewRequired;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final claims = state.submissions.where((s) => s.formType == 'claim').toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final reviewRequired = claims.where((s) => s.status == 'pending_finance_review').toList();
    final paymentRequired = claims.where((s) => s.status == 'approved_hof').toList();
    final inProgress = claims.where((s) => ['pending', 'approved_hos', 'approved_hod', 'approved_hop'].contains(s.status)).toList();
    final history = claims.where((s) => ['approved', 'rejected', 'paid', 'completed', 'voided'].contains(s.status)).toList();

    final visible = switch (_tab) {
      _Tab.reviewRequired => reviewRequired,
      _Tab.paymentRequired => paymentRequired,
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
              TabBarItem(value: _Tab.reviewRequired, label: 'Review', count: reviewRequired.length),
              TabBarItem(value: _Tab.paymentRequired, label: 'Payment', count: paymentRequired.length),
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
                        children: [SizedBox(height: 80), Center(child: Text('No claims here.', style: TextStyle(color: AppColors.mutedForeground)))],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _ClaimTile(submission: visible[index]),
                      ),
          ),
        ],
      ),
    );
  }

}

class _ClaimTile extends StatelessWidget {
  final Submission submission;

  const _ClaimTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateTime.tryParse(submission.submittedAt);
    final actionable = ['pending_finance_review', 'approved_hof'].contains(submission.status);
    final totalAmount = submission.data['totalAmount'];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ClaimDetailSheet(submission: submission),
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
                Text(totalAmount != null ? 'RM ${totalAmount.toString()}' : '', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${submission.refNo ?? submission.id.substring(0, 8)}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                  ),
                ),
                StatusBadge(status: submission.status),
              ],
            ),
            const SizedBox(height: 10),
            ApprovalOverview(formType: 'claim', status: submission.status, rejectedStage: submission.data['rejectedStage'] as String?),
          ],
        ),
      ),
    );
  }
}

class _ClaimDetailSheet extends ConsumerStatefulWidget {
  final Submission submission;

  const _ClaimDetailSheet({required this.submission});

  @override
  ConsumerState<_ClaimDetailSheet> createState() => _ClaimDetailSheetState();
}

class _ClaimDetailSheetState extends ConsumerState<_ClaimDetailSheet> {
  final _remarkController = TextEditingController();
  final _financeCodeController = TextEditingController();
  final _amountPaidController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final total = widget.submission.data['totalAmount'];
    if (total != null) _amountPaidController.text = double.tryParse(total.toString())?.toStringAsFixed(2) ?? '';
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _financeCodeController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  Future<void> _reviewAction(bool approve) async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    final history = appendApprovalRemark(
      widget.submission.data['approvalRemarksHistory'] as List?,
      actorName: user.name,
      actorRole: 'Finance Admin',
      action: approve ? 'approved' : 'rejected',
      remark: _remarkController.text.trim(),
    );

    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: approve ? 'approved_hop' : 'rejected',
      dataToMerge: {
        'finance_admin_remarks': _remarkController.text.trim(),
        'approvalRemarksHistory': history,
        if (!approve) 'rejectedStage': 'finance_review',
        'financeReviewedByName': user.name,
        'financeReviewedById': user.id,
        'financeReviewedAt': DateTime.now().toIso8601String(),
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      if (approve) {
        showSuccessSnackBar(context, 'Approved — proceeding to Head of Finance.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected.')));
      }
    } else {
      _showError(result.error ?? 'Action failed.');
    }
  }

  Future<void> _rejectFromPayment() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isSubmitting = true);

    final history = appendApprovalRemark(
      widget.submission.data['approvalRemarksHistory'] as List?,
      actorName: user.name,
      actorRole: 'Finance Admin',
      action: 'rejected',
      remark: _remarkController.text.trim(),
    );

    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: 'rejected',
      dataToMerge: {
        'finance_admin_remarks': _remarkController.text.trim(),
        'approvalRemarksHistory': history,
        'rejectedStage': 'admin',
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected.')));
    } else {
      _showError(result.error ?? 'Action failed.');
    }
  }

  Future<void> _processPayment() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_financeCodeController.text.trim().isEmpty) {
      _showError('Please enter the GL finance code.');
      return;
    }
    final amount = double.tryParse(_amountPaidController.text.trim());
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount paid.');
      return;
    }

    setState(() => _isSubmitting = true);
    final history = appendApprovalRemark(
      widget.submission.data['approvalRemarksHistory'] as List?,
      actorName: user.name,
      actorRole: 'Finance Admin',
      action: 'payment_processed',
      remark: _remarkController.text.trim(),
    );

    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: 'paid',
      dataToMerge: {
        'finance_admin_remarks': _remarkController.text.trim(),
        'approvalRemarksHistory': history,
        'financeCode': _financeCodeController.text.trim(),
        'amountPaid': amount.toStringAsFixed(2),
        'financePaidByName': user.name,
        'financePaidById': user.id,
        'financePaidAt': DateTime.now().toIso8601String(),
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, 'Payment processed.');
    } else {
      _showError(result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final isReviewStage = s.status == 'pending_finance_review';
    final isPaymentStage = s.status == 'approved_hof';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
                const Expanded(child: Text('Petty Cash Claim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
            if (isReviewStage) ...[
              const SizedBox(height: 10),
              TextField(controller: _remarkController, maxLines: 2, decoration: const InputDecoration(labelText: 'Remark')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => _reviewAction(false),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : () => _reviewAction(true),
                      child: _isSubmitting
                          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                          : const Text('Approve & Proceed to HOF'),
                    ),
                  ),
                ],
              ),
            ],
            if (isPaymentStage) ...[
              const SizedBox(height: 10),
              TextField(controller: _financeCodeController, decoration: const InputDecoration(labelText: 'GL Finance Code *')),
              const SizedBox(height: 10),
              TextField(
                controller: _amountPaidController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount Paid (RM) *'),
              ),
              const SizedBox(height: 10),
              TextField(controller: _remarkController, maxLines: 2, decoration: const InputDecoration(labelText: 'Remark')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _rejectFromPayment,
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _processPayment,
                      child: _isSubmitting
                          ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                          : const Text('Process Payment'),
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
