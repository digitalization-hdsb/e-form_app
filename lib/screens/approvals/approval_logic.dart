import '../../models/app_user.dart';
import '../../models/submission.dart';

/// One row per stage a signed-in approver can act on. Mirrors the
/// role-assignment checks traced out of ApproverDashboard.tsx: match by
/// `<role>UserId` first, falling back to the legacy `<role>Name` string.
class ApprovalStage {
  final String roleKey; // hos | hod | manco | hop | hof
  final String roleLabel; // HOS | HOD | MANCO | HOP | HOF
  final String requiredStatus;
  final Set<String> formTypes;
  final bool Function(Submission s, AppUser user) isAssignedToMe;

  const ApprovalStage({
    required this.roleKey,
    required this.roleLabel,
    required this.requiredStatus,
    required this.formTypes,
    required this.isAssignedToMe,
  });
}

bool _matches(Map<String, dynamic> data, String userIdField, String nameField, AppUser user) {
  final userId = data[userIdField] as String?;
  if (userId != null) return userId == user.id;
  final name = (data[nameField] ?? data[nameField.replaceAll('Name', '')]) as String?;
  return name == user.name;
}

final List<ApprovalStage> approvalStages = [
  ApprovalStage(
    roleKey: 'hos',
    roleLabel: 'HOS',
    requiredStatus: 'pending',
    formTypes: const {'car_rental', 'leave', 'claim'},
    isAssignedToMe: (s, user) => _matches(s.data, 'hosUserId', 'hosName', user),
  ),
  ApprovalStage(
    roleKey: 'hod',
    roleLabel: 'HOD',
    requiredStatus: 'approved_hos',
    formTypes: const {'car_rental', 'leave', 'claim'},
    isAssignedToMe: (s, user) => _matches(s.data, 'hodUserId', 'hodName', user),
  ),
  ApprovalStage(
    roleKey: 'manco',
    roleLabel: 'MANCO',
    requiredStatus: 'approved_hod',
    formTypes: const {'leave'},
    isAssignedToMe: (s, user) => _matches(s.data, 'mancoMemberUserId', 'mancoMemberName', user),
  ),
  ApprovalStage(
    roleKey: 'hop',
    roleLabel: 'HOP',
    requiredStatus: 'approved_hod',
    formTypes: const {'claim'},
    isAssignedToMe: (s, user) => _matches(s.data, 'hopUserId', 'hopName', user),
  ),
  ApprovalStage(
    roleKey: 'hof',
    roleLabel: 'HOF',
    requiredStatus: 'approved_hop',
    formTypes: const {'claim'},
    isAssignedToMe: (s, user) => _matches(s.data, 'hofUserId', 'hofName', user),
  ),
];

/// The set of roles a user should see an Approver Dashboard for.
const Map<String, String> approverRoleToStageKey = {
  'hos': 'hos',
  'hod': 'hod',
  'manco_member': 'manco',
  'head_of_purchasing': 'hop',
  'head_of_finance': 'hof',
};

bool userHasApproverRole(AppUser user) {
  final roles = {user.role, ...user.secondaryRoles};
  return roles.any(approverRoleToStageKey.containsKey);
}

/// Every stage this submission touches where [user] is the named approver,
/// regardless of whether it's currently their turn (used for "my queue").
List<ApprovalStage> stagesInvolvingMe(Submission s, AppUser user) {
  return approvalStages.where((stage) => stage.formTypes.contains(s.formType) && stage.isAssignedToMe(s, user)).toList();
}

/// Whether it's actionable right now — status matches the stage's required
/// status and the submission hasn't been rejected/voided/completed.
bool isActionableNow(Submission s, ApprovalStage stage) {
  if (['rejected', 'voided', 'completed', 'approved', 'paid'].contains(s.status)) return false;
  return s.status == stage.requiredStatus;
}

/// The next status when [stage] approves this submission — mirrors the
/// N/A-skip and pending_finance_review quirks traced from the website.
String nextStatusOnApprove(Submission s, ApprovalStage stage) {
  switch (stage.roleKey) {
    case 'hos':
      final hodName = s.data['hodName'] ?? s.data['hod'];
      return hodName == 'N/A' ? 'approved_hod' : 'approved_hos';
    case 'hod':
      return 'approved_hod';
    case 'manco':
      return 'approved_manco';
    case 'hop':
      return 'pending_finance_review';
    case 'hof':
      return 'approved_hof';
    default:
      return s.status;
  }
}
