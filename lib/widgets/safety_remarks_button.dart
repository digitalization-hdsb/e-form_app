import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/supabase_config.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';

/// Mirrors the "Add Remark" / "View Remarks" actions on the Safety admin
/// dashboards — writes to `safety_dashboard_remarks` (dashboard, remark,
/// created_by, created_by_name, created_at), independent of any submission.
class SafetyRemarksButton extends ConsumerWidget {
  final String dashboard; // final_discharge | mixing | waste_inventory

  const SafetyRemarksButton({super.key, required this.dashboard});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showAddRemark(context, ref),
            icon: const Icon(Icons.add_comment_outlined, size: 16),
            label: const Text('Add Remark'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRemarksList(context),
            icon: const Icon(Icons.list_alt_outlined, size: 16),
            label: const Text('View Remarks'),
          ),
        ),
      ],
    );
  }

  void _showAddRemark(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Remark'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Enter a remark...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              final user = ref.read(authProvider).user;
              try {
                await supabase.from('safety_dashboard_remarks').insert({
                  'dashboard': dashboard,
                  'remark': text,
                  'created_by': user?.id,
                  'created_by_name': user?.name,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save remark: $e'), backgroundColor: AppColors.destructive));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemarksList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => FutureBuilder(
          future: supabase.from('safety_dashboard_remarks').select('*').eq('dashboard', dashboard).order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final remarks = snapshot.data as List;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: remarks.isEmpty
                        ? Center(child: Text('No remarks yet.', style: TextStyle(color: AppColors.mutedForeground)))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: remarks.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final r = remarks[index] as Map;
                              final createdAt = DateTime.tryParse(r['created_at']?.toString() ?? '');
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(r['remark']?.toString() ?? ''),
                                subtitle: Text(
                                  '${r['created_by_name'] ?? 'Unknown'}${createdAt != null ? ' · ${DateFormat('d MMM yyyy, h:mm a').format(createdAt)}' : ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
