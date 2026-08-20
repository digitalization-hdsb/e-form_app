import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/modern_time_picker.dart';

/// Mirrors WaterTreatmentForm.tsx (internally DailyOperationMonitoringForm)
/// — one component reused for both Mixing & Chemical and Final Discharge.
/// Both submit with status "approved" directly; there is no HOS/HOD chain
/// for Safety forms.
class DailyOperationMonitoringFormScreen extends ConsumerStatefulWidget {
  final String variant; // mixing | discharge

  const DailyOperationMonitoringFormScreen({super.key, required this.variant});

  @override
  ConsumerState<DailyOperationMonitoringFormScreen> createState() => _DailyOperationMonitoringFormScreenState();
}

class _DailyOperationMonitoringFormScreenState extends ConsumerState<DailyOperationMonitoringFormScreen> {
  bool get _isMixing => widget.variant == 'mixing';

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _shift;

  // Mixing fields
  String? _tankVolume;
  final _causticLitres = TextEditingController();
  final _causticPh = TextEditingController();
  final _coagulationLitres = TextEditingController();
  final _coagulationPh = TextEditingController();
  final _flocculationLitres = TextEditingController();
  final _flocculationPh = TextEditingController();

  // Discharge fields
  final Map<String, TextEditingController> _dischargeControllers = {
    for (final key in ['ph4', 'cod', 'bod', 'tss', 'og', 'flowrate', 'mg', 'nickel', 'zink', 'iron', 'aluminum', 'fluoride', 'silver', 'sulphide', 'rawEq']) key: TextEditingController(),
  };
  static const _dischargeLabels = {
    'ph4': 'pH',
    'cod': 'COD (mg/L)',
    'bod': 'BOD (mg/L)',
    'tss': 'TSS (mg/L)',
    'og': 'Oil & Grease (mg/L)',
    'flowrate': 'Flowrate (m³/day)',
    'mg': 'Magnesium (mg/L)',
    'nickel': 'Nickel (mg/L)',
    'zink': 'Zinc (mg/L)',
    'iron': 'Iron (mg/L)',
    'aluminum': 'Aluminium (mg/L)',
    'fluoride': 'Fluoride (mg/L)',
    'silver': 'Silver (mg/L)',
    'sulphide': 'Sulphide (mg/L)',
    'rawEq': 'Raw EQ',
  };

  final _remarksController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _causticLitres.dispose();
    _causticPh.dispose();
    _coagulationLitres.dispose();
    _coagulationPh.dispose();
    _flocculationLitres.dispose();
    _flocculationPh.dispose();
    for (final c in _dischargeControllers.values) {
      c.dispose();
    }
    _remarksController.dispose();
    super.dispose();
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  String _nextBatchNo() {
    final count = ref.read(submissionsProvider).submissions.where((s) => s.formType == 'mixing_chemical_stages').length;
    return 'BCH-${(count + 1).toString().padLeft(4, '0')}';
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    if (_shift == null) return _showError('Select the shift.');
    if (_isMixing && _tankVolume == null) return _showError('Select the mixing tank volume.');

    setState(() => _isSubmitting = true);
    final metaInfo = {
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
      'shift': _shift,
    };
    final employeeInfo = {'name': user.name, 'staffNo': user.employeeId, 'department': user.department, 'position': user.position};

    final data = <String, dynamic>{
      'employeeInfo': employeeInfo,
      'metaInfo': metaInfo,
      'remarks': _remarksController.text.trim(),
    };

    if (_isMixing) {
      data['processInfo'] = {
        'mixingTankBatchNo': _nextBatchNo(),
        'mixingTankVolume': _tankVolume,
        'causticSodaLitres': _causticLitres.text.trim(),
        'causticSodaPH1': _causticPh.text.trim(),
        'coagulationLitres': _coagulationLitres.text.trim(),
        'coagulationPH2': _coagulationPh.text.trim(),
        'flocculationLitres': _flocculationLitres.text.trim(),
        'flocculationPH3': _flocculationPh.text.trim(),
      };
    } else {
      data['finalDischarge'] = {for (final entry in _dischargeControllers.entries) entry.key: entry.value.text.trim()};
    }

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: _isMixing ? 'mixing_chemical_stages' : 'final_discharge',
      status: 'approved',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: data,
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, '${_isMixing ? 'Mixing & Chemical' : 'Final Discharge'} record saved.');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isMixing ? 'Mixing & Chemical' : 'Final Discharge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.event_note_outlined,
            title: 'Record Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _pickerField('Date', DateFormat('d MMM yyyy').format(_date), () async {
                        final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                        if (picked != null) setState(() => _date = picked);
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pickerField('Time', _time.format(context), () async {
                        final picked = await showModernTimePicker(context: context, initialTime: _time, title: 'Time');
                        if (picked != null) setState(() => _time = picked);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Shift *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _choiceButton('Day', _shift == 'Day', () => setState(() => _shift = 'Day'))),
                    const SizedBox(width: 10),
                    Expanded(child: _choiceButton('Night', _shift == 'Night', () => setState(() => _shift = 'Night'))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_isMixing)
            FormSectionCard(
              number: '02',
              icon: Icons.science_outlined,
              title: 'Process Info',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mixing Tank Volume (L) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: _choiceButton('1500', _tankVolume == '1500', () => setState(() => _tankVolume = '1500'))),
                      const SizedBox(width: 10),
                      Expanded(child: _choiceButton('2000', _tankVolume == '2000', () => setState(() => _tankVolume = '2000'))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _numberField('Caustic Soda (Litres)', _causticLitres),
                  const SizedBox(height: 10),
                  _numberField('Caustic Soda pH', _causticPh),
                  const SizedBox(height: 10),
                  _numberField('Coagulation (Litres)', _coagulationLitres),
                  const SizedBox(height: 10),
                  _numberField('Coagulation pH', _coagulationPh),
                  const SizedBox(height: 10),
                  _numberField('Flocculation (Litres)', _flocculationLitres),
                  const SizedBox(height: 10),
                  _numberField('Flocculation pH', _flocculationPh),
                ],
              ),
            )
          else
            FormSectionCard(
              number: '02',
              icon: Icons.water_drop_outlined,
              title: 'Final Discharge Readings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final key in _dischargeControllers.keys) ...[
                    _numberField(_dischargeLabels[key]!, _dischargeControllers[key]!),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.notes_outlined,
            title: 'Remarks',
            child: TextField(controller: _remarksController, maxLines: 3, decoration: const InputDecoration(hintText: 'Optional remarks...')),
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

  Widget _numberField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
