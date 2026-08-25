import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/schedule_generator.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/scheduling_assistant_commands.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';

/// Executes structured AI commands on an IN-MEMORY COPY of the schedule,
/// then validates the result with the ConflictDetector and CoverageCalculator.
/// It never writes to Firestore - the returned proposal must be approved by
/// the admin before it is applied through the normal scheduler path.
class AssistantEngine {
  final SystemSettings settings;
  final List<Employee> employees;
  final List<ReceptionArea> areas;
  final List<StaffingRequirementEntity> requirements;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;
  final WeeklySchedule baseSchedule;
  final String currentUserId;

  const AssistantEngine({
    required this.settings,
    required this.employees,
    required this.areas,
    required this.requirements,
    this.availabilities = const [],
    this.leaves = const [],
    required this.baseSchedule,
    required this.currentUserId,
  });

  AssistantProposal execute(List<SchedulingCommand> commands) {
    var assignments =
        baseSchedule.assignments.map((a) => _clone(a)).toList();
    final added = <ScheduleAssignment>[];
    final removed = <ScheduleAssignment>[];
    final modified = <(ScheduleAssignment, ScheduleAssignment)>[];
    final explanations = <String>[];

    for (final command in commands) {
      switch (command) {
        case SetDayOffCommand c:
          removed.addAll(assignments.where((a) =>
              a.employeeId == c.employeeId && _sameDay(a.scheduledDate, c.date)));
          assignments = assignments
              .where((a) =>
                  !(a.employeeId == c.employeeId &&
                      _sameDay(a.scheduledDate, c.date)))
              .toList();
          explanations.add(
              '${removed.length} assignment(s) removed for ${c.employeeName} on ${_d(c.date)}');

        case MoveAssignmentAreaCommand c:
          for (var i = 0; i < assignments.length; i++) {
            final a = assignments[i];
            if (a.employeeId == c.employeeId &&
                _sameDay(a.scheduledDate, c.date) &&
                (c.fromAreaId == null || a.areaId == c.fromAreaId)) {
              final updated = a.copyWith(areaId: c.newAreaId);
              modified.add((a, updated));
              assignments[i] = updated;
            }
          }
          if (modified.isEmpty) {
            explanations.add(
                'No matching assignment found for ${c.employeeName} on ${_d(c.date)}.');
          }

        case AddCoverageCommand c:
          final picked = _pickForCoverage(c, assignments);
          for (final emp in picked) {
            final start = DateTime(c.date.year, c.date.month, c.date.day,
                c.startMinute ~/ 60, c.startMinute % 60);
            var end = DateTime(c.date.year, c.date.month, c.date.day,
                c.endMinute ~/ 60, c.endMinute % 60);
            if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
            final newAssignment = ScheduleAssignment(
              id: const Uuid().v4(),
              employeeId: emp.id,
              areaId: c.areaId,
              scheduledDate: DateTime(c.date.year, c.date.month, c.date.day),
              startDateTime: start,
              endDateTime: end,
              status: AssignmentStatus.draft,
              createdBy: currentUserId,
              updatedBy: currentUserId,
              notes: 'Added via AI assistant',
            );
            assignments.add(newAssignment);
            added.add(newAssignment);
          }
          explanations.add(picked.isEmpty
              ? 'No eligible employee available for the requested coverage.'
              : '${picked.map((e) => e.fullName).join(', ')} assigned for extra coverage.');

        case RestrictNightShiftsCommand c:
          final before = assignments.length;
          removed.addAll(assignments.where((a) =>
              a.employeeId == c.employeeId &&
              (a.isOvernight || a.startDateTime.hour >= 21)));
          assignments = assignments
              .where((a) =>
                  !(a.employeeId == c.employeeId &&
                      (a.isOvernight || a.startDateTime.hour >= 21)))
              .toList();
          explanations.add(
              '${before - assignments.length} night assignment(s) removed for ${c.employeeName}.');

        case GenerateBestScheduleCommand c:
          final generator = ScheduleGenerator(
            settings: settings,
            employees: employees,
            areas: areas,
            requirements: requirements,
            availabilities: availabilities,
            leaves: leaves,
            fixedAssignments: const [],
            weekStart: DateTimeUtils.getStartOfWeek(c.weekStart),
            createdBy: currentUserId,
          );
          final result = generator.generate();
          removed.addAll(assignments);
          added.addAll(result.draft.assignments);
          assignments = List.from(result.draft.assignments);
          explanations.add(
              'Schedule regenerated by the smart generator '
              '(coverage ${result.coverageReport.coveragePercentage.toStringAsFixed(1)}%).');
      }
    }

    // ---- Validation with the SAME engines the scheduler uses ----
    final detector = ConflictDetector(
      settings: settings,
      areas: areas,
      employees: employees,
      availabilities: availabilities,
      leaves: leaves,
      staffingRequirements: requirements,
    );
    final conflictsMap = detector.validateSchedule(assignments);
    final conflicts = <ScheduleConflict>{};
    for (final c in conflictsMap.values) {
      conflicts.addAll(c);
    }
    final staffingConflicts = detector.detectStaffingGaps(assignments);
    final coverage = const CoverageCalculator().calculateForWeek(
      weekStart: DateTimeUtils.getStartOfWeek(baseSchedule.weekStartDate),
      assignments: assignments,
      requirements: requirements,
    );

    final proposedDraft = baseSchedule.copyWith(assignments: assignments);

    return AssistantProposal(
      commands: commands,
      proposedDraft: proposedDraft,
      added: added,
      removed: removed,
      modified: modified,
      conflicts: conflicts.toList(),
      staffingConflicts: staffingConflicts,
      coverage: coverage,
      explanations: explanations,
      isFullyValid: conflicts
              .where((c) => c.severity == ConflictSeverity.error)
              .isEmpty &&
          staffingConflicts.isEmpty,
    );
  }

