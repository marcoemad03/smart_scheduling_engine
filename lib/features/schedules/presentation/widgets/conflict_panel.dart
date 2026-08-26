import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
      final l10n = AppLocalizations.of(context)!;
      return Card(
        color: Colors.green,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(l10n.noConflictsDetected,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Colors.orange.shade50,
      child: ExpansionTile(
        leading: Badge(
          label: Text('${conflicts.length}'),
          child: const Icon(Icons.warning_amber_rounded),
        ),
        title: Text(l10n.conflictsDetected),
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
              _contextLabel(l10n, c),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: isOverridden
                ? Chip(
                    label: Text(l10n.overridden),
                    backgroundColor: Colors.green,
                  )
                : c.isOverrideAllowed
                    ? TextButton(
                        onPressed: c.assignmentId1 != null
                            ? () => vm.overrideConflict(c.assignmentId1!)
                            : null,
                        child: Text(l10n.allowOverride),
                      )
                    : null,
          );
        }).toList(),
      ),
    );
  }

  String _contextLabel(AppLocalizations l10n, ScheduleConflict c) {
    final parts = <String>[];
    if (c.employeeId != null) {
      parts.add(
          l10n.employeeColon(employeeNames[c.employeeId] ?? c.employeeId ?? ''));
    }
    if (c.areaId != null) {
      parts.add(l10n.areaColon(areaNames[c.areaId] ?? c.areaId ?? ''));
    }
    return parts.join(' • ');
  }
}
