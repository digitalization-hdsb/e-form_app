import '../models/app_user.dart';
import '../models/submission.dart';

class NotificationRecipient {
  final String path;
  final String recipientType;
  const NotificationRecipient(this.path, this.recipientType);
}

/// Verbatim port of `getNotificationTarget` in src/lib/notifications.ts —
/// the single source of truth for who should see an "action required"
/// notification for a given submission. Pure function, no I/O, so it stays
/// in lockstep with the website as long as both are updated together.
NotificationRecipient? getNotificationTarget(AppUser user, Submission submission) {
  final role = user.role;
  final secondaryRoles = user.secondaryRoles;
  final name = user.name;
  final id = user.id;
  final data = submission.data;

  bool has(String r) => role == r || secondaryRoles.contains(r);

  final isHOS = has('hos');
  final isHOD = has('hod');
  final isHRAdmin = has('hr_admin');
  final isFinanceAdmin = has('finance_admin');
  final isITAdmin = has('it_admin');
  final isSecurityGuard = has('security_guard');
  final isHOP = has('head_of_purchasing');
  final isHOF = has('head_of_finance');
  final isMancoMember = has('manco_member');

  if (isHOS &&
      submission.status == 'pending' &&
      (data['hosUserId'] != null ? data['hosUserId'] == id : (data['hosName'] == name || data['hos'] == name))) {
    return const NotificationRecipient('/admin/approvals', 'hos');
  }

  if (isHOD &&
      submission.status == 'approved_hos' &&
      (data['hodUserId'] != null ? data['hodUserId'] == id : (data['hodName'] == name || data['hod'] == name))) {
    return const NotificationRecipient('/admin/approvals', 'hod');
  }

  if (isMancoMember &&
      submission.formType == 'leave' &&
      submission.status == 'approved_hod' &&
      (data['mancoMemberUserId'] != null ? data['mancoMemberUserId'] == id : data['mancoMemberName'] == name)) {
    return const NotificationRecipient('/admin/approvals', 'manco_member');
  }

  if (isHRAdmin && submission.formType == 'car_rental' && submission.status == 'approved_hod') {
    return const NotificationRecipient('/admin/hr', 'hr_admin');
  }

  if (isFinanceAdmin &&
      submission.formType == 'claim' &&
      ['pending_finance_review', 'approved_hof'].contains(submission.status)) {
    return const NotificationRecipient('/admin/finance', 'finance_admin');
  }

  if (isITAdmin && submission.formType == 'cctv_access_request' && submission.status == 'approved_hod') {
    return const NotificationRecipient('/admin/it', 'it_admin');
  }

  if (isITAdmin &&
      ['it_admin_request', 'it_application_request', 'it_facilities_requisition'].contains(submission.formType) &&
      ['approved_hod', 'reopened'].contains(submission.status)) {
    return const NotificationRecipient('/admin/it/facilities', 'it_admin');
  }

  if (isITAdmin && submission.formType == 'it_help_desk' && ['pending', 'reopened'].contains(submission.status)) {
    return const NotificationRecipient('/admin/it/help-desk', 'it_admin');
  }

  if (isSecurityGuard && submission.formType == 'leave' && submission.status == 'approved_manco') {
    return const NotificationRecipient('/admin/security', 'security_guard');
  }

  if (isHOP &&
      submission.formType == 'claim' &&
      submission.status == 'approved_hod' &&
      (data['hopUserId'] != null ? data['hopUserId'] == id : data['hopName'] == name)) {
    return const NotificationRecipient('/admin/approvals', 'head_of_purchasing');
  }

  if (isHOF &&
      submission.formType == 'claim' &&
      submission.status == 'approved_hop' &&
      (data['hofUserId'] != null ? data['hofUserId'] == id : data['hofName'] == name)) {
    return const NotificationRecipient('/admin/approvals', 'head_of_finance');
  }

  return null;
}
