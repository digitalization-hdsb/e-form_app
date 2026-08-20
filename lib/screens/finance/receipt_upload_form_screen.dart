import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/form_section_card.dart';

/// Mirrors buildReceiptRefNoMap in src/pages/ReceiptUploadForm.tsx: builds
/// a ref-no -> submission-id lookup for claims, falling back to the
/// synthetic HDSB-#### numbering when a claim predates ref-no storage.
Map<String, String> _buildReceiptRefNoMap(List claims) {
  final sorted = [...claims]..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
  final map = <String, String>{};
  for (var i = 0; i < sorted.length; i++) {
    final s = sorted[i];
    final stored = s.refNo?.toString().trim().toUpperCase();
    if (stored != null && stored.isNotEmpty) {
      map[stored] = s.id;
    } else {
      map['HDSB-${(i + 1).toString().padLeft(4, '0')}'] = s.id;
    }
  }
  return map;
}

class ReceiptUploadFormScreen extends ConsumerStatefulWidget {
  const ReceiptUploadFormScreen({super.key});

  @override
  ConsumerState<ReceiptUploadFormScreen> createState() => _ReceiptUploadFormScreenState();
}

class _ReceiptUploadFormScreenState extends ConsumerState<ReceiptUploadFormScreen> {
  final _refNoController = TextEditingController();
  final List<PlatformFile> _files = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _refNoController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'], allowMultiple: true);
    if (result != null) setState(() => _files.addAll(result.files));
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_refNoController.text.trim().isEmpty) {
      _showError('Please enter the submission reference number.');
      return;
    }
    if (_files.isEmpty) {
      _showError('Please attach at least one receipt file.');
      return;
    }

    final claims = ref.read(submissionsProvider).submissions.where((s) => s.formType == 'claim').toList();
    final refNoMap = _buildReceiptRefNoMap(claims);
    final submissionId = refNoMap[_refNoController.text.trim().toUpperCase()];
    if (submissionId == null) {
      _showError('Invalid reference number. Please check and try again.');
      return;
    }
    final submission = claims.where((s) => s.id == submissionId);
    if (submission.isEmpty) {
      _showError('This reference number does not correspond to a Petty Cash Claim.');
      return;
    }
    final target = submission.first;

    setState(() => _isSubmitting = true);
    try {
      final urls = <String>[];
      for (final file in _files) {
        final path = 'public/${user.id}/receipt_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
        if (file.bytes != null) {
          await supabase.storage.from('form-attachments').uploadBinary(path, file.bytes!);
        } else if (file.path != null) {
          await supabase.storage.from('form-attachments').upload(path, File(file.path!));
        }
        urls.add(supabase.storage.from('form-attachments').getPublicUrl(path));
      }

      final existing = (target.data['attachments'] as List?)?.cast<dynamic>() ?? [];
      final result = await ref.read(submissionsProvider.notifier).updateSubmission(
        target.id,
        dataToMerge: {'attachments': [...existing, ...urls]},
      );

      if (!mounted) return;
      if (result.success) {
        showSuccessSnackBar(context, 'Receipt uploaded and attached successfully!');
        context.go('/home');
      } else {
        _showError(result.error ?? 'Upload failed.');
      }
    } catch (e) {
      _showError('An error occurred during upload: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Upload Petty Cash Receipt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.receipt_long_outlined,
            title: 'Claim Reference',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Submission Reference Number *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: _refNoController, decoration: const InputDecoration(hintText: 'e.g. HDSB-0001')),
                const SizedBox(height: 6),
                Text('Enter the reference number from your original Petty Cash Claim submission.', style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.upload_file_outlined,
            title: 'Receipt Files',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final file in _files)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(file.name, overflow: TextOverflow.ellipsis)),
                        IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _files.remove(file))),
                      ],
                    ),
                  ),
                OutlinedButton.icon(onPressed: _pickFiles, icon: const Icon(Icons.upload_outlined), label: const Text('Upload Receipt(s)')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox() : const Icon(Icons.send, size: 16),
            label: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Receipt'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
