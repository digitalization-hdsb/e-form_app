import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/approval_stages.dart';
import '../../widgets/employee_info_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/submission_data_view.dart';

const _excludedFormTypes = {
  'inventory_addition', 'ppe_request', 'waste_inventory', 'mixing_chemical_stages', 'final_discharge', 'daily_operation_monitoring',
};

/// Mirrors pages/AllSubmissionsPage.tsx — Super Admin oversight across every
/// approval-flow form type, plus permanent deletion of terminal-status
/// records (completed/rejected/voided only).
class AllSubmissionsScreen extends ConsumerStatefulWidget {
  const AllSubmissionsScreen({super.key});

  @override
  ConsumerState<AllSubmissionsScreen> createState() => _AllSubmissionsScreenState();
}

class _AllSubmissionsScreenState extends ConsumerState<AllSubmissionsScreen> {
  final _searchController = TextEditingController();
  String _formTypeFilter = 'all';

  static const _quickFilters = {
    'all': 'All',
    'car_rental': 'Car',
    'claim': 'Claim',
    'leave': 'Gate Pass',
    'cctv_access_request': 'CCTV',
    'it_help_desk': 'IT Help Desk',
    'it_admin_request': 'IT Admin',
    'it_application_request': 'IT App',
    'it_facilities_requisition': 'IT Facilities',
    'ppe_purchase': 'PPE Purchase',
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Submission s, String query) {
    if (query.isEmpty) return true;
    final haystack = [s.employeeName, s.refNo ?? '', s.department, s.status, s.formTypeLabel].join(' ').toLowerCase();
    return haystack.contains(query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final query = _searchController.text.trim();
    final results = state.submissions
        .where((s) => !_excludedFormTypes.contains(s.formType))
        .where((s) => _formTypeFilter == 'all' || s.formType == _formTypeFilter)
        .where((s) => _matches(s, query))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text('SEARCH', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search employee, ref no, department, status...', isDense: true),
          ),
          const SizedBox(height: 16),
          Text('FORM TYPE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickFilters.entries
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: _formTypeFilter == e.key,
                          onSelected: (_) => setState(() => _formTypeFilter = e.key),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: _formTypeFilter == e.key ? AppColors.onPrimary : AppColors.foreground, fontWeight: FontWeight.w600, fontSize: 11),
                          backgroundColor: AppColors.card,
                          side: BorderSide(color: AppColors.border),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('SUBMISSIONS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
              const Spacer(),
              Text('${results.length}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 8),
          if (state.isLoading && state.submissions.isEmpty)
            Column(children: [for (var i = 0; i < 6; i++) Padding(padding: const EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 72, borderRadius: BorderRadius.circular(14)))])
          else if (results.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No matching submissions.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final submission in results) _SubmissionTile(submission: submission),
        ],
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Submission submission;

  const _SubmissionTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateTime.tryParse(submission.submittedAt);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _SubmissionDetailSheet(submission: submission),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(submission.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
                      StatusBadge(status: submission.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(submission.formTypeLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  const SizedBox(height: 2),
                  Text(
                    '${submission.department} · ${submission.refNo ?? submission.id.substring(0, 8)}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
                    style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionDetailSheet extends ConsumerWidget {
  final Submission submission;

  const _SubmissionDetailSheet({required this.submission});

  bool get _canDelete => ['completed', 'rejected', 'voided'].contains(submission.status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Row(
              children: [
                Expanded(child: Text(submission.formTypeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                StatusBadge(status: submission.status),
              ],
            ),
            if (submission.refNo != null) Text('Ref: ${submission.refNo}', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmployeeInfoCard(submission: submission),
                    const SizedBox(height: 14),
                    SubmissionDataView(data: submission.data, extraHiddenKeys: identityDataKeys),
                    const SizedBox(height: 14),
                    ApprovalStages(submission: submission),
                  ],
                ),
              ),
            ),
            if (_canDelete) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showDeleteDialog(context, ref),
                  icon: Icon(Icons.delete_forever_outlined, size: 16, color: AppColors.destructive),
                  label: Text('Permanently Delete', style: TextStyle(color: AppColors.destructive, fontSize: 12.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final refController = TextEditingController();
    final reasonController = TextEditingController();
    final expectedRef = submission.refNo ?? submission.id.substring(0, 8);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permanently delete this submission?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This cannot be undone. Type "$expectedRef" to confirm.', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(controller: refController, decoration: const InputDecoration(labelText: 'Reference Number')),
            const SizedBox(height: 10),
            TextField(controller: reasonController, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive, foregroundColor: Colors.white),
            onPressed: () async {
              if (refController.text.trim() != expectedRef) {
                showErrorSnackBar(dialogContext, 'Reference number does not match.');
                return;
              }
              if (reasonController.text.trim().length < 5) {
                showErrorSnackBar(dialogContext, 'Enter a reason of at least 5 characters.');
                return;
              }
              final result = await ref.read(submissionsProvider.notifier).permanentlyDeleteSubmission(submission.id, reasonController.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                Navigator.pop(context);
                if (result.success) {
                  showSuccessSnackBar(context, 'Submission permanently deleted.');
                } else {
                  showErrorSnackBar(context, result.error ?? 'Failed to delete.');
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
