import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notification_targeting.dart';
import '../core/supabase_config.dart';
import '../models/app_notification.dart';
import 'auth_provider.dart';
import 'submissions_provider.dart';

/// Excluded from notifications entirely, mirroring NotificationBell.tsx.
const _excludedForms = {
  'inventory_addition',
  'ppe_request',
  'ppe_purchase',
  'waste_inventory',
  'mixing_chemical_stages',
  'final_discharge',
  'daily_operation_monitoring',
};

class NotificationStatesState {
  final Set<String> readIds;
  final Set<String> hiddenIds;
  final bool isReady;

  const NotificationStatesState({this.readIds = const {}, this.hiddenIds = const {}, this.isReady = false});
}

/// Syncs per-user read/hidden state for the virtual notifications against
/// the `notification_user_states` table, mirroring the Supabase-backed
/// state (+ realtime subscription) in NotificationBell.tsx.
class NotificationStatesNotifier extends StateNotifier<NotificationStatesState> {
  NotificationStatesNotifier(this._ref) : super(const NotificationStatesState()) {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      final id = next.user?.id;
      if (id != _userId) _bind(id);
    }, fireImmediately: true);
  }

  final Ref _ref;
  String? _userId;
  StreamSubscription? _sub;

  void _bind(String? userId) {
    _userId = userId;
    _sub?.cancel();
    if (userId == null) {
      state = const NotificationStatesState();
      return;
    }
    state = const NotificationStatesState();
    _sub = supabase
        .from('notification_user_states')
        .stream(primaryKey: ['user_id', 'notification_id'])
        .eq('user_id', userId)
        .listen((rows) {
          state = NotificationStatesState(
            readIds: rows.where((r) => r['read_at'] != null).map((r) => r['notification_id'] as String).toSet(),
            hiddenIds: rows.where((r) => r['hidden_at'] != null).map((r) => r['notification_id'] as String).toSet(),
            isReady: true,
          );
        });
  }

  Future<void> _upsert(List<String> ids, {bool hidden = false}) async {
    final userId = _userId;
    if (userId == null || ids.isEmpty) return;
    final now = DateTime.now().toIso8601String();
    final rows = ids
        .map((id) => {
              'user_id': userId,
              'notification_id': id,
              'read_at': now,
              if (hidden) 'hidden_at': now,
              'updated_at': now,
            })
        .toList();
    try {
      await supabase.from('notification_user_states').upsert(rows, onConflict: 'user_id,notification_id');
    } catch (_) {
      // Best-effort, mirrors the website's non-blocking write.
    }
  }

  Future<void> markRead(String id) => _upsert([id]);

  Future<void> markAllRead(List<String> ids) => _upsert(ids);

  Future<void> clearAll(List<String> ids) => _upsert(ids, hidden: true);

  /// Hides a single notification — the per-item swipe-to-delete action on
  /// the Notifications screen, as opposed to [clearAll]'s "Clear all".
  Future<void> clearOne(String id) => _upsert([id], hidden: true);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notificationStatesProvider = StateNotifierProvider<NotificationStatesNotifier, NotificationStatesState>(
  (ref) => NotificationStatesNotifier(ref),
);

/// Mirrors the `allNotifications` useMemo in NotificationBell.tsx: derives
/// the notification list directly from `submissions`, filtered/targeted
/// per the current user's role (HOS, HOD, HR admin, IT admin, etc.), then
/// drops anything the user has hidden.
final notificationsProvider = Provider<List<AppNotification>>((ref) {
  final user = ref.watch(authProvider).user;
  final submissions = ref.watch(submissionsProvider).submissions;
  final states = ref.watch(notificationStatesProvider);
  if (user == null) return [];

  final notifs = <AppNotification>[];
  final now = DateTime.now();

  for (final s in submissions) {
    if (_excludedForms.contains(s.formType)) continue;

    final target = getNotificationTarget(user, s);
    final submittedAt = DateTime.tryParse(s.submittedAt);
    // Mirrors the web: an unparseable date (NaN there) counts as not recent.
    final isRecent = submittedAt != null && now.difference(submittedAt).inMinutes / (60 * 24) < 14;
    if (!isRecent && target == null) continue;

    final id = '${s.id}-${s.status}';
    final createdAt = (s.data['lastUpdatedAt'] as String?) ?? s.submittedAt;

    if (s.submittedBy == user.id && ['approved', 'rejected', 'paid'].contains(s.status)) {
      notifs.add(AppNotification(
        id: id,
        formType: s.formType,
        employeeName: 'You',
        createdAt: createdAt,
        read: states.readIds.contains(id),
        url: '/submissions',
        type: NotificationKind.self,
        status: s.status,
      ));
    }

    if (target != null && s.submittedBy != user.id) {
      notifs.add(AppNotification(
        id: id,
        formType: s.formType,
        employeeName: s.employeeName,
        createdAt: createdAt,
        read: states.readIds.contains(id),
        url: target.path,
        type: NotificationKind.action,
        status: s.status,
        recipientType: target.recipientType,
      ));
    }
  }

  notifs.sort((a, b) => (DateTime.tryParse(b.createdAt) ?? now).compareTo(DateTime.tryParse(a.createdAt) ?? now));
  return notifs.where((n) => !states.hiddenIds.contains(n.id)).toList();
});

final unreadNotificationCountProvider = Provider<int>((ref) {
  final states = ref.watch(notificationStatesProvider);
  if (!states.isReady) return 0;
  return ref.watch(notificationsProvider).where((n) => !n.read).length;
});
