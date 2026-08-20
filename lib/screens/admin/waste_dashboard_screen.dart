import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/safety_record_tile.dart';
import '../../widgets/safety_remarks_button.dart';

double _rowsNet(Map<String, dynamic> data) {
  final rows = (data['rows'] as List?) ?? [];
  double total = 0;
  for (final r in rows) {
    final row = r as Map;
    final gross = double.tryParse(row['gross']?.toString() ?? '') ?? 0;
    final container = double.tryParse(row['container']?.toString() ?? '') ?? 0;
    final net = gross - container;
    total += net < 0 ? 0 : net;
  }
  return total;
}

/// Mirrors pages/WasteDashboard.tsx: totals + record review + remarks.
/// The pie/bar charts and dynamic waste-type management from the website
/// are left off the mobile build — the record list is the functional core.
class WasteDashboardScreen extends ConsumerWidget {
  const WasteDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(submissionsProvider);
    final records = state.submissions.where((s) => s.formType == 'waste_inventory').toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    double totalSell = 0;
    double totalPay = 0;
    for (final r in records) {
      final net = _rowsNet(r.data);
      if (r.data['category'] == 'sell') {
        totalSell += net;
      } else {
        totalPay += net;
      }
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard('Records', '${records.length}')),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Total (kg)', (totalSell + totalPay).toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Sell (kg)', totalSell.toStringAsFixed(1))),
              const SizedBox(width: 8),
              Expanded(child: _statCard('Pay (kg)', totalPay.toStringAsFixed(1))),
            ],
          ),
          const SizedBox(height: 14),
          const SafetyRemarksButton(dashboard: 'waste_inventory'),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No waste records yet.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final record in records)
              SafetyRecordTile(
                submission: record,
                subtitle: '${record.data['plant'] ?? ''} · ${record.data['category'] == 'sell' ? 'Recycle' : 'Dispose'}',
              ),
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
