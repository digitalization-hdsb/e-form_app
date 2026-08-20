import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/app_notification.dart';
import '../../providers/notifications_provider.dart';

/// Notification-specific form labels, verbatim from the `formTypeLabels`
/// map in src/components/NotificationBell.tsx (a different, shorter set
/// than Submission.formTypeLabels used elsewhere in the app).
const _formTypeLabels = {
  'leave': 'Gate Pass',
  'car_rental': 'Vehicle Request',
  'claim': 'Petty Cash Claim',
  'cctv_access_request': 'CCTV Access Request',
  'it_help_desk': 'IT Help Desk Ticket',
  'it_admin_request': 'IT Request (Admin)',
  'it_application_request': 'IT Request (Application)',
  'it_facilities_requisition': 'IT Facilities Request',
};

String _formLabel(String formType) =>
    _formTypeLabels[formType] ?? formType.replaceAll('_', ' ');

({String title, String message}) _actionCopy(AppNotification n) {
  final label = _formLabel(n.formType);
  final employee = n.employeeName;
  switch (n.recipientType) {
    case 'hos':
      return (
        title: '$label Approval',
        message: "$employee's submission requires HOS approval.",
      );
    case 'hod':
      return (
        title: '$label Approval',
        message: "$employee's submission requires HOD approval.",
      );
    case 'manco_member':
      return (
        title: 'Gate Pass Approval',
        message: "$employee's Gate Pass requires MANCO approval.",
      );
    case 'head_of_purchasing':
      return (
        title: 'Petty Cash Approval',
        message: "$employee's claim requires Head of Purchasing approval.",
      );
    case 'head_of_finance':
      return (
        title: 'Petty Cash Approval',
        message: "$employee's claim requires Head of Finance approval.",
      );
    case 'finance_admin':
      return n.status == 'approved_hof'
          ? (
              title: 'Payment Required',
              message: "$employee's approved claim is ready for payment.",
            )
          : (
              title: 'Finance Review Required',
              message: "$employee's claim is ready for Finance review.",
            );
    case 'hr_admin':
      return (
        title: 'Vehicle Request Action',
        message: "$employee's approved vehicle request requires HR action.",
      );
    case 'it_admin':
      return (
        title: '$label Action',
        message: "$employee's request requires IT action.",
      );
    case 'security_guard':
      return (
        title: 'Gate Pass Ready for Exit',
        message: "$employee's MANCO-approved Gate Pass is ready for Security.",
      );
    default:
      return (
        title: '$label Action',
        message: "$employee's submission requires your action.",
      );
  }
}

IconData _actionIcon(AppNotification n) {
  switch (n.recipientType) {
    case 'finance_admin':
      return n.status == 'approved_hof'
          ? Icons.payments_outlined
          : Icons.fact_check_outlined;
    case 'hr_admin':
      return Icons.directions_car_outlined;
    case 'it_admin':
      return Icons.build_outlined;
    case 'security_guard':
      return Icons.verified_user_outlined;
    default:
      return Icons.access_time;
  }
}

String _formatTime(String isoString) {
  final date = DateTime.tryParse(isoString);
  if (date == null) return '';
  final now = DateTime.now();
  final isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return isToday
      ? 'Today, ${DateFormat('h:mm a').format(date)}'
      : DateFormat('d MMM, h:mm a').format(date);
}

/// A regular shell destination — same instant transition and bottom nav as
/// Home/Dashboard/Profile (see AppShell), rather than a pushed page or modal
/// sheet. Mirrors components/NotificationBell.tsx's dropdown of virtual
/// notifications derived from `submissions`, targeted per the current
/// user's role. The Mark-all-read/Clear actions live in AppShell's AppBar.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return notifications.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 48,
                  color: AppColors.mutedForeground.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'No new notifications',
                  style: TextStyle(color: AppColors.mutedForeground),
                ),
              ],
            ),
          )
        : ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            itemBuilder: (context, i) =>
                _NotificationTile(notification: notifications[i]),
          );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = _formLabel(notification.formType);
    final isSelf = notification.type == NotificationKind.self;
    final actionCopy = isSelf ? null : _actionCopy(notification);

    final title = isSelf ? '$label Update' : actionCopy!.title;
    final Widget messageWidget;
    if (isSelf) {
      if (notification.status == 'paid') {
        messageWidget = const Text(
          'Your claim has been paid. Please acknowledge receipt.',
        );
      } else {
        final rejected = notification.status == 'rejected';
        messageWidget = RichText(
          text: TextSpan(
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 13,
              height: 1.3,
            ),
            children: [
              const TextSpan(text: 'Your form was '),
              TextSpan(
                text: (notification.status ?? '').toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: rejected ? AppColors.destructive : AppColors.success,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        );
      }
    } else {
      messageWidget = Text(
        actionCopy!.message,
        style: TextStyle(
          color: AppColors.mutedForeground,
          fontSize: 13,
          height: 1.3,
        ),
      );
    }

    final IconData icon;
    final Color iconColor;
    final Color iconBg;
    if (isSelf) {
      iconColor = notification.status == 'rejected'
          ? AppColors.destructive
          : AppColors.success;
      iconBg = iconColor.withValues(alpha: 0.1);
      icon = notification.status == 'rejected'
          ? Icons.cancel_outlined
          : notification.status == 'paid'
          ? Icons.payments_outlined
          : Icons.check_circle_outline;
    } else {
      iconColor = AppColors.mutedForeground;
      iconBg = AppColors.mutedForeground.withValues(alpha: 0.12);
      icon = _actionIcon(notification);
    }

    return Slidable(
      key: ValueKey(notification.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.24,
        dismissible: DismissiblePane(
          onDismissed: () => ref
              .read(notificationStatesProvider.notifier)
              .clearOne(notification.id),
        ),
        children: [
          SlidableAction(
            onPressed: (_) => ref
                .read(notificationStatesProvider.notifier)
                .clearOne(notification.id),
            backgroundColor: AppColors.destructive,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          ref
              .read(notificationStatesProvider.notifier)
              .markRead(notification.id);
          context.go(notification.url);
        },
        child: Container(
          color: notification.read
              ? Colors.transparent
              : AppColors.primary.withValues(alpha: 0.05),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    messageWidget,
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
