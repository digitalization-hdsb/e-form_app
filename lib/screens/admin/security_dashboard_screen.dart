import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/modern_time_picker.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/underline_tab_bar.dart';

enum _Tab { actionRequired, onLeave, inProgress, history }

/// Mirrors pages/SecurityDashboard.tsx — the Security Guard's exit/entry
/// log for gate passes only, after Manco has signed off.
class SecurityDashboardScreen extends ConsumerStatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  ConsumerState<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends ConsumerState<SecurityDashboardScreen> {
  _Tab _tab = _Tab.actionRequired;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final gatePasses = state.submissions.where((s) => s.formType == 'leave').toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final actionRequired = gatePasses.where((s) => s.status == 'approved_manco').toList();
    final onLeave = gatePasses.where((s) => s.status == 'on_leave').toList();
    final inProgress = gatePasses.where((s) => ['pending', 'approved_hos', 'approved_hod'].contains(s.status)).toList();
    final history = gatePasses.where((s) => ['approved', 'rejected', 'voided'].contains(s.status)).toList();

    final overdue = onLeave.where((s) {
      if (s.data['purposeType'] != 'personal') return false;
      final actualOut = DateTime.tryParse(s.data['securityLog']?['actualTimeOut']?.toString() ?? '');
      if (actualOut == null) return false;
      return DateTime.now().difference(actualOut).inMinutes > 120;
    }).length;

    final visible = switch (_tab) {
      _Tab.actionRequired => actionRequired,
      _Tab.onLeave => onLeave,
      _Tab.inProgress => inProgress,
      _Tab.history => history,
    };

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: Column(
        children: [
          if (overdue > 0)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.destructive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.destructive, size: 18),
                  const SizedBox(width: 8),
                  Text('$overdue personal gate pass${overdue > 1 ? 'es' : ''} overdue (out over 2 hours)', style: TextStyle(color: AppColors.destructive, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          UnderlineTabBar<_Tab>(
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
            tabs: [
              TabBarItem(value: _Tab.actionRequired, label: 'Action', count: actionRequired.length),
              TabBarItem(value: _Tab.onLeave, label: 'On Leave', count: onLeave.length),
              TabBarItem(value: _Tab.inProgress, label: 'In Progress', count: inProgress.length),
              TabBarItem(value: _Tab.history, label: 'History'),
            ],
          ),
          Expanded(
            child: state.isLoading && state.submissions.isEmpty
                ? const ListRowsSkeleton()
                : visible.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [SizedBox(height: 80), Center(child: Text('No gate passes here.', style: TextStyle(color: AppColors.mutedForeground)))],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _GatePassTile(submission: visible[index]),
                      ),
          ),
        ],
      ),
    );
  }

}

class _GatePassTile extends StatelessWidget {
  final Submission submission;

  const _GatePassTile({required this.submission});

  @override
  Widget build(BuildContext context) {
    final passType = submission.data['purposeType'] == 'company' ? 'Company Business' : 'Personal Matter';
    final reason = submission.data['companyDetails']?['purpose'] ?? submission.data['personalDetails']?['purpose'] ?? '';
    final actionable = ['approved_manco', 'on_leave', 'pending', 'approved_hos', 'approved_hod'].contains(submission.status);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _GatePassDetailSheet(submission: submission),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: submission.status == 'approved_manco' ? AppColors.gold : AppColors.border, width: submission.status == 'approved_manco' ? 1.5 : 1),
        boxShadow: AppColors.cardShadow,
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(submission.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                StatusBadge(status: submission.status),
              ],
            ),
            const SizedBox(height: 4),
            Text('$passType${reason.isNotEmpty ? ' · $reason' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(submission.refNo ?? submission.id.substring(0, 8), style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            if (!actionable) const SizedBox() else const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _GatePassDetailSheet extends ConsumerStatefulWidget {
  final Submission submission;

  const _GatePassDetailSheet({required this.submission});

  @override
  ConsumerState<_GatePassDetailSheet> createState() => _GatePassDetailSheetState();
}

class _GatePassDetailSheetState extends ConsumerState<_GatePassDetailSheet> {
  final _vehicleController = TextEditingController();
  final _remarksController = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();
  bool _isSubmitting = false;

  void _showError(String message) => showErrorSnackBar(context, message);

