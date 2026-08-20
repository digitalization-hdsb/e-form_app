import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_config.dart';
import '../models/submission.dart';

/// Matches the format produced by the website's `crypto.randomUUID()` calls
/// in SubmissionsContext.tsx, since the `submissions.id` column has no
/// server-side default and expects the client to supply a value.
String _generateUuidV4() {
  final rand = Random.secure();
  final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int start, int end) => bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

class SubmissionsState {
  final List<Submission> submissions;
  final bool isLoading;

  const SubmissionsState({this.submissions = const [], this.isLoading = true});

  SubmissionsState copyWith({List<Submission>? submissions, bool? isLoading}) {
    return SubmissionsState(submissions: submissions ?? this.submissions, isLoading: isLoading ?? this.isLoading);
  }
}

/// Mirrors src/contexts/SubmissionsContext.tsx for the forms this MVP
/// covers (car_rental, leave/gate-pass, claim). Reference numbers are
/// allocated through the SAME Postgres RPCs the website calls, so numbering
/// stays consistent across both clients.
class SubmissionsNotifier extends StateNotifier<SubmissionsState> {
  SubmissionsNotifier() : super(const SubmissionsState()) {
    refresh();
    _subscribeRealtime();
  }

  StreamSubscription? _sub;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await supabase.from('submissions').select('*').order('submittedAt', ascending: false);
      final subs = (data as List).map((e) => Submission.fromMap(e as Map<String, dynamic>)).toList();
      state = state.copyWith(submissions: subs, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribeRealtime() {
    _sub = supabase
        .from('submissions')
        .stream(primaryKey: ['id'])
        .listen((_) => refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<({bool success, String? error})> addSubmission({
    required String formType,
    required String status,
    required String submittedBy,
    required String employeeName,
    required String department,
    required Map<String, dynamic> data,
  }) async {
    // Daily submission limit for Vehicle Booking & Gate Pass (max 2/day),
    // matching the website's client-side guard in SubmissionsContext.tsx.
    const limitedFormLabels = {'car_rental': 'Vehicle Booking', 'leave': 'Gate Pass'};
    if (limitedFormLabels.containsKey(formType)) {
      final today = DateTime.now();
      final todayCount = state.submissions.where((s) {
        if (s.submittedBy != submittedBy || s.formType != formType) return false;
        final submitted = DateTime.tryParse(s.submittedAt);
        if (submitted == null) return false;
        return submitted.year == today.year && submitted.month == today.month && submitted.day == today.day;
      }).length;
      if (todayCount >= 2) {
        return (
          success: false,
          error: 'Daily submission limit reached. You can submit a maximum of 2 ${limitedFormLabels[formType]} requests per day.',
        );
      }
    }

    // Mirrors the website's ref-no allocation branches in SubmissionsContext.tsx.
    const safetyFormTypes = {'waste_inventory', 'mixing_chemical_stages', 'final_discharge', 'daily_operation_monitoring'};
    const sharedHdsbFormTypes = {'claim', 'car_rental', 'cctv_access_request', 'it_help_desk', 'it_admin_request', 'it_application_request'};

    String? refNo;
    try {
      if (safetyFormTypes.contains(formType)) {
        refNo = await supabase.rpc('next_safety_ref_no') as String?;
      } else if (formType == 'leave') {
        refNo = await supabase.rpc('next_gate_pass_ref_no') as String?;
      } else if (sharedHdsbFormTypes.contains(formType)) {
        refNo = await supabase.rpc('next_hdsb_ref_no') as String?;
      }
    } catch (e) {
      return (success: false, error: 'Could not generate a submission reference number. Please try again.');
    }

    final payload = {
      'id': _generateUuidV4(),
      'formType': formType,
      'status': status,
      'submittedBy': submittedBy,
      'employeeName': employeeName,
      'department': department,
      'data': {...data, 'refNo': refNo},
      'submittedAt': DateTime.now().toIso8601String(),
    };

    try {
      await supabase.from('submissions').insert(payload);
      unawaited(_sendWorkflowNotification());
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<void> _sendWorkflowNotification() async {
    try {
      await supabase.functions.invoke('send-notification', body: {});
    } catch (_) {
      // Best-effort, mirrors the website's non-blocking notification call.
    }
  }

  /// Mirrors SubmissionsContext.tsx `updateSubmission`: merges [dataToMerge]
  /// into the existing `data` JSON blob and optionally changes `status` —
  /// used by every approval action (HOS/HOD/Manco/HOP/HOF/admin) plus
  /// receipt-upload and edit flows.
  Future<({bool success, String? error})> updateSubmission(
    String id, {
    Map<String, dynamic>? dataToMerge,
    String? status,
  }) async {
    final current = state.submissions.where((s) => s.id == id);
    if (current.isEmpty) return (success: false, error: 'Submission not found.');
    final currentSub = current.first;

    final updatedData = <String, dynamic>{
      ...currentSub.data,
      if (dataToMerge != null) ...dataToMerge,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
    };

    final payload = <String, dynamic>{'data': updatedData, if (status != null) 'status': status};

    try {
      await supabase.from('submissions').update(payload).eq('id', id);
      if (status != null && status != currentSub.status) {
        unawaited(_sendWorkflowNotification());
      }
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  /// Convenience alias matching the website's `updateSubmissionStatus` name.
  Future<({bool success, String? error})> updateSubmissionStatus(
    String id,
    String status, {
    Map<String, dynamic>? dataToMerge,
  }) {
    return updateSubmission(id, dataToMerge: dataToMerge, status: status);
  }

  Future<({bool success, String? error})> voidSubmission(String id, String reason) async {
    try {
      await supabase.rpc('void_submission', params: {'p_submission_id': id, 'p_reason': reason.trim()});
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }

  /// Mirrors `permanentlyDeleteSubmission` in SubmissionsContext.tsx: calls
  /// the RPC, then removes any linked attachments from the
  /// `form-attachments` storage bucket before dropping it from local state.
  Future<({bool success, String? error})> permanentlyDeleteSubmission(String id, String reason) async {
    try {
      final data = await supabase.rpc('permanently_delete_submission', params: {'p_submission_id': id, 'p_reason': reason.trim()});
      final values = <String>[];
      if (data is Map) {
        final attachment = data['attachment'];
        if (attachment is String) values.add(attachment);
        final attachments = data['attachments'];
        if (attachments is List) values.addAll(attachments.whereType<String>());
      }
      const marker = '/form-attachments/';
      final paths = values
          .map((v) {
            final index = v.indexOf(marker);
            if (index < 0) return null;
            return Uri.decodeComponent(v.substring(index + marker.length).split('?').first);
          })
          .whereType<String>()
          .toSet()
          .toList();
      if (paths.isNotEmpty) {
        try {
          await supabase.storage.from('form-attachments').remove(paths);
        } catch (_) {
          // Best-effort cleanup, matches the website's non-fatal warning.
        }
      }
      state = state.copyWith(submissions: state.submissions.where((s) => s.id != id).toList());
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: '$e');
    }
  }
}

final submissionsProvider = StateNotifierProvider<SubmissionsNotifier, SubmissionsState>((ref) {
  return SubmissionsNotifier();
});

final mySubmissionsProvider = Provider.family<List<Submission>, String?>((ref, userId) {
  final all = ref.watch(submissionsProvider).submissions;
  if (userId == null) return [];
  return all.where((s) => s.submittedBy == userId).toList();
});
