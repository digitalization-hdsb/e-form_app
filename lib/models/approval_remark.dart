import 'dart:math';

/// Mirrors src/lib/approvalRemarks.ts — one entry per approve/reject/payment
/// action, stored at `submission.data.approvalRemarksHistory`.
class ApprovalRemarkEntry {
  final String id;
  final String actorName;
  final String actorRole;
  final String action; // approved | rejected | payment_processed
  final String remark;
  final String createdAt;

  const ApprovalRemarkEntry({
    required this.id,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.remark,
    required this.createdAt,
  });

  factory ApprovalRemarkEntry.fromMap(Map<String, dynamic> map) {
    return ApprovalRemarkEntry(
      id: (map['id'] ?? '') as String,
      actorName: (map['actorName'] ?? '') as String,
      actorRole: (map['actorRole'] ?? '') as String,
      action: (map['action'] ?? 'approved') as String,
      remark: (map['remark'] ?? '') as String,
      createdAt: (map['createdAt'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'actorName': actorName,
        'actorRole': actorRole,
        'action': action,
        'remark': remark,
        'createdAt': createdAt,
      };
}

List<Map<String, dynamic>> appendApprovalRemark(
  List<dynamic>? existing, {
  required String actorName,
  required String actorRole,
  required String action,
  required String remark,
}) {
  final createdAt = DateTime.now().toIso8601String();
  final random = Random();
  final suffix = List.generate(6, (_) => '0123456789abcdefghijklmnopqrstuvwxyz'[random.nextInt(36)]).join();
  final entry = ApprovalRemarkEntry(
    id: '$createdAt-$suffix',
    actorName: actorName,
    actorRole: actorRole,
    action: action,
    remark: remark,
    createdAt: createdAt,
  );
  return [
    ...?existing?.map((e) => Map<String, dynamic>.from(e as Map)),
    entry.toMap(),
  ];
}

/// Reconstructs a display-only history for older submissions saved before
/// approvalRemarksHistory existed, mirroring ApprovalRemarksHistory.tsx's
/// legacy fallback so we never show a blank history for real remarks.
List<ApprovalRemarkEntry> approvalHistoryFor(Map<String, dynamic> data, String status) {
  final stored = data['approvalRemarksHistory'] as List?;
  if (stored != null && stored.isNotEmpty) {
    return stored.map((e) => ApprovalRemarkEntry.fromMap(Map<String, dynamic>.from(e as Map))).toList();
  }

  final entries = <ApprovalRemarkEntry>[];
  final remarks = (data['remarks'] as String?)?.trim();
  if (remarks != null && remarks.isNotEmpty) {
    final rejectedStage = data['rejectedStage'] as String?;
    final roleLabel = {
          'hos': 'HOS',
          'hod': 'HOD',
          'manco': 'MANCO',
          'hop': 'HOP',
          'hof': 'HOF',
          'admin': 'Admin',
          'finance_review': 'Finance Admin',
        }[rejectedStage] ??
        (status == 'rejected' ? 'Approver' : 'Approver');
    entries.add(ApprovalRemarkEntry(
      id: 'legacy-remarks',
      actorName: roleLabel,
      actorRole: roleLabel,
      action: status == 'rejected' ? 'rejected' : 'approved',
      remark: remarks,
      createdAt: (data['lastUpdatedAt'] as String?) ?? '',
    ));
  }
  final financeRemarks = (data['finance_admin_remarks'] as String?)?.trim();
  if (financeRemarks != null && financeRemarks.isNotEmpty && financeRemarks != remarks) {
    entries.add(ApprovalRemarkEntry(
      id: 'legacy-finance-remarks',
      actorName: 'Finance Admin',
      actorRole: 'Finance Admin',
      action: status == 'paid' ? 'payment_processed' : 'approved',
      remark: financeRemarks,
      createdAt: (data['financePaidAt'] ?? data['financeReviewedAt'] ?? '') as String,
    ));
  }
  return entries;
}
