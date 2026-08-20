import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/approval_progress_bar.dart';
import '../../widgets/approval_stages.dart';
import '../../widgets/employee_info_card.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/submission_data_view.dart';

enum _Filter { all, pending, approved, rejected }

class MySubmissionsScreen extends ConsumerStatefulWidget {
  const MySubmissionsScreen({super.key});

  @override
  ConsumerState<MySubmissionsScreen> createState() => _MySubmissionsScreenState();
}

class _MySubmissionsScreenState extends ConsumerState<MySubmissionsScreen> {
  _Filter _filter = _Filter.all;

  static const _icons = {
    'car_rental': Icons.directions_car_filled_outlined,
    'leave': Icons.calendar_today_outlined,
    'claim': Icons.attach_money,
  };

  bool _matchesFilter(Submission s) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.pending:
        return !['approved', 'completed', 'paid', 'rejected', 'voided'].contains(s.status);
      case _Filter.approved:
        return ['approved', 'completed', 'paid'].contains(s.status);
      case _Filter.rejected:
        return s.status == 'rejected';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isLoading = ref.watch(submissionsProvider).isLoading;
    final all = ref.watch(mySubmissionsProvider(user?.id));
    final filtered = all.where(_matchesFilter).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: Column(
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('All', _Filter.all),
                    _chip('Pending', _Filter.pending),
                    _chip('Approved', _Filter.approved),
                    _chip('Rejected', _Filter.rejected),
                  ],
                ),
              ),
            ),
            Expanded(
              child: isLoading && all.isEmpty
                  ? const ListRowsSkeleton()
                  : filtered.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(child: Text('No submissions yet.', style: TextStyle(color: AppColors.mutedForeground))),
                          ],
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _SubmissionTile(
                            submission: filtered[index],
                            icon: _icons[filtered[index].formType] ?? Icons.description_outlined,
                          ),
                        ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _Filter value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(color: selected ? AppColors.onPrimary : AppColors.foreground, fontWeight: FontWeight.w600),
        backgroundColor: AppColors.card,
        side: BorderSide(color: AppColors.border),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  final Submission submission;
  final IconData icon;

  const _SubmissionTile({required this.submission, required this.icon});

  @override
  Widget build(BuildContext context) {
    final submittedAt = DateTime.tryParse(submission.submittedAt);
    final dateLabel = submittedAt != null ? DateFormat('d MMM yyyy, h:mm a').format(submittedAt) : '';

    return InkWell(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _SubmissionDetailSheet(submission: submission),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(submission.formTypeLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text('${submission.refNo ?? submission.id.substring(0, 8)} · $dateLabel', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
                StatusBadge(status: submission.status),
              ],
            ),
            const SizedBox(height: 12),
            ApprovalProgressBar(formType: submission.formType, status: submission.status),
          ],
        ),
      ),
    );
  }
}

class _SubmissionDetailSheet extends StatelessWidget {
  final Submission submission;

  const _SubmissionDetailSheet({required this.submission});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(submission.formTypeLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                StatusBadge(status: submission.status),
              ],
            ),
            if (submission.refNo != null) Text('Ref No: ${submission.refNo}', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EmployeeInfoCard(submission: submission),
                    const SizedBox(height: 16),
                    SubmissionDataView(data: submission.data, extraHiddenKeys: identityDataKeys),
                    const SizedBox(height: 14),
                    ApprovalStages(submission: submission),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
