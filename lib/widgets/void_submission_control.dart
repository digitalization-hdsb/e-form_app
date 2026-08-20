import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/submissions_provider.dart';

/// Mirrors components/VoidSubmissionControl.tsx: only shown for
/// non-terminal submissions, requires a reason of 5+ characters, calls the
/// same `void_submission` RPC as the website. The website places this as a
/// compact "icon" button in the detail header next to the back button —
/// [compact] mirrors that, for use in a detail sheet's title row instead of
/// buried mid-scroll.
class VoidSubmissionControl extends ConsumerWidget {
  final String submissionId;
  final String status;
  final VoidCallback? onVoided;
  final bool compact;

  const VoidSubmissionControl({super.key, required this.submissionId, required this.status, this.onVoided, this.compact = false});

  bool get _hidden => ['completed', 'rejected', 'voided'].contains(status);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_hidden) return const SizedBox();

    if (compact) {
      return TextButton.icon(
        onPressed: () => _showDialog(context, ref),
        icon: Icon(Icons.block, size: 15, color: AppColors.destructive),
        label: Text('Void', style: TextStyle(color: AppColors.destructive, fontSize: 12, fontWeight: FontWeight.bold)),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _showDialog(context, ref),
        icon: Icon(Icons.block, size: 16, color: AppColors.destructive),
        label: Text('Void Submission', style: TextStyle(color: AppColors.destructive, fontSize: 12.5)),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Void this submission?'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason', hintText: 'Explain why this submission is being voided...'),
            validator: (v) => (v == null || v.trim().length < 5) ? 'Please provide a reason of at least 5 characters.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive, foregroundColor: Colors.white),
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final result = await ref.read(submissionsProvider.notifier).voidSubmission(submissionId, controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.success ? 'Submission voided.' : (result.error ?? 'Failed to void submission.'))),
                );
                if (result.success) onVoided?.call();
              }
            },
            child: const Text('Void'),
          ),
        ],
      ),
    );
  }
}
