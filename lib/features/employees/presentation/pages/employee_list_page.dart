import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/data/employees_repository.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

class EmployeeListPage extends ConsumerStatefulWidget {
  const EmployeeListPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends ConsumerState<EmployeeListPage> {
  String _searchTerm = '';
  bool _showInactive = true;

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 240,
              child: SearchBar(
                hintText: 'Search employees...',
                onChanged: (value) => setState(() => _searchTerm = value),
                leading: const Icon(Icons.search_outlined),
              ),
            ),
          ),
          IconButton(
            tooltip: _showInactive ? 'Hide inactive' : 'Show inactive',
            icon: Icon(_showInactive
                ? Icons.visibility
                : Icons.visibility_off),
            onPressed: () =>
                setState(() => _showInactive = !_showInactive),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
        onPressed: () => _showEmployeeDialog(context, null),
      ),
      body: employeesAsync.when(
        data: (employees) {
          final filtered = employees.where((e) {
            if (!_showInactive && !e.isActive) return false;
            final q = _searchTerm.toLowerCase();
            return e.fullName.toLowerCase().contains(q) ||
                e.email.toLowerCase().contains(q) ||
                e.employeeCode.toLowerCase().contains(q);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No employees found'));
          }

          final isDesktop = MediaQuery.of(context).size.width > 768;
          return RefreshIndicator(
            onRefresh: () async {},
            child: isDesktop
                ? ListView(padding: const EdgeInsets.all(16), children: [
                    _table(context, filtered)
                  ])
                : _mobileList(context, filtered),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _table(BuildContext context, List<Employee> employees) {
    return DataTable(
      columns: const [
        DataColumn(label: Text('Code')),
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Max Hours')),
        DataColumn(label: Text('Allowed Areas')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Actions')),
      ],
      rows: employees.map((e) {
        return DataRow(cells: [
          DataCell(Text(e.employeeCode.isEmpty ? '-' : e.employeeCode)),
          DataCell(Text(e.fullName)),
          DataCell(Text(e.email)),
          DataCell(Text('${e.maxWeeklyHours.toStringAsFixed(0)}h')),
          DataCell(Text(e.preferredAreas.isEmpty
              ? 'All areas'
              : e.preferredAreas.join(', '))),
          DataCell(_statusChip(context, e.isActive)),
          DataCell(Row(children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _showEmployeeDialog(context, e),
            ),
            IconButton(
              tooltip: e.isActive ? 'Deactivate' : 'Activate',
              icon: Icon(
                e.isActive ? Icons.toggle_on : Icons.toggle_off,
                size: 22,
                color: e.isActive ? Colors.green : Colors.grey,
              ),
              onPressed: () => ref
                  .read(employeesViewModelProvider.notifier)
                  .setActive(e, !e.isActive),
            ),
          ])),
        ]);
      }).toList(),
    );
  }

  Widget _mobileList(BuildContext context, List<Employee> employees) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(employee.firstName.isNotEmpty
                  ? employee.firstName.substring(0, 1)
                  : '?'),
            ),
            title: Text(employee.fullName),
            subtitle: Text(
                '${employee.employeeCode} • ${employee.email}\n${employee.maxWeeklyHours.toStringAsFixed(0)}h • ${employee.preferredAreas.isEmpty ? 'All areas' : employee.preferredAreas.join(', ')}'),
            isThreeLine: true,
            trailing: Switch(
              value: employee.isActive,
              onChanged: (value) => ref
                  .read(employeesViewModelProvider.notifier)
                  .setActive(employee, value),
            ),
            onTap: () => _showEmployeeDialog(context, employee),
          ),
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, bool isActive) {
    return Chip(
      label: Text(isActive ? 'Active' : 'Inactive'),
      backgroundColor:
          isActive ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.2),
    );
  }

  void _showEmployeeDialog(BuildContext context, Employee? employee) async {
    final vm = ref.read(employeesViewModelProvider.notifier);
    final areas = await vm.loadAreas();

    if (!mounted) return;
    final codeController = TextEditingController(
        text: employee?.employeeCode ?? await vm.nextEmployeeCode());
    final firstNameController =
        TextEditingController(text: employee?.firstName ?? '');
    final lastNameController =
        TextEditingController(text: employee?.lastName ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final phoneController = TextEditingController(text: employee?.phone ?? '');
    final maxHoursController = TextEditingController(
        text: employee?.maxWeeklyHours.toStringAsFixed(0) ?? '48');
    final notesController = TextEditingController(text: employee?.notes ?? '');
    var allowedAreas = Set<String>.from(employee?.preferredAreas ?? const []);
    var hireDate = employee?.hireDate ?? DateTime.now();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title:
              Text(employee == null ? 'Add Employee' : 'Edit Employee'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: firstNameController,
                        decoration:
                            const InputDecoration(labelText: 'First Name *'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: lastNameController,
                        decoration:
                            const InputDecoration(labelText: 'Last Name *'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                        labelText: 'Employee Code'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: maxHoursController,
                        decoration: const InputDecoration(
                            labelText: 'Max Weekly Hours'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration:
                            const InputDecoration(labelText: 'Hire Date'),
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
                          child: Text(DateFormat('MMM d, yyyy')
                              .format(hireDate)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Allowed Areas',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Leave all unchecked to allow every area.',
                          style: TextStyle(fontSize: 11, color: Colors.grey))),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: areas.map((ReceptionArea a) {
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
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                        labelText: 'Notes', alignLabelWithHint: true),
                    maxLines: 3,
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
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
                  isActive: employee?.isActive ?? true,
                  employeeCode: codeController.text.trim(),
                  notes: notesController.text.trim(),
                  createdAt: employee?.createdAt ?? DateTime.now(),
                );
                ref.read(employeesViewModelProvider.notifier).save(saved);
                Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
