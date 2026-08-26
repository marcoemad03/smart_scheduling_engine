import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

class BulkAssignDialog extends ConsumerStatefulWidget {
  final DateTime date;
  final List<Employee> employees;
  final List<ReceptionArea> areas;

  const BulkAssignDialog({
    Key? key,
    required this.date,
    required this.employees,
    required this.areas,
  }) : super(key: key);

  @override
  ConsumerState<BulkAssignDialog> createState() => _BulkAssignDialogState();
}

class _BulkAssignDialogState extends ConsumerState<BulkAssignDialog> {
  final Set<String> selectedEmployeeIds = {};
  String? areaId;
  TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 16, minute: 0);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.bulkAssignTitle),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: areaId,
              decoration: InputDecoration(labelText: l10n.colArea),
              items: widget.areas
                  .map((a) => DropdownMenuItem(
                        value: a.areaId, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => areaId = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: startTime);
                      if (t != null) setState(() => startTime = t);
                    },
                    child: InputDecorator(
                      decoration:
                          InputDecoration(labelText: l10n.startTime),
                      child: Text(startTime.format(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: context, initialTime: endTime);
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
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l10n.selectEmployees,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: widget.employees.length,
                itemBuilder: (context, index) {
                  final e = widget.employees[index];
                  final selected = selectedEmployeeIds.contains(e.id);
                  return CheckboxListTile(
                    value: selected,
                    title: Text(e.fullName),
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          selectedEmployeeIds.add(e.id);
                        } else {
                          selectedEmployeeIds.remove(e.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (areaId == null || selectedEmployeeIds.isEmpty) return;
            ref.read(schedulerViewModelProvider.notifier).bulkAssign(
                  employeeIds: selectedEmployeeIds.toList(),
                  areaId: areaId!,
                  date: widget.date,
                  startTime: startTime,
                  endTime: endTime,
                );
            Navigator.of(context).pop();
          },
          child: Text(l10n.assign),
        ),
      ],
    );
  }
}

class TemplateDialog extends ConsumerStatefulWidget {
  final List<Employee> employees;
  final List<ReceptionArea> areas;

  const TemplateDialog({
    Key? key,
    required this.employees,
    required this.areas,
  }) : super(key: key);

  @override
  ConsumerState<TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<TemplateDialog> {
  final TextEditingController nameController = TextEditingController();
  bool saveMode = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.scheduleTemplate),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.saveTemplate)),
                ButtonSegment(value: false, label: Text(l10n.applyTemplate)),
              ],
              selected: {saveMode},
              onSelectionChanged: (s) => setState(() => saveMode = s.first),
            ),
            const SizedBox(height: 16),
            if (saveMode)
              TextField(
                controller: nameController,
                decoration:
                    InputDecoration(labelText: l10n.templateName),
              )
            else
              Text(l10n.applyTemplateQuestion),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (saveMode) {
              if (nameController.text.isEmpty) return;
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .saveAsTemplate(nameController.text);
            }
            Navigator.of(context).pop();
          },
          child: Text(saveMode ? l10n.save : l10n.apply),
        ),
      ],
    );
  }
}
