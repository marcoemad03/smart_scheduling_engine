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
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get fullName => '$firstName $lastName';

  Employee copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    double? maxWeeklyHours,
    List<String>? preferredAreas,
    bool? isActive,
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
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}