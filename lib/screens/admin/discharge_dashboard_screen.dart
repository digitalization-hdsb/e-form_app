import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/safety_record_tile.dart';
import '../../widgets/safety_remarks_button.dart';

double _avg(Iterable<num> values) {
  final list = values.where((v) => v > 0).toList();
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}

num _numField(Submission s, String key) => num.tryParse((s.data['finalDischarge']?[key] ?? '').toString()) ?? 0;

/// Mirrors pages/DischargeDashboard.tsx: no HOS/HOD chain, just review +
/// remarks logging. Charting/CSV export are intentionally left off the
/// mobile build (presentational only) — the record list + remarks are the
/// functional core.
class DischargeDashboardScreen extends ConsumerWidget {
  const DischargeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(submissionsProvider);
    final records = state.submissions.where((s) => ['final_discharge', 'daily_operation_monitoring'].contains(s.formType) && s.data['finalDischarge'] != null).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    final avgPh = _avg(records.map((s) => _numField(s, 'ph4')));
    final avgCod = _avg(records.map((s) => _numField(s, 'cod')));
    final avgFlowrate = _avg(records.map((s) => _numField(s, 'flowrate')));

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('Reports', '${records.length}')),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Avg pH', avgPh.toStringAsFixed(2))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Avg COD', avgCod.toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Avg Flowrate', avgFlowrate.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 14),
          const SafetyRemarksButton(dashboard: 'final_discharge'),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No discharge records yet.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final record in records) SafetyRecordTile(submission: record, subtitle: record.data['metaInfo']?['shift'] != null ? '${record.data['metaInfo']['shift']} shift' : null),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.mutedForeground, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
