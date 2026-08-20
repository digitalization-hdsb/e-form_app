/// Mirrors the `cars` table + CarInfo in src/contexts/SubmissionsContext.tsx.
class CarInfo {
  final String id;
  final String plateNumber;
  final String model;
  final String status; // available | checked_out | maintenance
  final String? lastCheckedOutBy;
  final String? lastCheckedOutAt;
  final String? mileageOut;
  final String? fuelLevelOut;
  final String? currentFuelLevel;
  final String? remarksOut;
  final Map<String, dynamic>? photosOut;
  final bool? petrolCardOut;
  final String? petrolCardSerialOut;
  final String? activeSubmissionId;
  final String? activeSubmissionRefNo;
  final List<dynamic> history;
  final String? type;
  final String? imageUrl;

  const CarInfo({
    required this.id,
    required this.plateNumber,
    required this.model,
    required this.status,
    this.lastCheckedOutBy,
    this.lastCheckedOutAt,
    this.mileageOut,
    this.fuelLevelOut,
    this.currentFuelLevel,
    this.remarksOut,
    this.photosOut,
    this.petrolCardOut,
    this.petrolCardSerialOut,
    this.activeSubmissionId,
    this.activeSubmissionRefNo,
    this.history = const [],
    this.type,
    this.imageUrl,
  });

  factory CarInfo.fromMap(Map<String, dynamic> map) {
    return CarInfo(
      id: map['id'] as String,
      plateNumber: (map['plateNumber'] ?? '') as String,
      model: (map['model'] ?? '') as String,
      status: (map['status'] ?? 'available') as String,
      lastCheckedOutBy: map['lastCheckedOutBy'] as String?,
      lastCheckedOutAt: map['lastCheckedOutAt'] as String?,
      mileageOut: map['mileageOut'] as String?,
      fuelLevelOut: map['fuelLevelOut'] as String?,
      currentFuelLevel: map['currentFuelLevel'] as String?,
      remarksOut: map['remarksOut'] as String?,
      photosOut: (map['photosOut'] as Map?)?.cast<String, dynamic>(),
      petrolCardOut: map['petrolCardOut'] as bool?,
      petrolCardSerialOut: map['petrolCardSerialOut'] as String?,
      activeSubmissionId: map['activeSubmissionId'] as String?,
      activeSubmissionRefNo: map['activeSubmissionRefNo'] as String?,
      history: (map['history'] as List?) ?? const [],
      type: map['type'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }

  String get label => '$model ($plateNumber)';
}
