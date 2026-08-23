import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/errors/exceptions.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

class EmployeeRemoteDataSource {
  final FirebaseFirestore firestore;

  EmployeeRemoteDataSource({required this.firestore});

  Stream<List<EmployeeModel>> getEmployees() {
    return firestore.collection('employees').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => EmployeeModel.fromJson(doc.data()))
          .toList(),
    );
  }

  Future<EmployeeModel> getEmployeeById(String id) async {
    final doc = await firestore.collection('employees').doc(id).get();
    if (!doc.exists) throw Exception('Employee not found');
    return EmployeeModel.fromJson(doc.data()!);
  }

  Future<void> createEmployee(EmployeeModel employee) async {
    await firestore.collection('employees').doc(employee.employeeId).set(
      employee.toJson(),
    );
  }

  Future<void> updateEmployee(EmployeeModel employee) async {
    await firestore.collection('employees').doc(employee.employeeId).update({
      ...employee.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEmployee(String id) async {
    await firestore.collection('employees').doc(id).delete();
  }
}

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
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

abstract class EmployeeRepository {
  Stream<List<Employee>> getEmployees();
  Future<Employee> getEmployeeById(String id);
  Future<void> createEmployee(Employee employee);
  Future<void> updateEmployee(Employee employee);
  Future<void> deleteEmployee(String id);
  Future<void> toggleEmployeeStatus(String id, bool isActive);
}

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;

  EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<Employee>> getEmployees() {
    return remoteDataSource.getEmployees().map(
      (models) => models.map((model) => model.toDomain()).toList(),
    );
  }

  @override
  Future<Employee> getEmployeeById(String id) async {
    final model = await remoteDataSource.getEmployeeById(id);
    return model.toDomain();
  }

  @override
  Future<void> createEmployee(Employee employee) => remoteDataSource.createEmployee(EmployeeModel(
    employeeId: employee.id,
    firstName: employee.firstName,
    lastName: employee.lastName,
    email: employee.email,
    phone: employee.phone,
    hireDate: employee.hireDate,
    maxWeeklyHours: employee.maxWeeklyHours,
    preferredAreas: employee.preferredAreas,
    isActive: employee.isActive,
    createdAt: employee.createdAt,
    updatedAt: employee.updatedAt,
  ));

  @override
  Future<void> updateEmployee(Employee employee) => remoteDataSource.updateEmployee(EmployeeModel(
    employeeId: employee.id,
    firstName: employee.firstName,
    lastName: employee.lastName,
    email: employee.email,
    phone: employee.phone,
    hireDate: employee.hireDate,
    maxWeeklyHours: employee.maxWeeklyHours,
    preferredAreas: employee.preferredAreas,
    isActive: employee.isActive,
    createdAt: employee.createdAt,
    updatedAt: employee.updatedAt,
  ));

  @override
  Future<void> deleteEmployee(String id) => remoteDataSource.deleteEmployee(id);

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {
    final employee = await getEmployeeById(id);
    await updateEmployee(employee.copyWith(isActive: isActive));
  }
}

class MockEmployeeRepository extends EmployeeRepository {
  @override
  Future<void> createEmployee(Employee employee) async {}

  @override
  Future<void> deleteEmployee(String id) async {}

  @override
  Stream<List<Employee>> getEmployees() async* {
    yield [];
  }

  @override
  Future<Employee> getEmployeeById(String id) async {
    throw Exception('Not implemented');
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {}

  @override
  Future<void> updateEmployee(Employee employee) async {}
}

class EmployeeListViewModel extends StateNotifier<AsyncValue<List<Employee>>> {
  EmployeeListViewModel() : super(const AsyncValue.loading()) {
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    state = AsyncValue.data([
      Employee(
        id: 'emp1',
        firstName: 'John',
        lastName: 'Smith',
        email: 'john@hospital.com',
        phone: '555-1234',
        hireDate: DateTime(2020, 1, 15),
        maxWeeklyHours: 40,
        preferredAreas: ['Emergency', 'Pharmacy'],
        isActive: true,
        createdAt: DateTime(2020, 1, 15),
        updatedAt: DateTime(2020, 1, 15),
      ),
      Employee(
        id: 'emp2',
        firstName: 'Sarah',
        lastName: 'Johnson',
        email: 'sarah@hospital.com',
        phone: '555-5678',
        hireDate: DateTime(2019, 6, 10),
        maxWeeklyHours: 35,
        preferredAreas: ['Clinics', 'Operations'],
        isActive: true,
        createdAt: DateTime(2019, 6, 10),
        updatedAt: DateTime(2019, 6, 10),
      ),
    ]);
  }
}

final employeeListViewModelProvider =
    StateNotifierProvider<EmployeeListViewModel, AsyncValue<List<Employee>>>(
  (ref) => EmployeeListViewModel(),
);