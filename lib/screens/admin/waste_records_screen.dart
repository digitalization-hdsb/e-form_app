import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/safety_record_tile.dart';

/// Mirrors pages/WasteRecordsPage.tsx — read-only search/browse of every
/// waste_inventory submission (no edit/delete/status actions here).
class WasteRecordsScreen extends ConsumerStatefulWidget {
  const WasteRecordsScreen({super.key});

  @override
  ConsumerState<WasteRecordsScreen> createState() => _WasteRecordsScreenState();
}

class _WasteRecordsScreenState extends ConsumerState<WasteRecordsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Submission s, String query) {
    if (query.isEmpty) return true;
    final haystacks = [
      s.employeeName,
      s.data['wasteType']?.toString() ?? '',
      s.data['plant']?.toString() ?? '',
      s.data['category']?.toString() ?? '',
      s.refNo ?? '',
    ].join(' ').toLowerCase();
    return haystacks.contains(query.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final records = state.submissions.where((s) => s.formType == 'waste_inventory' && _matches(s, _searchController.text)).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search waste type, plant, employee, or ref no...', isDense: true),
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No matching records.', style: TextStyle(color: AppColors.mutedForeground))))
          else
            for (final record in records)
              SafetyRecordTile(submission: record, subtitle: record.data['wasteType']?.toString()),
        ],
      ),
    );
  }
}
