import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

class AssignmentDialog extends ConsumerStatefulWidget {
  final ScheduleAssignment? assignment;
  final DateTime initialDate;
  final List<Employee> employees;
  final List<ReceptionArea> areas;

  const AssignmentDialog({
    Key? key,
    this.assignment,
    required this.initialDate,
    required this.employees,
    required this.areas,
  }) : super(key: key);

  @override
  ConsumerState<AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends ConsumerState<AssignmentDialog> {
  late String? employeeId;
  late String? areaId;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late String? shiftTemplateId;
  late TextEditingController notesController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    employeeId = a?.employeeId ?? (widget.employees.isNotEmpty ? widget.employees.first.id : null);
    areaId = a?.areaId ?? (widget.areas.isNotEmpty ? widget.areas.first.areaId : null);
    startTime = a != null
        ? TimeOfDay(hour: a.startDateTime.hour, minute: a.startDateTime.minute)
        : const TimeOfDay(hour: 8, minute: 0);
    endTime = a != null
        ? TimeOfDay(hour: a.endDateTime.hour, minute: a.endDateTime.minute)
        : const TimeOfDay(hour: 15, minute: 0);
    shiftTemplateId = a?.shiftTemplateId;
    notesController = TextEditingController(text: a?.notes ?? '');
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.assignment != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Shift' : 'Add Shift'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: employeeId,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: widget.employees
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.fullName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => employeeId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: areaId,
                  decoration: const InputDecoration(labelText: 'Area'),
                  items: widget.areas
                      .map((a) => DropdownMenuItem(
                            value: a.areaId,
                            child: Text(a.name + (a.isActive ? '' : ' (inactive)')),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => areaId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (t != null) setState(() => startTime = t);
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Start Time'),
                          child: Text(startTime.format(context)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (t != null) setState(() => endTime = t);
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'End Time'),
                          child: Text(endTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'If End Time is before Start Time, the shift is treated as overnight (next day).',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = ref.read(schedulerViewModelProvider.notifier);
    if (widget.assignment != null) {
      final updated = widget.assignment!.copyWith(
        employeeId: employeeId!,
        areaId: areaId!,
        startDateTime: _combine(widget.assignment!.scheduledDate, startTime),
        endDateTime: _combineEnd(widget.assignment!.scheduledDate, endTime, startTime),
        shiftTemplateId: shiftTemplateId,
        notes: notesController.text.isEmpty ? null : notesController.text,
      );
      await vm.updateAssignment(updated);
    } else {
      await vm.addAssignment(
        employeeId: employeeId!,
        areaId: areaId!,
        date: widget.initialDate,
        startTime: startTime,
        endTime: endTime,
        shiftTemplateId: shiftTemplateId,
        notes: notesController.text.isEmpty ? null : notesController.text,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  DateTime _combine(DateTime date, TimeOfDay t) =>
      DateTime(date.year, date.month, date.day, t.hour, t.minute);

  DateTime _combineEnd(DateTime date, TimeOfDay end, TimeOfDay start) {
    var result = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (result.isBefore(_combine(date, start)) ||
        result.isAtSameMomentAs(_combine(date, start))) {
      result = result.add(const Duration(days: 1));
    }
    return result;
  }
}