  /// Chooses eligible employees for extra coverage using the generator's own
  /// scoring so fairness and hard rules are respected.
  List<Employee> _pickForCoverage(
      AddCoverageCommand c, List<ScheduleAssignment> working) {
    final generator = ScheduleGenerator(
      settings: settings,
      employees: employees,
      areas: areas,
      requirements: requirements,
      availabilities: availabilities,
      leaves: leaves,
      weekStart: baseSchedule.weekStartDate,
      createdBy: currentUserId,
    );

    final start = DateTime(c.date.year, c.date.month, c.date.day,
        c.startMinute ~/ 60, c.startMinute % 60);
    var end = DateTime(c.date.year, c.date.month, c.date.day,
        c.endMinute ~/ 60, c.endMinute % 60);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));

    final scored = <(double, Employee)>[];
    for (final e in employees) {
      // Skip anyone already working during the window.
      final busy = working.any((a) =>
          a.employeeId == e.id &&
          a.startDateTime.isBefore(end) &&
          start.isBefore(a.endDateTime));
      if (busy) continue;
      final score =
          generator.scoreCandidateForWindow(e, start, end, c.areaId, working);
      if (score != null) scored.add((score, e));
    }
    scored.sort((x, y) => x.$1.compareTo(y.$1));
    return scored.take(c.count).map((s) => s.$2).toList();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  ScheduleAssignment _clone(ScheduleAssignment a) => ScheduleAssignment(
        id: a.id,
        employeeId: a.employeeId,
        areaId: a.areaId,
        scheduledDate: a.scheduledDate,
        startDateTime: a.startDateTime,
        endDateTime: a.endDateTime,
        shiftTemplateId: a.shiftTemplateId,
        status: a.status,
        notes: a.notes,
        createdBy: a.createdBy,
        updatedBy: currentUserId,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
      );

  String _d(DateTime d) => '${d.day}/${d.month}';
}

class AssistantProposal {
  final List<SchedulingCommand> commands;
  final WeeklySchedule proposedDraft;
  final List<ScheduleAssignment> added;
  final List<ScheduleAssignment> removed;
  final List<(ScheduleAssignment, ScheduleAssignment)> modified;
  final List<ScheduleConflict> conflicts;
  final List<ScheduleConflict> staffingConflicts;
  final WeekCoverageResult coverage;
  final List<String> explanations;
  final bool isFullyValid;

  const AssistantProposal({
    required this.commands,
    required this.proposedDraft,
    required this.added,
    required this.removed,
    required this.modified,
    required this.conflicts,
    required this.staffingConflicts,
    required this.coverage,
    required this.explanations,
    required this.isFullyValid,
  });
}
