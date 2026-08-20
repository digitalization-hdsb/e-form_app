import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/safety_record_tile.dart';

/// Mirrors components/PurchasesDashboard.tsx — a read-only list of
/// `ppe_purchase` submissions (no editing; those are auto-approved on
/// submit, same as PPE requests).
class PurchasesDashboardScreen extends ConsumerWidget {
  const PurchasesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(submissionsProvider);
    final purchases = state.submissions.where((s) => s.formType == 'ppe_purchase').toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (purchases.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No purchase records yet.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final purchase in purchases)
              SafetyRecordTile(
                submission: purchase,
                subtitle: purchase.data['totalCost'] != null ? 'RM ${purchase.data['totalCost']}' : null,
              ),
        ],
      ),
    );
  }
}
