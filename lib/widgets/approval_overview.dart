import 'package:flutter/material.dart';

import '../core/theme.dart';

enum _StageState { done, current, pending, rejected, skipped }

const Map<String, List<String>> _stagesByFormType = {
  'car_rental': ['HOS', 'HOD', 'HR Admin'],
  'leave': ['HOS', 'HOD', 'MANCO', 'Security Exit', 'Security Entry'],
  'claim': ['HOS', 'HOD', 'HOP', 'Finance Review', 'HOF', 'Payment'],
};
const _defaultStages = ['HOS', 'HOD', 'Admin'];

const Map<String, int> _carRentalStageIndex = {'pending': 0, 'approved_hos': 1, 'approved_hod': 2};
const Map<String, int> _leaveStageIndex = {
  'pending': 0,
  'approved_hos': 1,
  'approved_hod': 2,
  'approved_manco': 3,
  'on_leave': 4,
};
const Map<String, int> _claimStageIndex = {
  'pending': 0,
  'approved_hos': 1,
  'approved_hod': 2,
  'pending_finance_review': 3,
  'approved_hop': 4,
  'approved_hof': 5,
};

/// Mirrors components/ApprovalOverview.tsx: a compact stage tracker showing
/// which approver the submission is waiting on, using only `status` and
/// `rejectedStage` from `submission.data` — no extra fetches required.
class ApprovalOverview extends StatelessWidget {
  final String formType;
  final String status;
  final String? rejectedStage;

  const ApprovalOverview({super.key, required this.formType, required this.status, this.rejectedStage});

  @override
  Widget build(BuildContext context) {
    final stages = _stagesByFormType[formType] ?? _defaultStages;
    final indexMap = formType == 'leave'
        ? _leaveStageIndex
        : formType == 'claim'
            ? _claimStageIndex
            : _carRentalStageIndex;

    final isTerminalDone = ['approved', 'completed', 'paid'].contains(status);
    final isRejected = status == 'rejected';
    final isVoided = status == 'voided';
    final currentIndex = isTerminalDone ? stages.length : (indexMap[status] ?? 0);
    final rejectedIndex = rejectedStage != null
        ? stages.indexWhere((s) => s.toLowerCase().replaceAll(' ', '').contains(rejectedStage!.replaceAll('_', '')))
        : -1;

    final states = List<_StageState>.generate(stages.length, (i) {
      if (isVoided) return _StageState.skipped;
      if (isRejected && rejectedIndex >= 0) {
        if (i < rejectedIndex) return _StageState.done;
        if (i == rejectedIndex) return _StageState.rejected;
        return _StageState.skipped;
      }
      if (isRejected) return i == 0 ? _StageState.rejected : _StageState.skipped;
      if (i < currentIndex) return _StageState.done;
      if (i == currentIndex && !isTerminalDone) return _StageState.current;
      return _StageState.pending;
    });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < stages.length; i++) _stageChip(stages[i], states[i]),
      ],
    );
  }

  Widget _stageChip(String label, _StageState state) {
    late Color bg;
    late Color fg;
    late IconData icon;
    switch (state) {
      case _StageState.done:
        bg = const Color(0xFF22B36B);
        fg = Colors.white;
        icon = Icons.check;
      case _StageState.current:
        bg = AppColors.gold;
        fg = AppColors.primaryDark;
        icon = Icons.hourglass_top;
      case _StageState.rejected:
        bg = AppColors.destructive;
        fg = Colors.white;
        icon = Icons.close;
      case _StageState.skipped:
      case _StageState.pending:
        bg = AppColors.border;
        fg = AppColors.mutedForeground;
        icon = Icons.circle_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 10.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