  @override
  void dispose() {
    _vehicleController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  DateTime _timestampForToday(TimeOfDay time) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, time.hour, time.minute);
  }

  Future<void> _exit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _isSubmitting = true);
    final existingLog = Map<String, dynamic>.from(widget.submission.data['securityLog'] as Map? ?? {});
    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: 'on_leave',
      dataToMerge: {
        'securityLog': {...existingLog, 'actualTimeOut': _timestampForToday(_time).toIso8601String(), 'vehicleNo': _vehicleController.text.trim(), 'remarks': _remarksController.text.trim()},
        'remarks': _remarksController.text.trim(),
        'securityExitReviewedByName': user.name,
        'securityExitReviewedById': user.id,
        'securityExitReviewedAt': DateTime.now().toIso8601String(),
      },
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, 'Exit logged.');
    } else {
      _showError(result.error ?? 'Failed to log exit.');
    }
  }

  Future<void> _entry() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final existingLog = Map<String, dynamic>.from(widget.submission.data['securityLog'] as Map? ?? {});
    final exitTime = DateTime.tryParse(existingLog['actualTimeOut']?.toString() ?? '');
    final entryTime = _timestampForToday(_time);
    if (exitTime != null && entryTime.isBefore(exitTime)) {
      return _showError('Entry time must be after the exit time.');
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: 'approved',
      dataToMerge: {
        'securityLog': {...existingLog, 'actualTimeIn': entryTime.toIso8601String(), 'remarks': _remarksController.text.trim()},
        'remarks': _remarksController.text.trim(),
        'securityEntryReviewedByName': user.name,
        'securityEntryReviewedById': user.id,
        'securityEntryReviewedAt': DateTime.now().toIso8601String(),
      },
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, 'Entry logged.');
    } else {
      _showError(result.error ?? 'Failed to log entry.');
    }
  }

  Future<void> _reject() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_remarksController.text.trim().isEmpty) return _showError('Enter a reason before rejecting.');

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).updateSubmission(
      widget.submission.id,
      status: 'rejected',
      dataToMerge: {
        'remarks': _remarksController.text.trim(),
        'rejectedStage': 'admin',
        'securityReviewedByName': user.name,
        'securityReviewedById': user.id,
        'securityReviewedAt': DateTime.now().toIso8601String(),
      },
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected.')));
    } else {
      _showError(result.error ?? 'Action failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final passType = s.data['purposeType'] == 'company' ? 'Company Business' : 'Personal Matter';
    final reason = s.data['companyDetails']?['purpose'] ?? s.data['personalDetails']?['purpose'] ?? '';
    final location = s.data['companyDetails']?['location'] ?? s.data['personalDetails']?['location'] ?? '';
    final estTimeOut = s.data['estimatedTime']?['timeOut'];
    final estTimeIn = s.data['estimatedTime']?['timeIn'];
    final actualOut = DateTime.tryParse(s.data['securityLog']?['actualTimeOut']?.toString() ?? '');
    final actualIn = DateTime.tryParse(s.data['securityLog']?['actualTimeIn']?.toString() ?? '');

    final canExit = s.status == 'approved_manco';
    final canEnter = s.status == 'on_leave';
    final canReject = ['pending', 'approved_hos', 'approved_hod', 'approved_manco'].contains(s.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(s.employeeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                StatusBadge(status: s.status),
              ],
            ),
            if (s.refNo != null) Text('Ref: ${s.refNo}', style: TextStyle(color: AppColors.mutedForeground, fontSize: 12)),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detail('Pass Type', passType),
                    _detail('Reason', reason.toString()),
                    _detail('Location', location.toString()),
                    _detail('Estimated Out', estTimeOut?.toString()),
                    _detail('Estimated In', estTimeIn?.toString()),
                    if (actualOut != null) _detail('Actual Out', DateFormat('d MMM, h:mm a').format(actualOut)),
                    if (actualIn != null) _detail('Actual In', DateFormat('d MMM, h:mm a').format(actualIn)),
                    _detail('Vehicle No.', s.data['securityLog']?['vehicleNo']?.toString()),
                  ],
                ),
              ),
            ),
            if (canExit || canEnter || canReject) ...[
              const SizedBox(height: 10),
              if (canExit || canEnter) ...[
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showModernTimePicker(context: context, initialTime: _time, title: canExit ? 'Time Out' : 'Time In');
                          if (picked != null) setState(() => _time = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: canExit ? 'Time Out' : 'Time In', isDense: true),
                          child: Text(_time.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (canExit) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _vehicleController, decoration: const InputDecoration(labelText: 'Vehicle No. (optional)', isDense: true)),
                ],
                const SizedBox(height: 10),
              ],
              TextField(controller: _remarksController, maxLines: 2, decoration: const InputDecoration(labelText: 'Remarks', isDense: true)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (canReject) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _reject,
                        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (canExit)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _exit,
                        child: _isSubmitting ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark)) : Text('Log Exit'),
                      ),
                    ),
                  if (canEnter)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _entry,
                        child: _isSubmitting ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark)) : Text('Log Entry'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detail(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
