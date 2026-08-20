/// Mirrors the `users` table + src/contexts/AuthContext.tsx `User` shape.
class AppUser {
  final String id;
  final String name;
  final String email;
  final String employeeId;
  final String department;
  final String position;
  final String role;
  final String phone;
  final String avatar;
  final bool isHeadOfFinance;
  final bool isHeadOfPurchasing;
  final List<String> secondaryRoles;
  final String icNo;
  final String drivingLicenseNo;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.employeeId,
    required this.department,
    required this.position,
    required this.role,
    this.phone = '',
    this.avatar = '',
    this.isHeadOfFinance = false,
    this.isHeadOfPurchasing = false,
    this.secondaryRoles = const [],
    this.icNo = '',
    this.drivingLicenseNo = '',
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      employeeId: (map['employeeId'] ?? map['employeeid'] ?? '') as String,
      department: (map['department'] ?? '') as String,
      position: (map['position'] ?? '') as String,
      role: ((map['role'] ?? 'employee') as String).trim().toLowerCase(),
      phone: (map['phone'] ?? '') as String,
      avatar: (map['avatar'] ?? '') as String,
      isHeadOfFinance: (map['is_head_of_finance'] ?? false) as bool,
      isHeadOfPurchasing: (map['is_head_of_purchasing'] ?? false) as bool,
      secondaryRoles: ((map['secondary_roles'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      icNo: (map['ic_no'] ?? '') as String,
      drivingLicenseNo: (map['driving_license_no'] ?? '') as String,
    );
  }

  AppUser copyWith({
    String? name,
    String? department,
    String? position,
    String? phone,
    String? avatar,
    String? icNo,
    String? drivingLicenseNo,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      employeeId: employeeId,
      department: department ?? this.department,
      position: position ?? this.position,
      role: role,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      isHeadOfFinance: isHeadOfFinance,
      isHeadOfPurchasing: isHeadOfPurchasing,
      secondaryRoles: secondaryRoles,
      icNo: icNo ?? this.icNo,
      drivingLicenseNo: drivingLicenseNo ?? this.drivingLicenseNo,
    );
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0]).join().toUpperCase();
  }
}

/// Mirrors src/contexts/UsersContext.tsx `AppUser` (the admin/approver
/// directory) — kept separate from [AppUser] above because the website
/// itself keeps two subtly different shapes for the same `users` rows.
class DirectoryUser {
  final String id;
  final String name;
  final String email;
  final String staffId;
  final String role;
  final String department;
  final String position;
  final List<String> secondaryRoles;
  final String status;
  final String phone;
  final String avatar;
  final String? deactivatedAt;
  final String? deactivatedByName;

  const DirectoryUser({
    required this.id,
    required this.name,
    required this.email,
    required this.staffId,
    required this.role,
    required this.department,
    this.position = '',
    this.secondaryRoles = const [],
    this.status = 'active',
    this.phone = '',
    this.avatar = '',
    this.deactivatedAt,
    this.deactivatedByName,
  });

  factory DirectoryUser.fromMap(Map<String, dynamic> map) {
    return DirectoryUser(
      id: map['id'] as String,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      staffId: (map['employeeId'] ?? map['employeeid'] ?? '') as String,
      role: ((map['role'] ?? 'employee') as String),
      department: (map['department'] ?? '') as String,
      position: (map['position'] ?? '') as String,
      status: (map['status'] ?? 'active') as String,
      phone: (map['phone'] ?? '') as String,
      avatar: (map['avatar'] ?? '') as String,
      deactivatedAt: map['deactivated_at'] as String?,
      deactivatedByName: map['deactivated_by_name'] as String?,
      secondaryRoles: ((map['secondary_roles'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  bool hasRole(String targetRole) {
    final normalized = targetRole.toLowerCase();
    return role.toLowerCase() == normalized ||
        secondaryRoles.any((r) => r.toLowerCase() == normalized);
  }
}
