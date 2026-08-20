import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/car_info.dart';
import '../../providers/cars_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../widgets/form_section_card.dart';
import '../../widgets/skeleton.dart';
import 'vehicle_history_screen.dart';

String _fuelLevelLabel(String value) {
  if (value == 'Empty') return 'Empty (Level 0/7)';
  if (value == 'Full') return 'Full (Level 7/7)';
  return '$value (Level $value)';
}

class _ApprovedBooking {
  final String submissionId;
  final String referenceNumber;
  final String employeeName;
  const _ApprovedBooking({
    required this.submissionId,
    required this.referenceNumber,
    required this.employeeName,
  });
}

/// Mirrors pages/CarManagement.tsx: fleet overview + checkout/check-in
/// flows that keep `cars` and the linked `submissions` row in sync.
class CarManagementScreen extends ConsumerStatefulWidget {
  const CarManagementScreen({super.key});

  @override
  ConsumerState<CarManagementScreen> createState() =>
      _CarManagementScreenState();
}

class _CarManagementScreenState extends ConsumerState<CarManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final carsState = ref.watch(carsProvider);
    if (carsState.isLoading && carsState.cars.isEmpty)
      return const DashboardSkeleton(cards: 3);

    final available = carsState.cars
        .where((c) => c.status == 'available')
        .toList();
    final checkedOut = carsState.cars
        .where((c) => c.status == 'checked_out')
        .toList();
    final maintenance = carsState.cars
        .where((c) => c.status == 'maintenance')
        .toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(carsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _statTile(
                  'Available',
                  available.length,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  'Checked Out',
                  checkedOut.length,
                  AppColors.gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statTile(
                  'Maintenance',
                  maintenance.length,
                  AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showCarFormSheet(context, ref),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Vehicle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const VehicleHistoryScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Usage History'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final car in carsState.cars) _CarTile(car: car),
        ],
      ),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the shared add/edit vehicle sheet — mirrors CarModal in
/// pages/CarManagement.tsx (photo, model, plate, type, and — when editing
/// an existing car — status).
void showCarFormSheet(
  BuildContext context,
  WidgetRef ref, {
  CarInfo? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CarFormSheet(existing: existing),
  );
}

class _CarFormSheet extends ConsumerStatefulWidget {
  final CarInfo? existing;
  const _CarFormSheet({this.existing});

  @override
  ConsumerState<_CarFormSheet> createState() => _CarFormSheetState();
}

class _CarFormSheetState extends ConsumerState<_CarFormSheet> {
  late final _modelController = TextEditingController(
    text: widget.existing?.model ?? '',
  );
  late final _plateController = TextEditingController(
    text: widget.existing?.plateNumber ?? '',
  );
  late String _type = widget.existing?.type ?? carTypeOptions.first;
  late String _status = widget.existing?.status ?? 'available';
  PlatformFile? _photoFile;
  String? _existingImageUrl;
  bool _isSubmitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.existing?.imageUrl;
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty)
      setState(() => _photoFile = result.files.first);
  }

  Future<void> _submit() async {
    final model = _modelController.text.trim();
    final plateNumber = _plateController.text.trim();
    if (model.isEmpty || plateNumber.isEmpty) {
      _showError('Please fill in the model and plate number.');
      return;
    }

    setState(() => _isSubmitting = true);
    var imageUrl = _existingImageUrl;
    try {
      if (_photoFile != null) {
        final path =
            'car-photos/${DateTime.now().millisecondsSinceEpoch}_${_photoFile!.name}';
        if (_photoFile!.bytes != null) {
          await supabase.storage
              .from('form-attachments')
              .uploadBinary(path, _photoFile!.bytes!);
        } else if (_photoFile!.path != null) {
          await supabase.storage
              .from('form-attachments')
              .upload(path, File(_photoFile!.path!));
        }
        imageUrl = supabase.storage.from('form-attachments').getPublicUrl(path);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Photo upload failed: $e');
      return;
    }

    final notifier = ref.read(carsProvider.notifier);
    final result = _isEdit
        ? await notifier.updateCar(
            widget.existing!.id,
            model: model,
            plateNumber: plateNumber,
            type: _type,
            imageUrl: imageUrl,
            status: _status,
          )
        : await notifier.addCar(
            plateNumber: plateNumber,
            model: model,
            type: _type,
          );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(
        context,
        _isEdit ? 'Vehicle updated.' : 'Vehicle added.',
      );
    } else {
      _showError(result.error ?? 'Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockedStatus = widget.existing?.status == 'checked_out';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isEdit ? 'Edit Car' : 'Add New Car',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _isEdit ? 'Update vehicle details' : 'Create a fleet vehicle',
              style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                InkWell(
                  onTap: _pickPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _photoFile != null
                        ? (_photoFile!.bytes != null
                              ? Image.memory(
                                  _photoFile!.bytes!,
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(_photoFile!.path!),
                                  fit: BoxFit.cover,
                                ))
                        : (_existingImageUrl != null &&
                              _existingImageUrl!.isNotEmpty)
                        ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                        : Icon(
                            Icons.directions_car_outlined,
                            color: AppColors.mutedForeground,
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: const Text('Upload Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Car Model *',
                hintText: 'e.g. Proton X50',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plateController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Plate Number *',
                hintText: 'e.g. VCA 1234',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(14),
              dropdownColor: AppColors.card,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.mutedForeground,
              ),
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Car Type'),
              items: carTypeOptions
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                borderRadius: BorderRadius.circular(14),
                dropdownColor: AppColors.card,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.mutedForeground,
                ),
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  const DropdownMenuItem(
                    value: 'available',
                    child: Text('Available'),
                  ),
                  const DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                  if (lockedStatus)
                    const DropdownMenuItem(
                      value: 'checked_out',
                      child: Text('In Use'),
                    ),
                ],
                onChanged: lockedStatus
                    ? null
                    : (v) => setState(() => _status = v ?? _status),
              ),
              if (lockedStatus)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Check this vehicle in first to change its status.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : Text(_isEdit ? 'Save Changes' : 'Add Car'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarTile extends ConsumerWidget {
  final CarInfo car;

  const _CarTile({required this.car});

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
          'Are you sure you want to delete "${car.model} (${car.plateNumber})"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final result = await ref
                  .read(carsProvider.notifier)
                  .deleteCar(car.id);
              if (context.mounted) {
                if (result.success) {
                  showSuccessSnackBar(context, 'Vehicle deleted.');
                } else {
                  showErrorSnackBar(
                    context,
                    result.error ?? 'Failed to delete vehicle.',
                  );
                }
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: AppColors.destructive),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAvailable = car.status == 'available';
    final isMaintenance = car.status == 'maintenance';
    final statusColor = isAvailable
        ? AppColors.success
        : (isMaintenance ? AppColors.mutedForeground : AppColors.gold);
    final statusLabel = isAvailable
        ? 'AVAILABLE'
        : (isMaintenance ? 'MAINTENANCE' : 'CHECKED OUT');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (car.imageUrl != null && car.imageUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    car.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  car.model,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: AppColors.mutedForeground,
                  size: 18,
                ),
                onSelected: (value) {
                  if (value == 'edit')
                    showCarFormSheet(context, ref, existing: car);
                  if (value == 'delete') _confirmDelete(context, ref);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.destructive),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            car.plateNumber,
            style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
          ),
          if (!isAvailable && !isMaintenance) ...[
            const SizedBox(height: 6),
            Text(
              'With ${car.lastCheckedOutBy ?? '—'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 10),
          if (isAvailable)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _CheckOutScreen(car: car)),
                ),
                child: const Text('Check Out'),
              ),
            ),
          if (!isAvailable && !isMaintenance)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => _CheckInScreen(car: car)),
                ),
                child: const Text('Check In'),
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckOutScreen extends ConsumerStatefulWidget {
  final CarInfo car;
  const _CheckOutScreen({required this.car});

  @override
  ConsumerState<_CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends ConsumerState<_CheckOutScreen> {
  String? _selectedBookingId;
  final _mileageController = TextEditingController();
  // A checkout records the fuel that is already in this particular vehicle.
  // Start on the level saved when it was last checked in instead of assuming
  // every available car has a full tank.
  String _fuelLevel = 'Full';
  final _remarksController = TextEditingController();
  bool _petrolCardOut = false;
  String? _petrolCardSerial;
  final Map<String, PlatformFile?> _photos = {
    'front': null,
    'back': null,
    'left': null,
    'right': null,
  };
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final savedFuelLevel = widget.car.currentFuelLevel;
    if (savedFuelLevel != null && fuelOptions.contains(savedFuelLevel)) {
      _fuelLevel = savedFuelLevel;
    }
  }

  List<_ApprovedBooking> get _approvedBookings {
    final submissions = ref.read(submissionsProvider).submissions;
    final cars = ref.read(carsProvider).cars;
    final checkedOutEmployees = cars
        .where((c) => c.status == 'checked_out')
        .map((c) => c.lastCheckedOutBy)
        .whereType<String>()
        .toSet();
    final now = DateTime.now();

    return submissions
        .where((s) {
          if (s.formType != 'car_rental' || s.status != 'approved')
            return false;
          final toDate = DateTime.tryParse(s.data['toDate']?.toString() ?? '');
          if (toDate == null) return false;
          // Keep the booking selectable through the end of its scheduled
          // day, not just its exact end time — a booking "for the 19th"
          // shouldn't vanish from checkout mid-afternoon on the 19th just
          // because its stored end-time was entered as an early hour.
          final availableUntil = DateTime(
            toDate.year,
            toDate.month,
            toDate.day,
            23,
            59,
            59,
          );
          if (availableUntil.isBefore(now)) return false;
          if (checkedOutEmployees.contains(s.employeeName)) return false;
          if (['checked_out', 'returned'].contains(s.data['carCheckoutStatus']))
            return false;
          return true;
        })
        .map(
          (s) => _ApprovedBooking(
            submissionId: s.id,
            referenceNumber: s.refNo ?? s.id.substring(0, 8),
            employeeName: s.employeeName,
          ),
        )
        .toList();
  }

  Future<void> _pickPhoto(String slot) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty)
      setState(() => _photos[slot] = result.files.first);
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    final booking = _approvedBookings.where(
      (b) => b.submissionId == _selectedBookingId,
    );
    if (booking.isEmpty) {
      _showError('Please select an approved booking.');
      return;
    }
    if (_mileageController.text.trim().isEmpty) {
      _showError('Please enter the current mileage.');
      return;
    }
    if (_petrolCardOut && _petrolCardSerial == null) {
      _showError('Please select a petrol card serial.');
      return;
    }

    setState(() => _isSubmitting = true);
    final photoUrls = <String, String?>{};
    try {
      for (final entry in _photos.entries) {
        if (entry.value == null) continue;
        final path =
            'car-photos/${widget.car.id}/out_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';
        if (entry.value!.bytes != null) {
          await supabase.storage
              .from('form-attachments')
              .uploadBinary(path, entry.value!.bytes!);
        } else if (entry.value!.path != null) {
          await supabase.storage
              .from('form-attachments')
              .upload(path, File(entry.value!.path!));
        }
        photoUrls[entry.key] = supabase.storage
            .from('form-attachments')
            .getPublicUrl(path);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Photo upload failed: $e');
      return;
    }

    final result = await ref
        .read(carsProvider.notifier)
        .checkOutCar(
          carId: widget.car.id,
          submissionId: booking.first.submissionId,
          submissionRefNo: booking.first.referenceNumber,
          employeeName: booking.first.employeeName,
          mileage: _mileageController.text.trim(),
          fuelLevel: _fuelLevel,
          remarksOut: _remarksController.text.trim(),
          photosOut: photoUrls,
          dateTimeOut: DateTime.now().toIso8601String(),
          petrolCardOut: _petrolCardOut,
          petrolCardSerialOut: _petrolCardSerial,
        );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(
        context,
        'Vehicle checked out to ${booking.first.employeeName}.',
      );
      Navigator.pop(context);
    } else {
      _showError(result.error ?? 'Checkout failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cars = ref.watch(carsProvider).cars;
    final checkedOut = cars.where((c) => c.status == 'checked_out');
    final availablePetrolCards = petrolCardOptions
        .where(
          (serial) => !checkedOut.any(
            (c) => c.petrolCardOut == true && c.petrolCardSerialOut == serial,
          ),
        )
        .toList();
    final bookings = _approvedBookings;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Check Out — ${widget.car.model}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.event_available_outlined,
            title: 'Booking',
            child: DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(14),
              dropdownColor: AppColors.card,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.mutedForeground,
              ),
              initialValue: _selectedBookingId,
              isExpanded: true,
              hint: const Text('Select an approved booking'),
              items: bookings
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.submissionId,
                      child: Text(
                        '${b.employeeName} — ${b.referenceNumber}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedBookingId = v),
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.speed_outlined,
            title: 'Vehicle Condition',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _mileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mileage (km)'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fuel Level',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (widget.car.currentFuelLevel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Current vehicle fuel: ${_fuelLevelLabel(widget.car.currentFuelLevel!)}',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: fuelOptions
                      .map(
                        (fuel) => ChoiceChip(
                          label: Text(_fuelLevelLabel(fuel)),
                          selected: _fuelLevel == fuel,
                          onSelected: (_) => setState(() => _fuelLevel = fuel),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.credit_card_outlined,
            title: 'Petrol Card',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _petrolCardOut,
                  onChanged: (v) => setState(() => _petrolCardOut = v),
                  title: const Text(
                    'Issuing a petrol card',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                if (_petrolCardOut)
                  DropdownButtonFormField<String>(
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: AppColors.card,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.mutedForeground,
                    ),
                    initialValue: _petrolCardSerial,
                    isExpanded: true,
                    hint: const Text('Select petrol card serial'),
                    items: availablePetrolCards
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _petrolCardSerial = v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '04',
            icon: Icons.camera_alt_outlined,
            title: 'Photos (optional)',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _photos.keys.map((slot) => _photoSlot(slot)).toList(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryDark,
                    ),
                  )
                : const Text('Confirm Check Out'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _photoSlot(String slot) {
    final file = _photos[slot];
    return InkWell(
      onTap: () => _pickPhoto(slot),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: file != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  Text(slot, style: TextStyle(fontSize: 10)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  Text(slot, style: TextStyle(fontSize: 10)),
                ],
              ),
      ),
    );
  }
}

class _CheckInScreen extends ConsumerStatefulWidget {
  final CarInfo car;
  const _CheckInScreen({required this.car});

  @override
  ConsumerState<_CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends ConsumerState<_CheckInScreen> {
  final _mileageController = TextEditingController();
  String _fuelLevel = '4/7';
  final _remarksController = TextEditingController();
  final Map<String, PlatformFile?> _photos = {
    'front': null,
    'back': null,
    'left': null,
    'right': null,
  };
  bool _isSubmitting = false;

  Future<void> _pickPhoto(String slot) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty)
      setState(() => _photos[slot] = result.files.first);
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    if (_mileageController.text.trim().isEmpty) {
      _showError('Please enter the return mileage.');
      return;
    }

    setState(() => _isSubmitting = true);
    final photoUrls = <String, String?>{};
    try {
      for (final entry in _photos.entries) {
        if (entry.value == null) continue;
        final path =
            'car-photos/${widget.car.id}/in_${entry.key}_${DateTime.now().millisecondsSinceEpoch}';
        if (entry.value!.bytes != null) {
          await supabase.storage
              .from('form-attachments')
              .uploadBinary(path, entry.value!.bytes!);
        } else if (entry.value!.path != null) {
          await supabase.storage
              .from('form-attachments')
              .upload(path, File(entry.value!.path!));
        }
        photoUrls[entry.key] = supabase.storage
            .from('form-attachments')
            .getPublicUrl(path);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      _showError('Photo upload failed: $e');
      return;
    }

    final result = await ref
        .read(carsProvider.notifier)
        .checkInCar(
          carId: widget.car.id,
          mileageIn: _mileageController.text.trim(),
          fuelLevelIn: _fuelLevel,
          remarks: _remarksController.text.trim(),
          photosIn: photoUrls,
          dateTimeIn: DateTime.now().toIso8601String(),
        );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'Vehicle checked in.');
      Navigator.pop(context);
    } else {
      _showError(result.error ?? 'Check-in failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Check In — ${widget.car.model}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Currently with ${widget.car.lastCheckedOutBy ?? '—'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '01',
            icon: Icons.speed_outlined,
            title: 'Return Condition',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _mileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Mileage (km)'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Fuel Level',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: fuelOptions
                      .map(
                        (f) => ChoiceChip(
                          label: Text(f),
                          selected: _fuelLevel == f,
                          onSelected: (_) => setState(() => _fuelLevel = f),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.camera_alt_outlined,
            title: 'Photos (optional)',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _photos.keys.map((slot) => _photoSlot(slot)).toList(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryDark,
                    ),
                  )
                : const Text('Confirm Check In'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _photoSlot(String slot) {
    final file = _photos[slot];
    return InkWell(
      onTap: () => _pickPhoto(slot),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 90,
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: file != null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  Text(slot, style: TextStyle(fontSize: 10)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    size: 20,
                    color: AppColors.mutedForeground,
                  ),
                  Text(slot, style: TextStyle(fontSize: 10)),
                ],
              ),
      ),
    );
  }
}
