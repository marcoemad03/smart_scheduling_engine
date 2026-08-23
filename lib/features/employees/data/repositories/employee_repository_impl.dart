import '../data/datasources/employee_remote_datasource.dart';
import '../data/models/employee_model.dart';
import '../../core/errors/exceptions.dart';

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
    try {
      final model = await remoteDataSource.getEmployeeById(id);
      return model.toDomain();
    } catch (e) {
      throw AppException('Failed to get employee: $e');
    }
  }

  @override
  Future<void> createEmployee(Employee employee) async {
    try {
      final model = EmployeeModel(
        employeeId: employee.id,
        firstName: employee.firstName,
        lastName: employee.lastName,
        email: employee.email,
        phone: employee.phone,
        hireDate: employee.hireDate,
        maxWeeklyHours: employee.maxWeeklyHours,
        preferredAreas: employee.preferredAreas,
        isActive: employee.isActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await remoteDataSource.createEmployee(model);
    } catch (e) {
      throw AppException('Failed to create employee: $e');
    }
  }

  @override
  Future<void> updateEmployee(Employee employee) async {
    try {
      final existing = await remoteDataSource.getEmployeeById(employee.id);
      final model = EmployeeModel(
        employeeId: employee.id,
        firstName: employee.firstName,
        lastName: employee.lastName,
        email: employee.email,
        phone: employee.phone,
        hireDate: employee.hireDate,
        maxWeeklyHours: employee.maxWeeklyHours,
        preferredAreas: employee.preferredAreas,
        isActive: employee.isActive,
        createdAt: existing.createdAt,
        updatedAt: DateTime.now(),
      );
      await remoteDataSource.updateEmployee(model);
    } catch (e) {
      throw AppException('Failed to update employee: $e');
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    try {
      await remoteDataSource.deleteEmployee(id);
    } catch (e) {
      throw AppException('Failed to delete employee: $e');
    }
  }
}