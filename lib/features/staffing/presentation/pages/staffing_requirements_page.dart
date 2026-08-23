import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

class StaffingRequirement {
  final String requirementId;
  final String areaId;
  final int dayOfWeek;
  final int requiredCount;
  final String? shiftTemplateId;
  final int minHoursPerWeek;

  StaffingRequirement({
    required this.requirementId,
    required this.areaId,
    required this.dayOfWeek,
    required this.requiredCount,
    this.shiftTemplateId,
    required this.minHoursPerWeek,
  });

  StaffingRequirement copyWith({
    String? requirementId,
    String? areaId,
    int? dayOfWeek,
    int? requiredCount,
    String? shiftTemplateId,
    int? minHoursPerWeek,
  }) {
    return StaffingRequirement(
      requirementId: requirementId ?? this.requirementId,
      areaId: areaId ?? this.areaId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      requiredCount: requiredCount ?? this.requiredCount,
      shiftTemplateId: shiftTemplateId ?? this.shiftTemplateId,
      minHoursPerWeek: minHoursPerWeek ?? this.minHoursPerWeek,
    );
  }
}

class StaffingRequirementsPage extends ConsumerStatefulWidget {
  const StaffingRequirementsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffingRequirementsPage> createState() => _StaffingRequirementsPageState();
}

class _StaffingRequirementsPageState extends ConsumerState<StaffingRequirementsPage> {
  final List<StaffingRequirement> _requirements = [
    StaffingRequirement(
      requirementId: 'req1',
      areaId: 'Emergency',
      dayOfWeek: 1,
      requiredCount: 3,
      shiftTemplateId: 'day',
      minHoursPerWeek: 35,
    ),
  ];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<ShiftOption> _shifts = [
    ShiftOption(id: 'day', name: 'Day Shift (08:00 → 15:00)'),
    ShiftOption(id: 'evening', name: 'Evening Shift (15:00 → 22:00)'),
    ShiftOption(id: 'night', name: 'Night Shift (22:00 → 08:00)'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(title: const Text('Staffing Requirements')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRequirementDialog,
        child: const Icon(Icons.add),
      ),
      body: isDesktop ? _buildDesktopView() : _buildMobileView(),
    );
  }

  Widget _buildDesktopView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          child: const Center(child: Text('Staffing Overview')),
        ),
        Expanded(child: _buildRequirementsTable()),
      ],
    );
  }

  Widget _buildMobileView() {
    return _buildRequirementsList();
  }

  Widget _buildRequirementsTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Area')),
          DataColumn(label: Text('Day')),
          DataColumn(label: Text('Required')),
          DataColumn(label: Text('Shift')),
          DataColumn(label: Text('Min Hours/Week')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _requirements.map((req) {
          return DataRow(cells: [
            DataCell(Text(req.areaId)),
            DataCell(Text(_days[req.dayOfWeek])),
            DataCell(Text('${req.requiredCount}')),
            DataCell(Text(_getShiftName(req.shiftTemplateId))),
            DataCell(Text('${req.minHoursPerWeek}')),
            DataCell(Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showRequirementDialog(requirement: req),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteRequirement(req),
                ),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildRequirementsList() {
    if (_requirements.isEmpty) {
      return const Center(child: Text('No requirements defined'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _requirements.length,
      itemBuilder: (context, index) {
        final req = _requirements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text('${req.areaId} - ${_days[req.dayOfWeek]}'),
            subtitle: Text('Required: ${req.requiredCount} • Min hours: ${req.minHoursPerWeek}'),
            trailing: IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMobileOptions(context, req),
            ),
          ),
        );
      },
    );
  }

  String _getShiftName(String? shiftId) {
    if (shiftId == null) return 'None';
    final match = _shifts.firstWhere((s) => s.id == shiftId, orElse: () => ShiftOption(id: '', name: 'Unknown'));
    return match.name;
  }

  void _showMobileOptions(BuildContext context, StaffingRequirement requirement) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showRequirementDialog(requirement: requirement);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _requirements.add(requirement.copyWith(requirementId: const Uuid().v4())));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRequirementDialog({StaffingRequirement? requirement}) {
    final areaController = TextEditingController(text: requirement?.areaId ?? '');
    final countController = TextEditingController(text: requirement?.requiredCount.toString() ?? '');
    final minHoursController = TextEditingController(text: requirement?.minHoursPerWeek.toString() ?? '');

    String selectedDay = (requirement?.dayOfWeek ?? 1).toString();
    String selectedShift = requirement?.shiftTemplateId ?? 'day';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(requirement == null ? 'Add Requirement' : 'Edit Requirement'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  items: _days.asMap().entries.map((e) => DropdownMenuItem(
                    value: (e.key + 1).toString(),
                    child: Text(e.value),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedDay = val!),
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedShift,
                  items: _shifts.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedShift = val!),
                  decoration: const InputDecoration(labelText: 'Shift Template'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: areaController,
                  decoration: const InputDecoration(labelText: 'Area'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: countController,
                  decoration: const InputDecoration(labelText: 'Required Count'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: minHoursController,
                  decoration: const InputDecoration(labelText: 'Minimum Hours Per Week'),
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
              final newReq = StaffingRequirement(
                requirementId: requirement?.requirementId ?? const Uuid().v4(),
                areaId: areaController.text.trim(),
                dayOfWeek: int.parse(selectedDay),
                requiredCount: int.parse(countController.text),
                shiftTemplateId: selectedShift,
                minHoursPerWeek: int.parse(minHoursController.text),
              );
              setState(() {
                if (requirement == null) {
                  _requirements.add(newReq);
                } else {
                  _requirements[_requirements.indexOf(requirement)] = newReq;
                }
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteRequirement(StaffingRequirement requirement) {
    setState(() => _requirements.remove(requirement));
  }
}

class ShiftOption {
  final String id;
  final String name;
  ShiftOption({required this.id, required this.name});
}