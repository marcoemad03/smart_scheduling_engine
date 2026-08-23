import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Employee {
  final String employeeId;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final DateTime hireDate;
  final double maxWeeklyHours;
  final List<String> preferredAreas;
  final bool isActive;

  Employee({
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.hireDate,
    required this.maxWeeklyHours,
    required this.preferredAreas,
    required this.isActive,
  });

  String get fullName => '$firstName $lastName';
}

class EmployeeListViewModel extends StateNotifier<AsyncValue<List<Employee>>> {
  EmployeeListViewModel() : super(const AsyncValue.loading()) {
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    state = const AsyncValue.loading();
    // Simulated data
    await Future.delayed(const Duration(milliseconds: 500));
    state = AsyncValue.data([
      Employee(
        employeeId: 'emp1',
        firstName: 'John',
        lastName: 'Smith',
        email: 'john@hospital.com',
        phone: '555-1234',
        hireDate: DateTime(2020, 1, 15),
        maxWeeklyHours: 40,
        preferredAreas: ['Emergency', 'Pharmacy'],
        isActive: true,
      ),
      Employee(
        employeeId: 'emp2',
        firstName: 'Sarah',
        lastName: 'Johnson',
        email: 'sarah@hospital.com',
        phone: '555-5678',
        hireDate: DateTime(2019, 6, 10),
        maxWeeklyHours: 35,
        preferredAreas: ['Clinics', 'Operations'],
        isActive: true,
      ),
      Employee(
        employeeId: 'emp3',
        firstName: 'Michael',
        lastName: 'Brown',
        email: 'michael@hospital.com',
        phone: '555-9012',
        hireDate: DateTime(2021, 3, 5),
        maxWeeklyHours: 48,
        preferredAreas: ['Approvals', 'Window'],
        isActive: true,
      ),
    ]);
  }
}

class EmployeeListPage extends ConsumerStatefulWidget {
  const EmployeeListPage({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends ConsumerState<EmployeeListPage> {
  String _searchTerm = '';

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeeListViewModelProvider);

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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeDialog(context, null),
        child: const Icon(Icons.add),
      ),
      body: employeesAsync.when(
        data: (employees) => _buildEmployeeList(employees),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildEmployeeList(List<Employee> employees) {
    final filtered = employees.where((e) => 
      e.firstName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
      e.lastName.toLowerCase().contains(_searchTerm.toLowerCase()) ||
      e.email.toLowerCase().contains(_searchTerm.toLowerCase())
    ).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text('No employees found'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 768;
        
        if (isDesktop) {
          return _buildDataTable(context, filtered);
        } else {
          return _buildMobileList(context, filtered);
        }
      }
    );
  }

  Widget _buildDataTable(BuildContext context, List<Employee> employees) {
    return PaginatedDataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Hire Date')),
        DataColumn(label: Text('Max Hours')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Actions')),
      ],
      source: EmployeeDataSource(context, employees, ref),
      rowsPerPage: 10,
    );
  }

  Widget _buildMobileList(BuildContext context, List<Employee> employees) {
    return ListView.builder(
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final employee = employees[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(employee.firstName.substring(0, 1)),
            ),
            title: Text(employee.fullName),
            subtitle: Text('${employee.email} • ${employee.phone}'),
            trailing: Switch(
              value: employee.isActive,
              onChanged: (value) => _toggleEmployeeStatus(employee, value),
            ),
            onTap: () => _showEmployeeDialog(context, employee),
          ),
        );
      },
    );
  }

  void _toggleEmployeeStatus(Employee employee, bool value) {
    // Update employee status
  }

  void _showEmployeeDialog(BuildContext context, Employee? employee) {
    final firstNameController = TextEditingController(text: employee?.firstName ?? '');
    final lastNameController = TextEditingController(text: employee?.lastName ?? '');
    final emailController = TextEditingController(text: employee?.email ?? '');
    final phoneController = TextEditingController(text: employee?.phone ?? '');
    final maxHoursController = TextEditingController(text: employee?.maxWeeklyHours.toString() ?? '40');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(employee == null ? 'Add Employee' : 'Edit Employee'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(labelText: 'First Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: maxHoursController,
                  decoration: const InputDecoration(labelText: 'Max Weekly Hours'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(employee == null ? 'Employee added' : 'Employee updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

final employeeListViewModelProvider = 
    StateNotifierProvider<EmployeeListViewModel, AsyncValue<List<Employee>>>(
  (ref) => EmployeeListViewModel(),
);

class EmployeeDataSource extends DataTableSource {
  final BuildContext context;
  final List<Employee> employees;
  final WidgetRef ref;

  EmployeeDataSource(this.context, this.employees, this.ref);

  @override
  DataRow? getRow(int index) {
    if (index >= employees.length) return null;
    final employee = employees[index];
    return DataRow(
      cells: [
        DataCell(Text(employee.fullName)),
        DataCell(Text(employee.email)),
        DataCell(Text(employee.hireDate.toLocal().toString().split(' ')[0])),
        DataCell(Text('${employee.maxWeeklyHours.toInt()}h')),
        DataCell(Chip(
          label: Text(employee.isActive ? 'Active' : 'Inactive'),
          backgroundColor: employee.isActive 
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
        )),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
              iconSize: 18,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () {},
              iconSize: 18,
            ),
          ],
        )),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => employees.length;

  @override
  int get selectedRowCount => 0;
}

final employeeRepositoryProvider = Provider((ref) => null);

