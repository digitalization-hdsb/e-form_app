import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/modern_time_picker.dart';

const defaultSellWasteTypes = [
  'SW104 ALUMINIUM DROSS',
  'SW104 ALUMINIUM SLUDGE',
  'SW422 OILY SCRAP',
  'SW422 ALUMINIUM CHIP COOLANT',
  'SW409 DISPOSAL CHEMICAL CONTAINER',
  'SW305 SPENT LUBRICANTING OIL',
  'SW306 SPENT HYDRAULIC OIL',
];
const defaultPayWasteTypes = [
  'SW410 CONTAMINATED COTTON RAG/GLOVE',
  'SW204 SLUDGE CAKE',
  'SW307 SPENT MINERAL OIL WITH WATER EMULSION',
  'SW327 WASTE OF WATER GLYCOL',
];

class _WasteRow {
  final int id;
  final _grossController = TextEditingController();
  final _containerController = TextEditingController();
  PlatformFile? photo;
  _WasteRow(this.id);

  double get gross => double.tryParse(_grossController.text) ?? 0;
  double get container => double.tryParse(_containerController.text) ?? 0;
  double get net => (gross - container) < 0 ? 0 : double.parse((gross - container).toStringAsFixed(2));
}

class WasteInventoryFormScreen extends ConsumerStatefulWidget {
  const WasteInventoryFormScreen({super.key});

  @override
  ConsumerState<WasteInventoryFormScreen> createState() => _WasteInventoryFormScreenState();
}

class _WasteInventoryFormScreenState extends ConsumerState<WasteInventoryFormScreen> {
  String _plant = 'Plant 1';
  String _category = 'sell';
  DateTime _recordDate = DateTime.now();
  TimeOfDay _recordTime = TimeOfDay.now();
  List<String> _sellWasteTypes = defaultSellWasteTypes;
  List<String> _payWasteTypes = defaultPayWasteTypes;
  String? _wasteType;
  int _nextRowId = 3;
  late List<_WasteRow> _rows;
  bool _isSubmitting = false;

  List<String> get _wasteTypeOptions => _category == 'sell' ? _sellWasteTypes : _payWasteTypes;

  @override
  void initState() {
    super.initState();
    _rows = [_WasteRow(0), _WasteRow(1), _WasteRow(2)];
    _wasteType = _sellWasteTypes.first;
    _loadWasteTypes();
  }

  Future<void> _loadWasteTypes() async {
    try {
      final row = await supabase.from('safety_dashboard_settings').select('value').eq('key', 'waste_types').maybeSingle();
      final value = row?['value'] as Map?;
      if (value != null) {
        setState(() {
          _sellWasteTypes = (value['sell'] as List?)?.cast<String>() ?? defaultSellWasteTypes;
          _payWasteTypes = (value['pay'] as List?)?.cast<String>() ?? defaultPayWasteTypes;
          _wasteType = _wasteTypeOptions.first;
        });
      }
    } catch (_) {
      // Keep defaults.
    }
  }

  void _addRow() => setState(() => _rows.add(_WasteRow(_nextRowId++)));
  void _removeRow(_WasteRow row) {
    if (_rows.length <= 1) return;
    setState(() => _rows.remove(row));
  }

