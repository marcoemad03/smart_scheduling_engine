import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/services/employee_account_service.dart';
import 'package:reception_workforce_scheduler/features/employees/data/employees_repository.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';

/// Number of assignments per employee for the current week, shown in the
/// employees table.
final weekShiftCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  final weekStart = DateTimeUtils.getStartOfWeek(DateTime.now());
  final schedule = await repository.getScheduleByWeek(weekStart);
  final counts = <String, int>{};
  if (schedule == null) return counts;
  for (final a in schedule.assignments) {
    counts[a.employeeId] = (counts[a.employeeId] ?? 0) + 1;
  }
  return counts;
});

/// Localizes account-provisioning errors for display.
String localizeAccountError(AppLocalizations l10n, Object error) {
  if (error is AccountProvisionException) {
    switch (error.code) {
      case 'email-already-in-use':
        return l10n.authErrEmailInUse;
      case 'weak-password':
        return l10n.authErrWeakPassword;
      case 'invalid-email':
        return l10n.authInvalidEmail;
      case 'network-request-failed':
        return l10n.authNetworkError;
      default:
        return l10n.accountUnknownError;
    }
  }
  return '$error';
}

class EmployeeListPage extends ConsumerStatefulWidget {
  const EmployeeListPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeListPage> createState() => _EmployeeListPageState();
}

enum _StatusFilter { all, active, inactive }

