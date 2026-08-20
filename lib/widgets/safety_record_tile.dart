import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';
import '../models/submission.dart';
import 'submission_data_view.dart';

/// A tappable record row shared by the Safety admin dashboards — opens a
/// generic key/value detail sheet since these forms have no approval
/// workflow to render (they auto-approve on submit).
class SafetyRecordTile extends StatelessWidget {
  final Submission submission;
  final String? subtitle;

  const SafetyRecordTile({super.key, required this.submission, this.subtitle});

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
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(submission.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (submission.refNo != null) Text('Ref: ${submission.refNo}', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
                const SizedBox(height: 12),
                Expanded(child: SingleChildScrollView(controller: scrollController, child: SubmissionDataView(data: submission.data))),
              ],
            ),
          ),
        ),
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
                  Text(submission.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(
                    '${submission.refNo ?? submission.id.substring(0, 8)}${subtitle != null ? ' · $subtitle' : ''}${submittedAt != null ? ' · ${DateFormat('d MMM yyyy').format(submittedAt)}' : ''}',
                    style: TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}