  Future<void> _pickPhoto(_WasteRow row) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) setState(() => row.photo = result.files.first);
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  double get _totalGross => _rows.fold(0, (sum, r) => sum + r.gross);
  double get _totalContainer => _rows.fold(0, (sum, r) => sum + r.container);
  double get _totalNet => _rows.fold(0, (sum, r) => sum + r.net);

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_wasteType == null) return _showError('Select a waste type.');
    if (_rows.every((r) => r.gross == 0 && r.container == 0)) return _showError('Enter at least one weigh-in row.');

    setState(() => _isSubmitting = true);
    final rowsData = <Map<String, dynamic>>[];
    try {
      for (final row in _rows) {
        String? imageUrl;
        String? imageName;
        if (row.photo != null) {
          final path = 'waste-inventory/${user.id}/${row.id}/${DateTime.now().millisecondsSinceEpoch}_${row.photo!.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
          if (row.photo!.bytes != null) {
            await supabase.storage.from('form-attachments').uploadBinary(path, row.photo!.bytes!);
          } else if (row.photo!.path != null) {
            await supabase.storage.from('form-attachments').upload(path, File(row.photo!.path!));
          }
          imageUrl = supabase.storage.from('form-attachments').getPublicUrl(path);
          imageName = row.photo!.name;
        }
        rowsData.add({
          'id': row.id,
          'gross': row._grossController.text.trim(),
          'container': row._containerController.text.trim(),
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (imageName != null) 'imageName': imageName,
        });
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Photo upload failed: $e');
      return;
    }

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'waste_inventory',
      status: 'approved',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'plant': _plant,
        'category': _category,
        'wasteType': _wasteType,
        'rows': rowsData,
        'totals': {'gross': _totalGross.toStringAsFixed(2), 'container': _totalContainer.toStringAsFixed(2), 'net': _totalNet.toStringAsFixed(2)},
        'recordDate': DateFormat('yyyy-MM-dd').format(_recordDate),
        'recordTime': '${_recordTime.hour.toString().padLeft(2, '0')}:${_recordTime.minute.toString().padLeft(2, '0')}',
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Waste inventory record saved.');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Waste Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.settings_outlined,
            title: 'Configuration',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plant *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _choiceButton('Plant 1', _plant == 'Plant 1', () => setState(() => _plant = 'Plant 1'))),
                    const SizedBox(width: 10),
                    Expanded(child: _choiceButton('Plant 2', _plant == 'Plant 2', () => setState(() => _plant = 'Plant 2'))),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Category *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _choiceButton('Recycle (Sell)', _category == 'sell', () => setState(() { _category = 'sell'; _wasteType = _sellWasteTypes.first; }))),
                    const SizedBox(width: 10),
                    Expanded(child: _choiceButton('Dispose (Pay)', _category == 'pay', () => setState(() { _category = 'pay'; _wasteType = _payWasteTypes.first; }))),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Waste Type *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(14),
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                  initialValue: _wasteTypeOptions.contains(_wasteType) ? _wasteType : null,
                  isExpanded: true,
                  items: _wasteTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _wasteType = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _pickerField('Date', DateFormat('d MMM yyyy').format(_recordDate), () async {
                        final picked = await showDatePicker(context: context, initialDate: _recordDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                        if (picked != null) setState(() => _recordDate = picked);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField('Time', _recordTime.format(context), () async {
                        final picked = await showModernTimePicker(context: context, initialTime: _recordTime, title: 'Time');
                        if (picked != null) setState(() => _recordTime = picked);
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.scale_outlined,
            title: 'Weigh-in Rows',
            trailing: IconButton(icon: Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: _addRow),
            child: Column(
              children: [
                for (final row in _rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: row._grossController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, labelText: 'Gross (kg)'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: row._containerController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(isDense: true, labelText: 'Container (kg)'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            IconButton(icon: Icon(Icons.camera_alt_outlined, size: 20, color: AppColors.primary), onPressed: () => _pickPhoto(row)),
                            if (_rows.length > 1) IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _removeRow(row)),
                          ],
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Net: ${row.net.toStringAsFixed(2)} kg${row.photo != null ? ' · photo attached' : ''}', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Total Net: ${_totalNet.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Save Record'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _pickerField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        InkWell(onTap: onTap, child: InputDecorator(decoration: const InputDecoration(isDense: true), child: Text(value))),
      ],
    );
  }

  Widget _choiceButton(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.background, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: TextStyle(color: selected ? AppColors.onPrimary : AppColors.mutedForeground, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }
}
