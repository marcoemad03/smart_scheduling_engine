import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.assignment != null;
    final selectedEmployee = widget.employees
        .where((e) => e.id == employeeId)
        .firstOrNull;
    final selectedArea = widget.areas.where((a) => a.areaId == areaId).firstOrNull;
    final areaNotAllowed = selectedEmployee != null &&
        selectedArea != null &&
        !selectedEmployee.isAllowedInArea(selectedArea.areaId);

    return AlertDialog(
      title: Text(isEdit ? l10n.editShift : l10n.addShift),
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
                  decoration: InputDecoration(labelText: l10n.employee),
                  items: widget.employees
                      .map((e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.fullName),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => employeeId = v),
                  validator: (v) => v == null ? l10n.required : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: areaId,
                  decoration: InputDecoration(labelText: l10n.colArea),
                  items: widget.areas.map((a) {
                    final allowed =
                        selectedEmployee?.isAllowedInArea(a.areaId) ?? true;
                    return DropdownMenuItem(
                      value: a.areaId,
                      child: Text(
                        a.name +
                            (a.isActive ? '' : ' ${l10n.inactiveArea}') +
                            (allowed
                                ? ''
                                : ' (${l10n.areaNotAllowedSuffix})'),
                        style: allowed
                            ? null
                            : TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => areaId = v),
                  validator: (v) => v == null ? l10n.required : null,
                ),
                if (areaNotAllowed) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.areaNotAllowedWarning(selectedArea.name),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ]),
                  ),
                ],
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
                              InputDecoration(labelText: l10n.startTime),
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
                              InputDecoration(labelText: l10n.endTime),
                          child: Text(endTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.overnightNote,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.notesOptional),
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
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? l10n.save : l10n.add),
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
