import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';

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