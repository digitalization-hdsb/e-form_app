import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/app_user.dart';
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
import 'approval_logic.dart';

class _QueueEntry {
  final Submission submission;
  final ApprovalStage stage;
  const _QueueEntry(this.submission, this.stage);
}

class ApproverDashboardScreen extends ConsumerStatefulWidget {
  const ApproverDashboardScreen({super.key});

  @override
  ConsumerState<ApproverDashboardScreen> createState() => _ApproverDashboardScreenState();
}

class _ApproverDashboardScreenState extends ConsumerState<ApproverDashboardScreen> {
  bool _actionRequiredOnly = true;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final submissionsState = ref.watch(submissionsProvider);
    if (user == null) return const SizedBox();

    final queue = <_QueueEntry>[];
    for (final s in submissionsState.submissions) {
      for (final stage in stagesInvolvingMe(s, user)) {
        queue.add(_QueueEntry(s, stage));
      }
    }
    queue.sort((a, b) => b.submission.submittedAt.compareTo(a.submission.submittedAt));

    final actionable = queue.where((e) => isActionableNow(e.submission, e.stage)).toList();
    final visible = _actionRequiredOnly ? actionable : queue;

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(
              '${actionable.length} awaiting your action',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          UnderlineTabBar<bool>(
            selected: _actionRequiredOnly,
            onChanged: (v) => setState(() => _actionRequiredOnly = v),
            tabs: [
              TabBarItem(value: true, label: 'Action Required', count: actionable.length),
              TabBarItem(value: false, label: 'All', count: queue.length),
            ],
          ),
          Expanded(
            child: submissionsState.isLoading && submissionsState.submissions.isEmpty
                ? const ListRowsSkeleton()
                : visible.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(child: Text('Nothing here right now.', style: TextStyle(color: AppColors.mutedForeground))),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _QueueTile(entry: visible[index], user: user),
                      ),
          ),
        ],
      ),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  final _QueueEntry entry;
  final AppUser user;

  const _QueueTile({required this.entry, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = entry.submission;
    final actionable = isActionableNow(s, entry.stage);
    final submittedAt = DateTime.tryParse(s.submittedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ApprovalDetailSheet(entry: entry, user: user),
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
                Expanded(child: Text(s.formTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                StatusBadge(status: s.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${s.employeeName} · ${s.refNo ?? s.id.substring(0, 8)}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
              style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 10),
            ApprovalOverview(formType: s.formType, status: s.status, rejectedStage: s.data['rejectedStage'] as String?),
            if (actionable) ...[
              const SizedBox(height: 8),
              Text('Waiting on your ${entry.stage.roleLabel} approval', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApprovalDetailSheet extends ConsumerStatefulWidget {
  final _QueueEntry entry;
  final AppUser user;

  const _ApprovalDetailSheet({required this.entry, required this.user});

  @override
  ConsumerState<_ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends ConsumerState<_ApprovalDetailSheet> {
  final _remarkController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _act(bool approve) async {
    final s = widget.entry.submission;
    final stage = widget.entry.stage;

    setState(() => _isSubmitting = true);
    final nextStatus = approve ? nextStatusOnApprove(s, stage) : 'rejected';
    final history = appendApprovalRemark(
      s.data['approvalRemarksHistory'] as List?,
      actorName: widget.user.name,
      actorRole: stage.roleLabel,
      action: approve ? 'approved' : 'rejected',
      remark: _remarkController.text.trim(),
    );

    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      s.id,
      status: nextStatus,
      dataToMerge: {
        'remarks': _remarkController.text.trim(),
        'approvalRemarksHistory': history,
        if (!approve) 'rejectedStage': stage.roleKey,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      if (approve) {
        showSuccessSnackBar(context, 'Approved.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected.')));
      }
    } else {
      showErrorSnackBar(context, result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.entry.submission;
    final actionable = isActionableNow(s, widget.entry.stage);

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
                StatusBadge(status: s.status),
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
                decoration: InputDecoration(labelText: 'Remark (optional for approve, recommended for reject)', hintText: 'Add a note for ${widget.entry.stage.roleLabel} decision...'),
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
