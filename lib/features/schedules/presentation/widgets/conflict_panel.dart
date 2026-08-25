import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

class ConflictPanel extends ConsumerWidget {
  final List<ScheduleConflict> conflicts;
  final Map<String, String> employeeNames;
  final Map<String, String> areaNames;

  const ConflictPanel({
    Key? key,
    required this.conflicts,
    required this.employeeNames,
    required this.areaNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.read(schedulerViewModelProvider.notifier);
    final overridden = ref.watch(schedulerViewModelProvider
        .select((s) => s.overriddenAssignmentIds));

    if (conflicts.isEmpty) {
      return const Card(
        color: Colors.green,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('No conflicts detected',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    return Card(
      color: Colors.orange.shade50,
      child: ExpansionTile(
        leading: Badge(
          label: Text('${conflicts.length}'),
          child: const Icon(Icons.warning_amber_rounded),
        ),
        title: const Text('Conflicts Detected'),
        children: conflicts.map((c) {
          final isOverridden = c.assignmentId1 != null &&
              overridden.contains(c.assignmentId1);
          return ListTile(
            leading: Icon(
              c.severity == ConflictSeverity.error
                  ? Icons.error
                  : Icons.warning,
              color: c.severity == ConflictSeverity.error
                  ? Colors.red
                  : Colors.orange,
            ),
            title: Text(c.message),
            subtitle: Text(
              _contextLabel(c),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: isOverridden
                ? const Chip(
                    label: Text('Overridden'),
                    backgroundColor: Colors.green,
                  )
                : c.isOverrideAllowed
                    ? TextButton(
                        onPressed: c.assignmentId1 != null
                            ? () => vm.overrideConflict(c.assignmentId1!)
                            : null,
                        child: const Text('Allow Override'),
                      )
                    : null,
          );
        }).toList(),
      ),
    );
  }

  String _contextLabel(ScheduleConflict c) {
    final parts = <String>[];
    if (c.employeeId != null) {
      parts.add('Employee: ${employeeNames[c.employeeId] ?? c.employeeId}');
    }
    if (c.areaId != null) {
      parts.add('Area: ${areaNames[c.areaId] ?? c.areaId}');
    }
    return parts.join(' • ');
  }
}
