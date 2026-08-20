enum NotificationKind { self, action }

/// Mirrors `AppNotification` in src/components/NotificationBell.tsx — a
/// virtual notification derived from a `submissions` row, not a stored row
/// itself. `id` is synthesized as `${submissionId}-${status}`.
class AppNotification {
  final String id;
  final String formType;
  final String employeeName;
  final String createdAt;
  final bool read;
  final String url;
  final NotificationKind type;
  final String? status;
  final String? recipientType;

  const AppNotification({
    required this.id,
    required this.formType,
    required this.employeeName,
    required this.createdAt,
    required this.read,
    required this.url,
    required this.type,
    this.status,
    this.recipientType,
  });
}
