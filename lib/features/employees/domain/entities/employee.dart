class Employee {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime hireDate;
  final double maxWeeklyHours;
  final List<String> preferredAreas;
  final bool isActive;
  final String employeeCode;
  final String notes;
  final String authUid;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.hireDate,
    required this.maxWeeklyHours,
    required this.preferredAreas,
    required this.isActive,
    this.employeeCode = '',
    this.notes = '',
    this.authUid = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  /// Whether this employee profile is linked to a Firebase Auth account.
  bool get hasAccount => authUid.isNotEmpty;

  /// Whether the employee is allowed to work in [areaId]. An employee with
  /// no explicit allowed areas may work everywhere (existing behavior).
  bool isAllowedInArea(String areaId) =>
      preferredAreas.isEmpty || preferredAreas.contains(areaId);

  Employee copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    double? maxWeeklyHours,
    List<String>? preferredAreas,
    bool? isActive,
    String? employeeCode,
    String? notes,
    String? authUid,
  }) {
    return Employee(
      id: id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      hireDate: hireDate,
      maxWeeklyHours: maxWeeklyHours ?? this.maxWeeklyHours,
      preferredAreas: preferredAreas ?? this.preferredAreas,
      isActive: isActive ?? this.isActive,
      employeeCode: employeeCode ?? this.employeeCode,
      notes: notes ?? this.notes,
      authUid: authUid ?? this.authUid,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
