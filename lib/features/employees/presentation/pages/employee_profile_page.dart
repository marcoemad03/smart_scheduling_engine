import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

/// Read-only profile for the signed-in employee. Employees cannot modify
/// their own data or work permissions (admin-only, enforced by Firestore
/// rules as well as the UI).
class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({Key? key}) : super(key: key);

  Stream<Employee?> _myEmployeeStream(WidgetRef ref) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return ref
        .read(firebaseFirestoreProvider)
        .collection('employees')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : _fromDoc(s.docs.first.id, s.docs.first.data()));
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    final areasAsync = ref.watch(areaListViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myProfile)),
      body: StreamBuilder<Employee?>(
        stream: _myEmployeeStream(ref),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final employee = snapshot.data;
          if (employee == null) {
            return Center(child: Text(l10n.noEmployeesFound));
          }
          final areas = areasAsync.asData?.value ?? const [];
          final accountEmail = user?.email ?? employee.email;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 36,
                      child: Text(
                        employee.firstName.isNotEmpty
                            ? employee.firstName.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(employee.fullName,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Chip(
                      avatar: Icon(
                        employee.isActive
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        size: 16,
                        color: employee.isActive ? Colors.green : Colors.grey,
                      ),
                      label: Text(
                          employee.isActive ? l10n.active : l10n.inactive,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sectionProfile,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _row(l10n.colName, employee.fullName),
                        _row(l10n.employeeCode,
                            employee.employeeCode.isEmpty ? l10n.notSet : employee.employeeCode),
                        _row(l10n.email, accountEmail),
                        _row(l10n.phone,
                            employee.phone.isEmpty ? l10n.notSet : employee.phone),
                        _row(l10n.maxWeeklyHours,
                            '${employee.maxWeeklyHours.toStringAsFixed(0)}h'),
                      ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sectionPermissions,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(l10n.permissionsNote,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 12),
                        if (areas.isEmpty)
                          Text(l10n.noAreasYet,
                              style: const TextStyle(color: Colors.grey))
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: areas.map((a) {
                              final isAllowed =
                                  employee.isAllowedInArea(a.areaId);
                              return Chip(
                                avatar: Icon(
                                  isAllowed
                                      ? Icons.check_circle
                                      : Icons.block,
                                  size: 16,
                                  color: isAllowed
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                label: Text(a.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isAllowed
                                            ? Colors.green
                                            : Colors.red)),
                                backgroundColor:
                                    (isAllowed ? Colors.green : Colors.red)
                                        .withOpacity(0.08),
                              );
                            }).toList(),
                          ),
                      ]),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.sectionAccountInfo,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const Divider(height: 24),
                        _row(l10n.accountStatusLabel,
                            user != null ? l10n.accountLinked : l10n.accountNotLinked),
                        _row(l10n.email, accountEmail),
                      ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
