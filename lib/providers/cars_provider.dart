import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_config.dart';
import '../models/car_info.dart';
import 'submissions_provider.dart';

class CarsState {
  final List<CarInfo> cars;
  final bool isLoading;

  const CarsState({this.cars = const [], this.isLoading = true});

  CarsState copyWith({List<CarInfo>? cars, bool? isLoading}) {
    return CarsState(cars: cars ?? this.cars, isLoading: isLoading ?? this.isLoading);
  }
}

/// Mirrors the car-fleet slice of src/contexts/SubmissionsContext.tsx —
/// checkOutCar/checkInCar write to the same `cars` table columns and flip
/// the linked submission's `data.carCheckoutStatus` exactly as the website.
class CarsNotifier extends StateNotifier<CarsState> {
  CarsNotifier(this._ref) : super(const CarsState()) {
    refresh();
    _subscribeRealtime();
  }

  final Ref _ref;
  StreamSubscription? _sub;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final data = await supabase.from('cars').select('*').order('model');
      final cars = (data as List).map((e) => CarInfo.fromMap(e as Map<String, dynamic>)).toList();
      state = state.copyWith(cars: cars, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribeRealtime() {
    _sub = supabase.from('cars').stream(primaryKey: ['id']).listen((_) => refresh());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<({bool success, String? error})> checkOutCar({
    required String carId,
    required String submissionId,
    required String submissionRefNo,
    required String employeeName,
    required String mileage,
    required String fuelLevel,
    required String remarksOut,
    required Map<String, String?> photosOut,
    required String dateTimeOut,
    required bool petrolCardOut,
    String? petrolCardSerialOut,
  }) async {
    final updates = {
      'status': 'checked_out',
      'activeSubmissionId': submissionId,
      'activeSubmissionRefNo': submissionRefNo,
      'lastCheckedOutBy': employeeName,
      'lastCheckedOutAt': dateTimeOut,
      'mileageOut': mileage,
      'fuelLevelOut': fuelLevel,
      'remarksOut': remarksOut,
      'photosOut': photosOut,
      'petrolCardOut': petrolCardOut,
      'petrolCardSerialOut': petrolCardOut ? petrolCardSerialOut : null,
    };
    try {
      final data = await supabase.from('cars').update(updates).eq('id', carId).eq('status', 'available').select().maybeSingle();
      if (data == null) return (success: false, error: 'This vehicle is no longer available. Refresh and try again.');
      await _ref.read(submissionsProvider.notifier).updateSubmission(
        submissionId,
        status: 'approved',
        dataToMerge: {
          'carCheckoutStatus': 'checked_out',
          'assignedCarId': carId,
          'assignedCarModel': data['model'],
          'assignedCarPlateNumber': data['plateNumber'],
          'checkedOutAt': dateTimeOut,
        },
      );
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<({bool success, String? error})> checkInCar({
    required String carId,
    required String mileageIn,
    required String fuelLevelIn,
    required String remarks,
    required Map<String, String?> photosIn,
    required String dateTimeIn,
  }) async {
    final car = state.cars.where((c) => c.id == carId);
    if (car.isEmpty) return (success: false, error: 'Car not found.');
    final current = car.first;
    if (current.status != 'checked_out') return (success: false, error: 'This vehicle is no longer checked out.');

    final historyEntry = {
      'employeeName': current.lastCheckedOutBy,
      'checkedOutAt': current.lastCheckedOutAt,
      'checkedInAt': dateTimeIn,
      'mileageOut': current.mileageOut,
      'mileageIn': mileageIn,
      'fuelLevelOut': current.fuelLevelOut,
      'fuelLevelIn': fuelLevelIn,
      'remarksOut': current.remarksOut,
      'remarksIn': remarks,
      'photosOut': current.photosOut,
      'photosIn': photosIn,
      'petrolCardOut': current.petrolCardOut,
      'petrolCardSerialOut': current.petrolCardSerialOut,
      'submissionId': current.activeSubmissionId,
      'submissionRefNo': current.activeSubmissionRefNo,
    };

    final updates = {
      'status': 'available',
      'lastCheckedOutBy': null,
      'lastCheckedOutAt': null,
      'mileageOut': null,
      'fuelLevelOut': null,
      'remarksOut': null,
      'photosOut': null,
      'petrolCardOut': null,
      'petrolCardSerialOut': null,
      'activeSubmissionId': null,
      'activeSubmissionRefNo': null,
      'currentFuelLevel': fuelLevelIn,
      'history': [historyEntry, ...current.history],
    };

    try {
      final data = await supabase.from('cars').update(updates).eq('id', carId).eq('status', 'checked_out').select().maybeSingle();
      if (data == null) return (success: false, error: 'Check-in failed because the vehicle state changed. Refresh and try again.');
      if (current.activeSubmissionId != null) {
        await _ref.read(submissionsProvider.notifier).updateSubmission(
          current.activeSubmissionId!,
          status: 'completed',
          dataToMerge: {
            'carCheckoutStatus': 'returned',
            'assignedCarId': carId,
            'assignedCarModel': current.model,
            'assignedCarPlateNumber': current.plateNumber,
            'checkedInAt': dateTimeIn,
          },
        );
      }
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<({bool success, String? error})> addCar({required String plateNumber, required String model, String? type}) async {
    try {
      await supabase.from('cars').insert({'plateNumber': plateNumber, 'model': model, 'type': type, 'status': 'available'});
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<({bool success, String? error})> updateCar(
    String carId, {
    required String model,
    required String plateNumber,
    String? type,
    String? imageUrl,
    required String status,
  }) async {
    try {
      await supabase.from('cars').update({
        'model': model,
        'plateNumber': plateNumber,
        'type': type,
        'imageUrl': imageUrl,
        'status': status,
      }).eq('id', carId);
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }

  Future<({bool success, String? error})> deleteCar(String carId) async {
    try {
      await supabase.from('cars').delete().eq('id', carId);
      await refresh();
      return (success: true, error: null);
    } catch (e) {
      return (success: false, error: 'Database error: $e');
    }
  }
}

final carsProvider = StateNotifierProvider<CarsNotifier, CarsState>((ref) => CarsNotifier(ref));

const fuelOptions = ['Empty', '1/7', '2/7', '3/7', '4/7', '5/7', '6/7', 'Full'];
const petrolCardOptions = ['708381 530122 65680', '708381 530098 38960'];
const carTypeOptions = ['Sedan', 'SUV', 'Truck', 'Van'];
