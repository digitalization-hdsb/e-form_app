import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/approval_remark.dart';
import '../models/submission.dart';

enum _StageState { approved, rejected, pending, skipped, notApplicable, out, completed }

class _Stage {
  final String role;
  final String approver;
  final _StageState state;
  const _Stage(this.role, this.approver, this.state);
}

/// Verbatim port of `getApprovalStages` in components/ApprovalOverview.tsx —
/// resolves, per form type, which role is next and who actually acted at
/// each stage (falling back to the approval-remarks history, then a role
/// placeholder), not just a bare done/pending flag.
List<_Stage> _stagesFor(Submission submission) {
  final data = submission.data;
  final statusBeforeVoid = data['statusBeforeVoid'] as String?;
  final status = (submission.status == 'voided' && statusBeforeVoid != null) ? statusBeforeVoid : submission.status;
  final isRejected = status == 'rejected';
  final rejectedStage = (data['rejectedStage'] as String?) ?? (isRejected ? 'hos' : null);
  final hosName = (data['hosName'] ?? data['hos'] ?? 'Not selected').toString();
  final hodName = (data['hodName'] ?? data['hod'] ?? 'Not selected').toString();
  final history = approvalHistoryFor(data, submission.status);

  String? latestActor(String role, [String? action]) {
    for (final e in history.reversed) {
      if (e.actorRole == role && (action == null || e.action == action)) return e.actorName;
    }
    return null;
  }

  bool inStatus(List<String> list) => list.contains(status);
  bool stageIn(List<String> list) => rejectedStage != null && list.contains(rejectedStage);

  _StageState state(bool done, bool rejected, {bool skipped = false, bool completed = false}) {
    if (rejected) return _StageState.rejected;
    if (isRejected && !done) return _StageState.notApplicable;
    if (skipped) return _StageState.skipped;
    if (completed) return _StageState.completed;
    if (done) return _StageState.approved;
    return _StageState.pending;
  }

  switch (submission.formType) {
    case 'claim':
      final afterHOS = inStatus(['approved_hos', 'approved_hod', 'pending_finance_review', 'approved_hop', 'approved_hof', 'approved', 'paid', 'completed']) ||
          stageIn(['hod', 'hop', 'finance_review', 'hof', 'admin']);
      final afterHOD = inStatus(['approved_hod', 'pending_finance_review', 'approved_hop', 'approved_hof', 'approved', 'paid', 'completed']) ||
          stageIn(['hop', 'finance_review', 'hof', 'admin']);
      final afterHOP = inStatus(['pending_finance_review', 'approved_hop', 'approved_hof', 'approved', 'paid', 'completed']) || stageIn(['finance_review', 'hof', 'admin']);
      final afterFinanceReview = inStatus(['approved_hop', 'approved_hof', 'approved', 'paid', 'completed']) || stageIn(['hof', 'admin']);
      final afterHOF = inStatus(['approved_hof', 'approved', 'paid', 'completed']) || rejectedStage == 'admin';
      final paymentCompleted = inStatus(['paid', 'completed']);
      return [
        _Stage('HOS', hosName, state(afterHOS, rejectedStage == 'hos', skipped: hosName == 'N/A')),
        _Stage('HOD', hodName, state(afterHOD, rejectedStage == 'hod', skipped: hodName == 'N/A')),
        _Stage('HOP', (data['hopName'] as String?) ?? 'Not selected', state(afterHOP, rejectedStage == 'hop')),
        _Stage(
          'Finance Review',
          (data['financeReviewedByName'] as String?) ?? latestActor('Finance Admin', 'approved') ?? 'Finance Admin',
          state(afterFinanceReview, rejectedStage == 'finance_review'),
        ),
        _Stage('HOF', (data['hofName'] as String?) ?? 'Not selected', state(afterHOF, rejectedStage == 'hof')),
        _Stage(
          'Payment',
          (data['financePaidByName'] as String?) ?? latestActor('Finance Admin', 'payment_processed') ?? 'Finance Admin',
          state(paymentCompleted, rejectedStage == 'admin', completed: paymentCompleted),
        ),
      ];

    case 'leave':
      final afterHOS = inStatus(['approved_hos', 'approved_hod', 'approved_manco', 'on_leave', 'approved']) || stageIn(['hod', 'manco', 'admin']);
      final afterHOD = inStatus(['approved_hod', 'approved_manco', 'on_leave', 'approved']) || stageIn(['manco', 'admin']);
      final afterManco = inStatus(['approved_manco', 'on_leave', 'approved']) || rejectedStage == 'admin';
      final exited = inStatus(['on_leave', 'approved']);
      final returned = status == 'approved';
      return [
        _Stage('HOS', hosName, state(afterHOS, rejectedStage == 'hos', skipped: hosName == 'N/A')),
        _Stage('HOD', hodName, state(afterHOD, rejectedStage == 'hod', skipped: hodName == 'N/A')),
        _Stage('MANCO', (data['mancoMemberName'] as String?) ?? 'Not selected', state(afterManco, rejectedStage == 'manco')),
        _Stage(
          'Security Exit',
          (data['securityExitReviewedByName'] as String?) ?? (data['securityReviewedByName'] as String?) ?? 'Security Guard',
          state(exited, rejectedStage == 'admin'),
        ),
        _Stage(
          'Security Entry',
          (data['securityEntryReviewedByName'] as String?) ?? (returned ? data['securityReviewedByName'] as String? : null) ?? 'Security Guard',
          returned
              ? _StageState.completed
              : status == 'on_leave'
                  ? _StageState.out
                  : isRejected
                      ? _StageState.notApplicable
                      : _StageState.pending,
        ),
      ];

    default:
      final afterHOS = inStatus(['approved_hos', 'approved_hod', 'approved', 'awaiting_confirmation', 'completed']) || stageIn(['hod', 'admin']);
      final afterHOD = inStatus(['approved_hod', 'approved', 'awaiting_confirmation', 'completed']) || rejectedStage == 'admin';
      final finalCompleted = inStatus(['approved', 'awaiting_confirmation', 'completed']);
      final finalRole = submission.formType == 'car_rental' ? 'HR Admin' : 'IT Admin';
      final finalApprover = submission.formType == 'car_rental'
          ? (data['hrAdminReviewedByName'] as String?) ?? latestActor('HR Admin') ?? 'HR Admin'
          : (data['itAdminReviewedBy'] as String?) ?? latestActor('IT Admin') ?? 'IT Admin';
      return [
        _Stage('HOS', hosName, state(afterHOS, rejectedStage == 'hos', skipped: hosName == 'N/A')),
        _Stage('HOD', hodName, state(afterHOD, rejectedStage == 'hod', skipped: hodName == 'N/A')),
        _Stage(finalRole, finalApprover, state(finalCompleted, rejectedStage == 'admin', completed: status == 'completed')),
      ];
  }
}

