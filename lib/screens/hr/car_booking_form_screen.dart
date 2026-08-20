import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/car_info.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cars_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/modern_time_picker.dart';
import '../../providers/users_provider.dart';
import '../../widgets/approver_dropdown.dart';
import '../../widgets/form_section_card.dart';

class _Passenger {
  String name = '';
  String staffId = '';
  String position = '';
  String department = '';
}

class CarBookingFormScreen extends ConsumerStatefulWidget {
  const CarBookingFormScreen({super.key});

  @override
  ConsumerState<CarBookingFormScreen> createState() => _CarBookingFormScreenState();
}

class _CarBookingFormScreenState extends ConsumerState<CarBookingFormScreen> {
  String _journeyType = 'business';
  DateTime? _fromDate;
  DateTime? _toDate;
  final _destinationController = TextEditingController();
  final _purposeController = TextEditingController();
  PlatformFile? _licenseFile;
  final List<_Passenger> _passengers = [_Passenger(), _Passenger()];
  String? _hos;
  String? _hod;
  bool _policyAgreed = false;
  bool _isSubmitting = false;

  final _dateFmt = DateFormat('d MMM yyyy, h:mm a');

  @override
  void dispose() {
    _destinationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 1)), lastDate: DateTime(now.year + 2));
    if (date == null || !mounted) return;
    final time = await showModernTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isFrom) {
        _fromDate = combined;
      } else {
        _toDate = combined;
      }
    });
  }

  Future<void> _pickLicenseFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _licenseFile = result.files.first);
    }
  }

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (!_policyAgreed) {
      _showError('Please agree to the Company Vehicle Policy before submitting.');
      return;
    }
    if (_hos == null || _hod == null) {
      _showError('Please select both Head of Section and Head of Department.');
      return;
    }
    if (_fromDate == null || _toDate == null) {
      _showError('Please select both From and To date & time.');
      return;
    }
    if (_purposeController.text.trim().isEmpty || _destinationController.text.trim().isEmpty) {
      _showError('Please fill in the purpose and destination of your journey.');
      return;
    }
    if (_licenseFile == null) {
      _showError('Please upload a copy of your driving license.');
      return;
    }

    setState(() => _isSubmitting = true);

    String? licenseUrl;
    try {
      final path = 'public/${user.id}/license_${DateTime.now().millisecondsSinceEpoch}_${_licenseFile!.name.replaceAll(RegExp(r'[^a-zA-Z0-9.-]'), '_')}';
      if (_licenseFile!.bytes != null) {
        await supabase.storage.from('form-attachments').uploadBinary(path, _licenseFile!.bytes!);
      } else if (_licenseFile!.path != null) {
        await supabase.storage.from('form-attachments').upload(path, File(_licenseFile!.path!));
      }
      licenseUrl = supabase.storage.from('form-attachments').getPublicUrl(path);
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('License upload failed: $e');
      return;
    }

    final initialStatus = _hos == 'N/A' ? 'approved_hos' : 'pending';

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'car_rental',
      status: initialStatus,
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'journeyType': _journeyType,
        'fromDate': _fromDate!.toIso8601String(),
        'toDate': _toDate!.toIso8601String(),
        'destination': _destinationController.text.trim(),
        'purpose': _purposeController.text.trim(),
        'name': user.name,
        'staffId': user.employeeId,
        'icNo': user.icNo,
        'avatar': user.avatar,
        'department': user.department,
        'position': user.position,
        'mobileNumber': user.phone,
        'drivingLicenseNo': user.drivingLicenseNo,
        'hosName': _hos,
        'hodName': _hod,
        'licenseAttachment': licenseUrl,
        'passengers': _passengers
            .where((p) => p.name.isNotEmpty)
            .map((p) => {'name': p.name, 'staffId': p.staffId, 'position': p.position, 'department': p.department})
            .toList(),
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Company car request submitted successfully!');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  void _showError(String message) {
    showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final usersState = ref.watch(usersProvider);
    final hosUsers = usersState.byRole('hos');
    final hodUsers = usersState.byRole('hod');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Company Car Request')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.person_outline,
            title: 'Requester & Driver Details',
            child: PrefilledDetailsBox(rows: {
              'Name': user?.name ?? '',
              'Position': user?.position ?? '',
              'Staff ID': user?.employeeId ?? '',
              'Department': user?.department ?? '',
              'IC Number': user?.icNo ?? '',
              'Driving Licence': user?.drivingLicenseNo ?? '',
            }),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.map_outlined,
            title: 'Journey Details',
            trailing: TextButton.icon(
              onPressed: () => showVehicleAvailabilitySheet(context, ref),
              icon: const Icon(Icons.calendar_month_outlined, size: 16),
              label: const Text('Availability', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _journeyTypeOption('business', 'Business', 'Official company travel')),
                    const SizedBox(width: 10),
                    Expanded(child: _journeyTypeOption('other', 'Other', 'Non-business journey')),
                  ],
                ),
                const SizedBox(height: 14),
                _dateField('From Date & Time', _fromDate, () => _pickDate(isFrom: true)),
                const SizedBox(height: 12),
                _dateField('To Date & Time', _toDate, () => _pickDate(isFrom: false)),
                const SizedBox(height: 12),
                _label('Purpose of Journey *'),
                TextField(controller: _purposeController, decoration: const InputDecoration(hintText: 'State the reason for your request...')),
                const SizedBox(height: 12),
                _label('Destination *'),
                TextField(controller: _destinationController, decoration: const InputDecoration(hintText: 'e.g., Kuala Lumpur, Selangor')),
                const SizedBox(height: 12),
                _label('Upload Driving Licence *'),
                _licenseFile != null
                    ? Row(
                        children: [
                          Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_licenseFile!.name, overflow: TextOverflow.ellipsis)),
                          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _licenseFile = null)),
                        ],
                      )
                    : OutlinedButton.icon(onPressed: _pickLicenseFile, icon: const Icon(Icons.upload_outlined), label: const Text('Upload Licence (PDF/JPG/PNG)')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.groups_outlined,
            title: 'Passenger Details',
            trailing: IconButton(icon: Icon(Icons.add_circle_outline, color: AppColors.primary), onPressed: () => setState(() => _passengers.add(_Passenger()))),
            child: Column(
              children: [
                for (int i = 0; i < _passengers.length; i++) _passengerCard(i),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '04',
            icon: Icons.shield_outlined,
            title: 'Digital Approvals',
            child: Column(
              children: [
                ApproverDropdown(label: 'Head of Section', options: hosUsers, value: _hos, isLoading: usersState.isLoading, includeNotApplicable: true, onChanged: (v) => setState(() => _hos = v)),
                const SizedBox(height: 12),
                ApproverDropdown(label: 'Head of Department', options: hodUsers, value: _hod, isLoading: usersState.isLoading, onChanged: (v) => setState(() => _hod = v)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '05',
            icon: Icons.description_outlined,
            title: 'Company Vehicles Policy',
            child: CheckboxListTile(
              value: _policyAgreed,
              onChanged: (v) => setState(() => _policyAgreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I have read and understood the company vehicle, service and repair policies and agree to follow all applicable rules and procedures, including responsibility for fines and penalties.',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting ? const SizedBox() : const Icon(Icons.send, size: 16),
            label: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Request'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _journeyTypeOption(String value, String title, String subtitle) {
    final selected = _journeyType == value;
    return InkWell(
      onTap: () => setState(() => _journeyType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
          color: selected ? AppColors.primary.withValues(alpha: 0.05) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('$label *'),
        InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
            child: Text(value == null ? 'Select date & time' : _dateFmt.format(value)),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );

  Widget _passengerCard(int i) {
    final p = _passengers[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Passenger ${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.mutedForeground))),
              if (i > 1)
                InkWell(
                  onTap: () => setState(() => _passengers.removeAt(i)),
                  child: Icon(Icons.remove_circle_outline, size: 18, color: AppColors.destructive),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: p.name,
            decoration: const InputDecoration(labelText: 'Name', isDense: true),
            onChanged: (v) => p.name = v,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: p.staffId,
                  decoration: const InputDecoration(labelText: 'Staff ID', isDense: true),
                  onChanged: (v) => p.staffId = v,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: p.position,
                  decoration: const InputDecoration(labelText: 'Position', isDense: true),
                  onChanged: (v) => p.position = v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: p.department,
            decoration: const InputDecoration(labelText: 'Department', isDense: true),
            onChanged: (v) => p.department = v,
          ),
        ],
      ),
    );
  }
}

class _ActiveBooking {
  final String employeeName;
  final DateTime fromDate;
  final DateTime toDate;
  final String? destination;
  final CarInfo? car;
  const _ActiveBooking({required this.employeeName, required this.fromDate, required this.toDate, this.destination, this.car});
}

List<_ActiveBooking> _computeActiveBookings(List<Submission> submissions, List<CarInfo> cars) {
  final now = DateTime.now();
  final bookings = <_ActiveBooking>[];

  for (final s in submissions) {
    if (s.formType != 'car_rental' || s.status != 'approved') continue;
    final fromDate = DateTime.tryParse(s.data['fromDate']?.toString() ?? '');
    final toDate = DateTime.tryParse(s.data['toDate']?.toString() ?? '');
    if (fromDate == null || toDate == null) continue;
    if (toDate.isBefore(now.subtract(const Duration(hours: 24)))) continue;

    CarInfo? assignedCar;
    for (final c in cars) {
      if (c.status != 'checked_out' || c.lastCheckedOutBy != s.employeeName) continue;
      final windowStart = fromDate.subtract(const Duration(hours: 24));
      final windowEnd = toDate.add(const Duration(hours: 24));
      if (!now.isBefore(windowStart) && !now.isAfter(windowEnd)) {
        assignedCar = c;
        break;
      }
    }

    bookings.add(_ActiveBooking(employeeName: s.employeeName, fromDate: fromDate, toDate: toDate, destination: s.data['destination']?.toString(), car: assignedCar));
  }

  bookings.sort((a, b) => a.fromDate.compareTo(b.fromDate));
  return bookings;
}

/// Opens the "Current Vehicle Availability" sheet — mirrors the modal in
/// CarBookingForm.tsx: every fleet vehicle with its status and, if it's
/// currently out, who booked it and until when.
void showVehicleAvailabilitySheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => const _VehicleAvailabilitySheet(),
  );
}

class _VehicleAvailabilitySheet extends ConsumerWidget {
  const _VehicleAvailabilitySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cars = ref.watch(carsProvider).cars;
    final submissions = ref.watch(submissionsProvider).submissions;
    final bookings = _computeActiveBookings(submissions, cars);
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Current Vehicle Availability', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('See which company vehicles are currently available or in use.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 16),
            Expanded(
              child: cars.isEmpty
                  ? Center(child: Text('No company vehicles found.', style: TextStyle(color: AppColors.mutedForeground)))
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: cars.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final car = cars[i];
                        final booking = bookings.where((b) => b.car?.id == car.id).toList();
                        return _vehicleTile(car, booking.isEmpty ? null : booking.first, dateFmt);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehicleTile(CarInfo car, _ActiveBooking? booking, DateFormat dateFmt) {
    final isAvailable = car.status == 'available';
    final isMaintenance = car.status == 'maintenance';
    final statusColor = isAvailable ? AppColors.success : (isMaintenance ? AppColors.mutedForeground : AppColors.gold);
    final statusLabel = isAvailable ? 'AVAILABLE' : (isMaintenance ? 'MAINTENANCE' : 'IN USE');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: car.imageUrl != null && car.imageUrl!.isNotEmpty
                ? Image.network(car.imageUrl!, width: 56, height: 56, fit: BoxFit.cover)
                : Container(width: 56, height: 56, color: AppColors.card, child: Icon(Icons.directions_car_outlined, color: AppColors.mutedForeground)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(car.model, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Text(car.plateNumber, style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground)),
                const SizedBox(height: 6),
                if (booking != null) ...[
                  Text('Booked by ${booking.employeeName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${dateFmt.format(booking.fromDate)} → ${dateFmt.format(booking.toDate)}', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                ] else
                  Text(
                    isAvailable ? 'No active booking' : (isMaintenance ? 'Vehicle is unavailable for booking' : 'Booking details unavailable'),
                    style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
