/// Mirrors the `submissions` table + src/contexts/SubmissionsContext.tsx.
class Submission {
  final String id;
  final String formType;
  final String status;
  final String submittedAt;
  final String submittedBy;
  final String employeeName;
  final String department;
  final Map<String, dynamic> data;

  const Submission({
    required this.id,
    required this.formType,
    required this.status,
    required this.submittedAt,
    required this.submittedBy,
    required this.employeeName,
    required this.department,
    required this.data,
  });

  factory Submission.fromMap(Map<String, dynamic> map) {
    return Submission(
      id: map['id'] as String,
      formType: (map['formType'] ?? '') as String,
      status: (map['status'] ?? 'pending') as String,
      submittedAt: (map['submittedAt'] ?? '') as String,
      submittedBy: (map['submittedBy'] ?? '') as String,
      employeeName: (map['employeeName'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
    );
  }

  String? get refNo => data['refNo'] as String?;

  static const Map<String, String> formTypeLabels = {
    'car_rental': 'Company Car Request',
    'leave': 'Gate Pass',
    'claim': 'Petty Cash Claim',
    'ppe_request': 'PPE | Uniform | Office Supplies',
    'ppe_purchase': 'PPE | Uniform Purchase',
    'cctv_access_request': 'CCTV Access Request',
    'it_help_desk': 'IT Help Desk Ticket',
    'it_admin_request': 'IT Request (Admin)',
    'it_application_request': 'IT Request (Application)',
    'waste_inventory': 'Waste Inventory',
    'mixing_chemical_stages': 'Mixing & Chemical Stages',
    'final_discharge': 'Final Discharge',
    'daily_operation_monitoring': 'Daily Operation Monitoring',
  };

  String get formTypeLabel => formTypeLabels[formType] ?? formType;
}
