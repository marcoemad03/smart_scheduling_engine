import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

class EmployeesViewModel extends StateNotifier<AsyncValue<List<Employee>>> {
  final FirebaseFirestore firestore;
  StreamSubscription? _sub;

  EmployeesViewModel(this.firestore) : super(const AsyncValue.loading()) {
    _sub = firestore
        .collection('employees')
        .snapshots()
        .map((s) => s.docs
            .map((d) => _fromDoc(d.id, d.data()))
            .toList())
        .listen((list) {
      list.sort((a, b) => a.fullName.compareTo(b.fullName));
      state = AsyncValue.data(list);
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  Employee _fromDoc(String id, Map<String, dynamic> d) {
    return Employee(
      id: d['employeeId'] as String? ?? id,
      firstName: d['firstName'] as String? ?? '',
      lastName: d['lastName'] as String? ?? '',
      email: d['email'] as String? ?? '',
      phone: d['phone'] as String? ?? '',
      hireDate: d['hireDate'] != null
          ? (d['hireDate'] as Timestamp).toDate()
          : DateTime.now(),
      maxWeeklyHours: (d['maxWeeklyHours'] as num?)?.toDouble() ?? 48,
      preferredAreas: (d['preferredAreas'] as List?)?.cast<String>() ?? const [],
      isActive: d['isActive'] as bool? ?? true,
      employeeCode: d['employeeCode'] as String? ?? '',
      notes: d['notes'] as String? ?? '',
      authUid: d['authUid'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Future<void> save(Employee e) async {
    await firestore.collection('employees').doc(e.id).set({
      'employeeId': e.id,
      'firstName': e.firstName,
      'lastName': e.lastName,
      'email': e.email,
      'phone': e.phone,
      'hireDate': Timestamp.fromDate(e.hireDate),
      'maxWeeklyHours': e.maxWeeklyHours,
      'preferredAreas': e.preferredAreas,
      'isActive': e.isActive,
      'employeeCode': e.employeeCode,
      'notes': e.notes,
      'authUid': e.authUid,
      'createdAt': Timestamp.fromDate(e.createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  /// Hard-deletes the employee profile document. The Firebase Auth account
  /// is intentionally NOT deleted (requires Admin SDK); deactivate the
  /// employee instead to revoke scheduling access.
  Future<void> delete(Employee e) async {
    await firestore.collection('employees').doc(e.id).delete();
    if (e.hasAccount) {
      // Remove the login profile so the account can no longer sign in to
      // this app (the Auth record itself remains but has no profile).
      try {
        await firestore.collection('users').doc(e.authUid).delete();
      } catch (_) {
        // Profile doc may not exist; the employee record removal is primary.
      }
    }
  }

  Future<void> setActive(Employee e, bool active) async {
    await save(e.copyWith(isActive: active));
  }

  Future<String> nextEmployeeCode() async {
    final snapshot = await firestore
        .collection('employees')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    var max = 0;
    for (final doc in snapshot.docs) {
      final code = doc.data()['employeeCode'] as String? ?? '';
      final digits = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), ''));
      if (digits != null && digits > max) max = digits;
    }
    return (max + 1).toString().padLeft(4, '0');
  }

  Future<List<ReceptionArea>> loadAreas() async {
    final snapshot =
        await firestore.collection('areas').orderBy('orderIndex').get();
    return snapshot.docs.map((doc) {
      final d = doc.data();
      return ReceptionArea(
        areaId: d['areaId'] as String? ?? doc.id,
        name: d['name'] as String? ?? '',
        description: d['description'] as String? ?? '',
        orderIndex: d['orderIndex'] as int? ?? 0,
        isActive: d['isActive'] as bool? ?? true,
      );
    }).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final employeesViewModelProvider =
    StateNotifierProvider<EmployeesViewModel, AsyncValue<List<Employee>>>((ref) {
  return EmployeesViewModel(ref.watch(firebaseFirestoreProvider));
});

final newEmployeeIdProvider = Provider<String>((ref) => const Uuid().v4());
