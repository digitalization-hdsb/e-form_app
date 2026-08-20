import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/submission.dart';

/// Keys already surfaced by [EmployeeInfoCard] — pass as
/// `SubmissionDataView(extraHiddenKeys: identityDataKeys)` so the generic
/// form-field dump doesn't repeat them.
const Set<String> identityDataKeys = {
  'employeeInfo',
  'name',
  'staffId',
  'icNo',
  'department',
  'position',
  'mobileNumber',
  'drivingLicenseNo',
};

class _EmployeeInfo {
  final String name;
  final String? staffId;
  final String department;
  final String? position;
  final String? phone;
  final String? icNo;
  final String? drivingLicenseNo;
  final String avatar;

  const _EmployeeInfo({
    required this.name,
    this.staffId,
    required this.department,
    this.position,
    this.phone,
    this.icNo,
    this.drivingLicenseNo,
    this.avatar = '',
  });

  /// Pulls employee identity fields out of a submission's `data` blob,
  /// mirroring the `EmployeeSummary` props built in AdminDashboard.tsx /
  /// MySubmissions.tsx — either from the nested `employeeInfo` object used
  /// by leave/PPE forms, or the flat fields used by car_rental/claim.
  factory _EmployeeInfo.from(Submission s) {
    final rawInfo = s.data['employeeInfo'];
    final nested = rawInfo is Map ? rawInfo : const {};
    String? str(dynamic v) => (v == null || v.toString().isEmpty) ? null : v.toString();

    return _EmployeeInfo(
      name: s.employeeName,
      staffId: str(s.data['staffId']) ?? str(nested['staffNo']) ?? str(nested['employeeNumber']),
      department: s.department.isNotEmpty ? s.department : (str(nested['department']) ?? '—'),
      position: str(nested['position']) ?? str(s.data['position']),
      phone: str(nested['phone']) ?? str(s.data['mobileNumber']),
      icNo: str(s.data['icNo']),
      drivingLicenseNo: str(s.data['drivingLicenseNo']),
      avatar: str(nested['avatar']) ?? str(s.data['avatar']) ?? '',
    );
  }
}

/// The employee identity block shown at the top of every submission detail
/// sheet — mirrors `EmployeeSummary.tsx`'s position right after the header,
/// ahead of the form-specific fields.
class EmployeeInfoCard extends StatelessWidget {
  final Submission submission;

  const EmployeeInfoCard({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {
    final info = _EmployeeInfo.from(submission);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                backgroundImage: info.avatar.isNotEmpty ? NetworkImage(info.avatar) : null,
                child: info.avatar.isEmpty
                    ? Text(_initials(info.name), style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (info.position != null)
                      Text(info.position!, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _field(Icons.badge_outlined, 'Staff ID', info.staffId),
              _field(Icons.apartment_outlined, 'Department', info.department),
              _field(Icons.phone_outlined, 'Phone', info.phone),
              _field(Icons.credit_card_outlined, 'IC No', info.icNo),
              _field(Icons.directions_car_outlined, 'Licence No', info.drivingLicenseNo),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(IconData icon, String label, String? value) {
    if (value == null) return const SizedBox.shrink();
    return SizedBox(
      width: 148,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
                const SizedBox(height: 1),
                Text(value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }
}
