class EmployeeModel {
  final String employeeId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime hireDate;
  final double maxWeeklyHours;
  final List<String> preferredAreas;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeModel({
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.hireDate,
    required this.maxWeeklyHours,
    required this.preferredAreas,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      employeeId: json['employeeId'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      hireDate: (json['hireDate'] as Timestamp).toDate(),
      maxWeeklyHours: (json['maxWeeklyHours'] as num?)?.toDouble() ?? 48.0,
      preferredAreas: (json['preferredAreas'] as List?)?.cast<String>() ?? [],
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'hireDate': Timestamp.fromDate(hireDate),
      'maxWeeklyHours': maxWeeklyHours,
      'preferredAreas': preferredAreas,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Employee toDomain() {
    return Employee(
      id: employeeId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      hireDate: hireDate,
      maxWeeklyHours: maxWeeklyHours,
      preferredAreas: preferredAreas,
      isActive: isActive,
    );
  }
}