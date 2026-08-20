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
import 'ppe_item_catalog.dart';

class _SelectedItem {
  bool selected = false;
  String size = '';
  String quantity = '1';
}

class PpeRequestFormScreen extends ConsumerStatefulWidget {
  const PpeRequestFormScreen({super.key});

  @override
  ConsumerState<PpeRequestFormScreen> createState() => _PpeRequestFormScreenState();
}

class _PpeRequestFormScreenState extends ConsumerState<PpeRequestFormScreen> {
  String _category = 'ppe'; // ppe | uniform | office
  String _requestType = 'issue'; // issue | buy
  final _search = TextEditingController();
  final Map<String, _SelectedItem> _selections = {};
  final _remarksController = TextEditingController();
  PlatformFile? _invoiceFile;
  bool _isSubmitting = false;

  List<CatalogItem> get _catalog {
    switch (_category) {
      case 'uniform':
        return uniformItems;
      case 'office':
        return officeItems;
      default:
        return ppeItems;
    }
  }

  _SelectedItem _stateFor(String name) => _selections.putIfAbsent(name, () => _SelectedItem());

  double get _totalCost {
    if (_requestType != 'buy') return 0;
    double total = 0;
    for (final item in _catalog) {
      final sel = _selections[item.name];
      if (sel == null || !sel.selected) continue;
      final price = item.unitPrice(sel.size.isEmpty ? null : sel.size) ?? 0;
      total += price * (int.tryParse(sel.quantity) ?? 0);
    }
    return total;
  }

  Future<void> _pickInvoice() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _invoiceFile = result.files.first);
    }
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final selectedEntries = _catalog.where((item) => _selections[item.name]?.selected == true).toList();
    if (selectedEntries.isEmpty) {
      _showError('Please select at least one item to request.');
      return;
    }
    for (final item in selectedEntries) {
      final sel = _selections[item.name]!;
      final qty = int.tryParse(sel.quantity);
      if (qty == null || qty < 1 || qty > 999) {
        _showError('Quantity must be a whole number between 1 and 999 for every selected item.');
        return;
      }
      if (item.sizes.length > 1 && sel.size.isEmpty) {
        _showError('Please choose a size or option for every selected item.');
        return;
      }
    }

    String? invoiceUrl;
    String? invoicePath;
    if (_requestType == 'buy') {
      if (_invoiceFile == null) {
        _showError('Please upload an invoice for purchase requests.');
        return;
      }
      setState(() => _isSubmitting = true);
      try {
        final path = 'ppe-purchase/${user.id}/${DateTime.now().millisecondsSinceEpoch}_${_invoiceFile!.name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}';
        if (_invoiceFile!.bytes != null) {
          await supabase.storage.from('form-attachments').uploadBinary(path, _invoiceFile!.bytes!);
        } else if (_invoiceFile!.path != null) {
          await supabase.storage.from('form-attachments').upload(path, File(_invoiceFile!.path!));
        }
        invoiceUrl = supabase.storage.from('form-attachments').getPublicUrl(path);
        invoicePath = path;
      } catch (e) {
        setState(() => _isSubmitting = false);
        _showError('Upload failed: $e');
        return;
      }
    } else {
      setState(() => _isSubmitting = true);
    }

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: _requestType == 'buy' ? 'ppe_purchase' : 'ppe_request',
      status: 'approved',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'employeeInfo': {
          'name': user.name,
          'staffNo': user.employeeId,
          'department': user.department,
          'position': user.position,
          'avatar': user.avatar,
          'phone': user.phone,
        },
        'requestCategory': _category,
        'requestType': _requestType,
        'items': selectedEntries
            .map((item) => {'Item Name': item.name, 'Size': _selections[item.name]!.size, 'Quantity': _selections[item.name]!.quantity})
            .toList(),
        if (_requestType == 'buy') 'totalCost': _totalCost,
        'remarks': _remarksController.text.trim(),
        if (invoiceUrl != null) 'invoiceUrl': invoiceUrl,
        if (invoicePath != null) 'invoicePath': invoicePath,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Collection record saved successfully!');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _catalog.where((i) => i.name.toLowerCase().contains(_search.text.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('PPE | Uniform | Office Supplies')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.inventory_2_outlined,
            title: 'Request Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _toggleButton('Issue', _requestType == 'issue', () => setState(() {
                            _requestType = 'issue';
                            if (_category == 'office' && _requestType != 'issue') _category = 'ppe';
                          })),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _toggleButton('Buy', _requestType == 'buy', () => setState(() {
                            _requestType = 'buy';
                            if (_category == 'office') _category = 'ppe';
                          })),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    _categoryChip('ppe', 'PPE'),
                    _categoryChip('uniform', 'Uniform'),
                    if (_requestType == 'issue') _categoryChip('office', 'Office Supply'),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search items...', isDense: true),
                ),
                const SizedBox(height: 10),
                for (final item in visibleItems) _itemRow(item),
                const SizedBox(height: 10),
                const Text('Remarks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(controller: _remarksController, decoration: const InputDecoration(hintText: 'Please enter remarks if any...')),
                if (_requestType == 'buy') ...[
                  const SizedBox(height: 14),
                  const Text('Upload Invoice / Receipt *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  _invoiceFile != null
                      ? Row(
                          children: [
                            Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_invoiceFile!.name, overflow: TextOverflow.ellipsis)),
                            IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _invoiceFile = null)),
                          ],
                        )
                      : OutlinedButton.icon(onPressed: _pickInvoice, icon: const Icon(Icons.upload_outlined), label: const Text('Upload Invoice')),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('Total Estimated Cost: RM ${_totalCost.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox() : const Icon(Icons.send, size: 16),
            label: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Record'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: TextStyle(color: selected ? AppColors.onPrimary : AppColors.mutedForeground, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _categoryChip(String value, String label) {
    final selected = _category == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _category = value),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? AppColors.onPrimary : AppColors.foreground, fontWeight: FontWeight.w600, fontSize: 12),
      backgroundColor: AppColors.card,
      side: BorderSide(color: AppColors.border),
    );
  }

  Widget _itemRow(CatalogItem item) {
    final sel = _stateFor(item.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: sel.selected ? AppColors.primary.withValues(alpha: 0.05) : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel.selected ? AppColors.primary : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: sel.selected,
                onChanged: (v) => setState(() {
                  sel.selected = v ?? false;
                  if (sel.selected && item.sizes.length == 1) sel.size = item.sizes.first.size;
                }),
              ),
              Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              Text(item.unit, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
            ],
          ),
          if (sel.selected)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 8, right: 4),
              child: Row(
                children: [
                  if (item.sizes.length > 1)
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: AppColors.card,
                        icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                        initialValue: sel.size.isEmpty ? null : sel.size,
                        isDense: true,
                        decoration: const InputDecoration(isDense: true, labelText: 'Size'),
                        items: item.sizes.map((s) => DropdownMenuItem(value: s.size, child: Text(s.size))).toList(),
                        onChanged: (v) => setState(() => sel.size = v ?? ''),
                      ),
                    ),
                  if (item.sizes.length > 1) const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextFormField(
                      initialValue: sel.quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(isDense: true, labelText: 'Qty'),
                      onChanged: (v) => setState(() => sel.quantity = v),
                    ),
                  ),
                  if (_requestType == 'buy') ...[
                    const SizedBox(width: 10),
                    Text(
                      item.unitPrice(sel.size.isEmpty ? null : sel.size) == null
                          ? 'Select size'
                          : 'RM ${(item.unitPrice(sel.size.isEmpty ? null : sel.size)! * (int.tryParse(sel.quantity) ?? 0)).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
