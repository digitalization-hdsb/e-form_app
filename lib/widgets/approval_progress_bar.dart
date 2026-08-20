import 'package:flutter/material.dart';

import '../core/theme.dart';

const _itFormTypes = {'it_help_desk', 'it_admin_request', 'it_application_request', 'it_facilities_requisition'};

/// Mirrors `getOverallStatus` in src/pages/MySubmissions.tsx exactly (same
/// labels/colors/percentages) — the linear progress bar shown per
/// submission, as opposed to the stage-chip ApprovalOverview used on the
/// admin/approver dashboards.
({String label, Color color, double progress}) overallStatus(String formType, String status) {
  if (status == 'rejected') return (label: 'Rejected', color: AppColors.destructive, progress: 1.0);
  if (status == 'voided') return (label: 'Voided', color: const Color(0xFF64748B), progress: 1.0);
  if (status == 'completed') return (label: 'Completed', color: const Color(0xFF10B981), progress: 1.0);
  if (status == 'approved' || status == 'paid') return (label: 'Fully Approved', color: const Color(0xFF10B981), progress: 1.0);

  if (formType == 'claim') {
    if (status == 'approved_hof') return (label: 'Pending Finance Payment', color: const Color(0xFF14B8A6), progress: 0.95);
    if (status == 'approved_hop') return (label: 'Pending HOF', color: const Color(0xFF0EA5E9), progress: 0.85);
    if (status == 'pending_finance_review') return (label: 'Pending Finance Review', color: const Color(0xFFD946EF), progress: 0.75);
    if (status == 'approved_hod') return (label: 'Pending HOP', color: const Color(0xFF3B82F6), progress: 0.60);
    if (status == 'approved_hos') return (label: 'Pending HOD', color: const Color(0xFF0EA5E9), progress: 0.40);
    return (label: 'Pending HOS', color: AppColors.gold, progress: 0.20);
  }

  if (formType == 'leave') {
    if (status == 'on_leave') return (label: 'On Leave', color: const Color(0xFF6366F1), progress: 0.90);
    if (status == 'approved_manco') return (label: 'Pending Security', color: const Color(0xFF3B82F6), progress: 0.80);
    if (status == 'approved_hod') return (label: 'Pending Manco Member', color: const Color(0xFF6366F1), progress: 0.65);
    if (status == 'approved_hos') return (label: 'Pending HOD', color: AppColors.gold, progress: 0.50);
  } else if (formType == 'cctv_access_request') {
    if (status == 'approved_hod') return (label: 'Pending IT Admin', color: const Color(0xFF8B5CF6), progress: 0.75);
    if (status == 'approved_hos') return (label: 'Pending HOD', color: AppColors.gold, progress: 0.50);
  } else if (_itFormTypes.contains(formType)) {
    if (status == 'awaiting_confirmation') return (label: 'Confirm IT Resolution', color: const Color(0xFF0EA5E9), progress: 0.85);
    if (status == 'reopened') return (label: 'Reopened with IT', color: AppColors.gold, progress: 0.45);
    if (formType != 'it_help_desk') {
      if (status == 'approved_hod') return (label: 'Pending IT Admin', color: const Color(0xFF8B5CF6), progress: 0.70);
      if (status == 'approved_hos') return (label: 'Pending HOD', color: const Color(0xFF0EA5E9), progress: 0.45);
      return (label: 'Pending HOS', color: AppColors.gold, progress: 0.20);
    }
    return (label: 'Submitted to IT', color: const Color(0xFF8B5CF6), progress: 0.35);
  } else {
    if (status == 'approved_hod') return (label: 'Pending Admin', color: const Color(0xFF3B82F6), progress: 0.75);
    if (status == 'approved_hos') return (label: 'Pending HOD', color: AppColors.gold, progress: 0.50);
  }

  return (label: 'Pending HOS', color: AppColors.gold, progress: 0.25);
}

class ApprovalProgressBar extends StatelessWidget {
  final String formType;
  final String status;

  const ApprovalProgressBar({super.key, required this.formType, required this.status});

  @override
  Widget build(BuildContext context) {
    final result = overallStatus(formType, status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(result.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: result.color)),
            Text('${(result.progress * 100).round()}%', style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: result.progress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(result.color),
          ),
        ),
      ],
    );
  }
}