class _EmployeeListPageState extends ConsumerState<EmployeeListPage> {
  String _searchTerm = '';
  _StatusFilter _statusFilter = _StatusFilter.all;
  String? _areaFilter;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesViewModelProvider);
    final areasAsync = ref.watch(areaListViewModelProvider);
    final countsAsync = ref.watch(weekShiftCountsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeesTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: Text(l10n.addEmployee),
        onPressed: () => _showEmployeeDialog(context, null),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: SearchBar(
                    hintText: l10n.searchEmployeesHint,
                    onChanged: (value) => setState(() => _searchTerm = value),
                    leading: const Icon(Icons.search_outlined),
                  ),
                ),
                DropdownButton<_StatusFilter>(
                  value: _statusFilter,
                  items: [
                    DropdownMenuItem(
                        value: _StatusFilter.all,
                        child: Text(l10n.filterAllStatuses)),
                    DropdownMenuItem(
                        value: _StatusFilter.active,
                        child: Text(l10n.active)),
                    DropdownMenuItem(
                        value: _StatusFilter.inactive,
                        child: Text(l10n.inactive)),
                  ],
                  onChanged: (v) =>
                      setState(() => _statusFilter = v ?? _StatusFilter.all),
                ),
                areasAsync.maybeWhen(
                  data: (areas) => DropdownButton<String>(
                    value: _areaFilter,
                    hint: Text(l10n.filterByArea),
                    items: [
                      DropdownMenuItem<String>(
                          value: null, child: Text(l10n.filterByArea)),
                      ...areas.map((a) => DropdownMenuItem(
                          value: a.areaId, child: Text(a.name))),
                    ],
                    onChanged: (v) => setState(() => _areaFilter = v),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                final filtered = employees.where((e) {
                  switch (_statusFilter) {
                    case _StatusFilter.active:
                      if (!e.isActive) return false;
                      break;
                    case _StatusFilter.inactive:
                      if (e.isActive) return false;
                      break;
                    case _StatusFilter.all:
                      break;
                  }
                  if (_areaFilter != null &&
                      !e.preferredAreas.contains(_areaFilter)) {
                    return false;
                  }
                  final q = _searchTerm.toLowerCase();
                  if (q.isEmpty) return true;
                  return e.fullName.toLowerCase().contains(q) ||
                      e.email.toLowerCase().contains(q) ||
                      e.employeeCode.toLowerCase().contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Text(l10n.noEmployeesFound));
                }

                final isDesktop = MediaQuery.of(context).size.width > 900;
                final areaNames = areasAsync.maybeWhen(
                  data: (areas) =>
                      {for (final a in areas) a.areaId: a.name},
                  orElse: () => const <String, String>{},
                );
                final counts =
                    countsAsync.asData?.value ?? const <String, int>{};

                return RefreshIndicator(
                  onRefresh: () async {},
                  child: isDesktop
                      ? ListView(padding: const EdgeInsets.all(16), children: [
                          _table(context, filtered, areaNames, counts)
                        ])
                      : _mobileList(context, filtered, areaNames, counts),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                  child:
                      Text(AppLocalizations.of(context)!.errorPrefix('$error'))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, List<Employee> employees,
      Map<String, String> areaNames, Map<String, int> counts) {
    final l10n = AppLocalizations.of(context)!;
    return DataTable(
      columns: [
        DataColumn(label: Text(l10n.colName)),
        DataColumn(label: Text(l10n.colCode)),
        DataColumn(label: Text(l10n.colEmail)),
        DataColumn(label: Text(l10n.colAccount)),
        DataColumn(label: Text(l10n.colStatus)),
        DataColumn(label: Text(l10n.colAllowedAreas)),
        DataColumn(label: Text(l10n.colMaxHours), numeric: true),
        DataColumn(label: Text(l10n.colShiftsWeek), numeric: true),
        DataColumn(label: Text(l10n.colActions)),
      ],
      rows: employees.map((e) {
        return DataRow(cells: [
          DataCell(Text(e.fullName)),
          DataCell(Text(e.employeeCode.isEmpty ? '-' : e.employeeCode)),
          DataCell(Text(e.email)),
          DataCell(_accountChip(context, e)),
          DataCell(_statusChip(context, e.isActive)),
          DataCell(Text(_areasLabel(e, areaNames, l10n))),
          DataCell(Text('${e.maxWeeklyHours.toStringAsFixed(0)}h')),
          DataCell(Text('${counts[e.id] ?? 0}')),
          DataCell(_actions(context, e)),
        ]);
      }).toList(),
    );
  }

  Widget _mobileList(BuildContext context, List<Employee> employees,
      Map<String, String> areaNames, Map<String, int> counts) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: employees.length,
      itemBuilder: (context, i) {
        final e = employees[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(e.firstName.isNotEmpty
                  ? e.firstName.substring(0, 1).toUpperCase()
                  : '?'),
            ),
            title: Text(e.fullName),
            subtitle: Text(
                '${e.employeeCode.isEmpty ? '-' : e.employeeCode} • ${e.email}\n'
                '${_areasLabel(e, areaNames, l10n)} • ${counts[e.id] ?? 0} ${l10n.colShiftsWeek}'),
            isThreeLine: true,
            trailing: _actions(context, e),
          ),
        );
      },
    );
  }

  String _areasLabel(
      Employee e, Map<String, String> areaNames, AppLocalizations l10n) {
    if (e.preferredAreas.isEmpty) return l10n.allAreas;
    return e.preferredAreas
        .map((id) => areaNames[id] ?? id)
        .join(', ');
  }

  Widget _accountChip(BuildContext context, Employee e) {
    final l10n = AppLocalizations.of(context)!;
    return Tooltip(
      message: e.hasAccount ? e.authUid : l10n.accountNotLinked,
      child: Chip(
        avatar: Icon(
          e.hasAccount ? Icons.verified_user_outlined : Icons.person_off_outlined,
          size: 16,
          color: e.hasAccount ? Colors.green : Colors.grey,
        ),
        label: Text(e.hasAccount ? l10n.accountLinked : l10n.accountNotLinked,
            style: const TextStyle(fontSize: 11)),
        backgroundColor: e.hasAccount
            ? Colors.green.withOpacity(0.12)
            : Colors.grey.withOpacity(0.15),
      ),
    );
  }

  Widget _statusChip(BuildContext context, bool isActive) {
    final l10n = AppLocalizations.of(context)!;
    return Chip(
      label: Text(isActive ? l10n.active : l10n.inactive),
      backgroundColor: isActive
          ? Colors.green.withOpacity(0.15)
          : Colors.grey.withOpacity(0.2),
    );
  }

  Widget _actions(BuildContext context, Employee e) {
    final l10n = AppLocalizations.of(context)!;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: l10n.viewDetails,
        icon: const Icon(Icons.info_outline, size: 20),
        onPressed: () => context.go('/admin/employees/${e.id}'),
      ),
      IconButton(
        tooltip: l10n.edit,
        icon: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _showEmployeeDialog(context, e),
      ),
      IconButton(
        tooltip: e.isActive ? l10n.deactivate : l10n.activate,
        icon: Icon(
          e.isActive ? Icons.toggle_on : Icons.toggle_off,
          size: 22,
          color: e.isActive ? Colors.green : Colors.grey,
        ),
        onPressed: () => ref
            .read(employeesViewModelProvider.notifier)
            .setActive(e, !e.isActive),
      ),
      if (e.hasAccount)
        IconButton(
          tooltip: l10n.resetPassword,
          icon: const Icon(Icons.lock_reset_outlined, size: 19),
          onPressed: () => _resetPassword(context, e),
        ),
      IconButton(
        tooltip: l10n.delete,
        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        onPressed: () => _confirmDelete(context, e),
      ),
    ]);
  }

  Future<void> _resetPassword(BuildContext context, Employee e) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(employeeAccountServiceProvider)
          .sendPasswordReset(e.email);
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.resetPasswordSent(e.email)),
          backgroundColor: Colors.green));
    } catch (err) {
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.errorPrefix('$err')),
          backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Employee e) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEmployeeTitle),
        content: Text(l10n.deleteEmployeeBody(e.fullName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(employeesViewModelProvider.notifier).delete(e);
    }
  }

  void _showEmployeeDialog(BuildContext context, Employee? employee) async {
    final vm = ref.read(employeesViewModelProvider.notifier);
    final accountService = ref.read(employeeAccountServiceProvider);
    final areasAsync = ref.watch(areaListViewModelProvider);
    final allAreas = areasAsync.asData?.value ?? await vm.loadAreas();

    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);

    final isCreate = employee == null;
    final hasAccount = employee?.hasAccount ?? false;
    final formKey = GlobalKey<FormState>();
    final firstNameController =
        TextEditingController(text: employee?.firstName ?? '');
    final lastNameController =
        TextEditingController(text: employee?.lastName ?? '');
    final codeController =
        TextEditingController(text: employee?.employeeCode ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final phoneController = TextEditingController(text: employee?.phone ?? '');
    final maxHoursController = TextEditingController(
        text: employee?.maxWeeklyHours.toStringAsFixed(0) ?? '48');
    final notesController = TextEditingController(text: employee?.notes ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    var hireDate = employee?.hireDate ?? DateTime.now();
    var isActive = employee?.isActive ?? true;
    final allowedAreas = <String>{...(employee?.preferredAreas ?? const [])};
    var createAccount = isCreate;
    var passwordVisible = false;

    // Auth role ('employee'/'admin') stored on the login profile.
    var initialRole = 'employee';
    var selectedRole = 'employee';
    if (!isCreate && (employee?.hasAccount ?? false)) {
      try {
        final current =
            await accountService.fetchUserRole(employee!.authUid);
        if (current != null) {
          initialRole = current;
          selectedRole = current;
        }
      } catch (_) {
        // Profile unreadable - default to employee (least privilege).
      }
    }

    String generatePassword() {
      const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
      final rnd = DateTime.now().microsecondsSinceEpoch;
      var out = '';
      for (var i = 0; i < 8; i++) {
        out += chars[(rnd >> (i * 3)) % chars.length];
      }
      return out;
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: Text(isCreate ? l10n.addEmployee : l10n.editEmployee),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.sectionProfile,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: firstNameController,
                        decoration:
                            InputDecoration(labelText: l10n.firstName),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? l10n.required : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lastNameController,
                        decoration:
                            InputDecoration(labelText: l10n.lastName),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? l10n.required : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeController,
                    decoration:
                        InputDecoration(labelText: l10n.employeeCode),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(labelText: l10n.email),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return l10n.required;
                      if (!v.contains('@')) return l10n.invalidEmail;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: InputDecoration(labelText: l10n.phone),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: maxHoursController,
                        decoration:
                            InputDecoration(labelText: l10n.maxWeeklyHours),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration:
                            InputDecoration(labelText: l10n.hireDate),
                        child: InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: ctx2,
                              initialDate: hireDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setDialog(() => hireDate = d);
                          },
                          child: Text(
                              DateFormat('MMM d, yyyy').format(hireDate)),
                        ),
                      ),
                    ),
                  ]),
                  SwitchListTile(
                    title: Text(isActive ? l10n.active : l10n.inactive),
                    value: isActive,
                    onChanged: (v) => setDialog(() => isActive = v),
                  ),
                  const SizedBox(height: 8),

                  // ---- Allowed work areas (dynamic from Firestore) ----
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.allowedAreas,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey))),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.allowedAreasHint,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey))),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: allAreas
                        .where((ReceptionArea a) => a.isActive)
                        .map((ReceptionArea a) {
                      final selected = allowedAreas.contains(a.areaId);
                      return FilterChip(
                        label: Text(a.name),
                        selected: selected,
                        onSelected: (sel) => setDialog(() {
                          sel
                              ? allowedAreas.add(a.areaId)
                              : allowedAreas.remove(a.areaId);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // ---- Account (Firebase Authentication) ----
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.accountSection,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey))),
                  if (isCreate || !hasAccount) ...[
                    SwitchListTile(
                      title: Text(l10n.generateAccount),
                      subtitle: Text(l10n.generateAccountDesc,
                          style: const TextStyle(fontSize: 11)),
                      value: createAccount,
                      onChanged: (v) => setDialog(() => createAccount = v),
                    ),
                    if (createAccount) ...[
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.temporaryPassword,
                          border: const OutlineInputBorder(),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l10n.generatePassword,
                                icon: const Icon(Icons.casino_outlined,
                                    size: 20),
                                onPressed: () => setDialog(() {
                                  passwordController.text =
                                      generatePassword();
                                  confirmPasswordController.text =
                                      passwordController.text;
                                }),
                              ),
                              IconButton(
                                icon: Icon(
                                    passwordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    size: 20),
                                onPressed: () => setDialog(
                                    () => passwordVisible = !passwordVisible),
                              ),
                            ],
                          ),
                        ),
                        obscureText: !passwordVisible,
                        validator: (v) {
                          if (!createAccount) return null;
                          if (v == null || v.isEmpty) return l10n.required;
                          if (v.length < 6) return l10n.passwordMinLength;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: l10n.confirmPassword,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: !passwordVisible,
                        validator: (v) {
                          if (!createAccount) return null;
                          if (v != passwordController.text) {
                            return l10n.passwordMismatch;
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.passwordNeverStored,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ] else
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.verified_user_outlined,
                          color: Colors.green),
                      title: Text(l10n.accountLinked,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(emailController.text,
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                        tooltip: l10n.resetPassword,
                        icon: const Icon(Icons.lock_reset_outlined),
                        onPressed: () => _resetPassword(ctx2, employee),
                      ),
                    ),
                  if (hasAccount || (isCreate && createAccount)) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: InputDecoration(labelText: l10n.roleLabel),
                      items: [
                        DropdownMenuItem(
                            value: 'employee', child: Text(l10n.roleEmployee)),
                        DropdownMenuItem(
                            value: 'admin', child: Text(l10n.roleAdmin)),
                      ],
                      onChanged: (v) =>
                          setDialog(() => selectedRole = v ?? 'employee'),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.roleAdminHint,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  ] else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(l10n.roleNeedsAccount,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesController,
                    decoration: InputDecoration(
                        labelText: l10n.notes, alignLabelWithHint: true),
                    maxLines: 3,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final navigator = Navigator.of(ctx2);

                String authUid = employee?.authUid ?? '';
                if (isCreate || !hasAccount) {
                  if (createAccount) {
                    try {
                      final email = emailController.text.trim();
                      final existed = await accountService
                          .findUidByEmail(email) !=
                          null;
                      authUid = await accountService.createOrReuseAccount(
                        email: email,
                        password: passwordController.text,
                      );
                      await accountService.ensureUserProfile(
                        uid: authUid,
                        email: email,
                        displayName:
                            '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
                                .trim(),
                        linkedEmployeeId: employee?.id ?? '',
                      );
                      messenger.showSnackBar(SnackBar(
                        content: Text(existed
                            ? l10n.accountReused(email)
                            : l10n.accountCreatedFor(email)),
                        backgroundColor: Colors.green,
                      ));
                    } catch (err) {
                      messenger.showSnackBar(SnackBar(
                        content: Text(
                            localizeAccountError(l10n, err)),
                        backgroundColor: Colors.red,
                      ));
                      return;
                    }
                  }
                }

                final saved = Employee(
                  id: employee?.id ?? const Uuid().v4(),
                  firstName: firstNameController.text.trim(),
                  lastName: lastNameController.text.trim(),
                  email: emailController.text.trim(),
                  phone: phoneController.text.trim(),
                  hireDate: hireDate,
                  maxWeeklyHours:
                      double.tryParse(maxHoursController.text) ?? 48,
                  preferredAreas: allowedAreas.toList(),
                  isActive: isActive,
                  employeeCode: codeController.text.trim(),
                  notes: notesController.text.trim(),
                  authUid: authUid,
                  createdAt: employee?.createdAt ?? DateTime.now(),
                );
                await ref.read(employeesViewModelProvider.notifier).save(saved);

                // Apply role change on the login profile ('admin' grants full
                // schedule/employee management access, 'employee' revokes it).
                if (authUid.isNotEmpty && selectedRole != initialRole) {
                  try {
                    await accountService.updateUserRole(
                        authUid, selectedRole);
                  } catch (err) {
                    messenger.showSnackBar(SnackBar(
                      content: Text(l10n.errorPrefix('$err')),
                      backgroundColor: Colors.orange,
                    ));
                  }
                }
                messenger.showSnackBar(SnackBar(
                    content: Text(l10n.employeeSaved)));
                navigator.pop();
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