({Color bg, Color fg, String label}) _badgeStyle(_StageState state) {
  switch (state) {
    case _StageState.approved:
      return (bg: const Color(0xFF57D51B), fg: Colors.white, label: 'APPROVED');
    case _StageState.rejected:
      return (bg: const Color(0xFFD32F2F), fg: Colors.white, label: 'REJECTED');
    case _StageState.skipped:
      return (bg: const Color(0xFF57D51B), fg: Colors.white, label: 'AUTO-APPROVED');
    case _StageState.notApplicable:
      return (bg: const Color(0x1F6E7280), fg: const Color(0xFF6E7280), label: 'N/A');
    case _StageState.out:
      return (bg: const Color(0xFF6366F1), fg: Colors.white, label: 'OUT');
    case _StageState.completed:
      return (bg: const Color(0xFF57D51B), fg: Colors.white, label: 'COMPLETED');
    case _StageState.pending:
      return (bg: const Color(0x26F59E0B), fg: const Color(0xFFB45309), label: 'PENDING');
  }
}

/// The full "who approved this, and what's the status of each stage" grid
/// shown at the bottom of a submission's detail sheet — mirrors
/// components/ApprovalOverview.tsx exactly (role + approver name + a
/// colored status badge per stage), rather than a bare progress stepper.
class ApprovalStages extends StatelessWidget {
  final Submission submission;

  const ApprovalStages({super.key, required this.submission});

  static const _spacing = 6.0;
  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    final stages = _stagesFor(submission);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('APPROVAL OVERVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // A fixed card width (however carefully picked) only fits 3 per
            // row on some screen widths and 2 on others — dividing the
            // actual available width guarantees 3 columns everywhere.
            final cardWidth = (constraints.maxWidth - _spacing * (_perRow - 1)) / _perRow;
            return Wrap(
              spacing: _spacing,
              runSpacing: _spacing,
              children: [for (final s in stages) _stageCard(s, cardWidth)],
            );
          },
        ),
      ],
    );
  }

  Widget _stageCard(_Stage stage, double width) {
    final badge = _badgeStyle(stage.state);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Text(stage.role, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground)),
          const SizedBox(height: 3),
          Text(
            stage.approver,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, color: AppColors.foreground.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: BoxDecoration(color: badge.bg, borderRadius: BorderRadius.circular(999)),
            child: Text(badge.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: badge.fg, fontSize: 7.8, fontWeight: FontWeight.bold, letterSpacing: 0.2)),
          ),
        ],
      ),
    );
  }
}
