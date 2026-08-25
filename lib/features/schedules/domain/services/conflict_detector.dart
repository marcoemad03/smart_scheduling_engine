import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';

class ScheduleConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final String? employeeId;
  final String? areaId;
  final String? assignmentId1;
  final String? assignmentId2;
  final String message;
  final bool isOverrideAllowed;

  ScheduleConflict({
    required this.id,
    required this.type,
    required this.severity,
    this.employeeId,
    this.areaId,
    this.assignmentId1,
    this.assignmentId2,
    required this.message,
    this.isOverrideAllowed = true,
  });
}

class ConflictDetector {
  final SystemSettings settings;
  final List<ReceptionArea> areas;
  final List<Employee> employees;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;
  final List<StaffingRequirementEntity> staffingRequirements;

  ConflictDetector({
    required this.settings,
    required this.areas,
    required this.employees,
    required this.availabilities,
    required this.leaves,
    required this.staffingRequirements,
  });

  ReceptionArea? _getArea(String areaId) =>
      areas.where((a) => a.areaId == areaId).firstOrNull;

  Employee? _getEmployee(String employeeId) =>
      employees.where((e) => e.id == employeeId).firstOrNull;

  List<ScheduleConflict> detectAssignmentConflicts(
    ScheduleAssignment assignment,
    List<ScheduleAssignment> existing,
  ) {
    final conflicts = <ScheduleConflict>[];
    final others =
        existing.where((a) => a.id != assignment.id).toList();

    conflicts.addAll(_detectEmployeeTimeOverlap(assignment, others));
    // NOTE: multiple employees may legitimately share an area simultaneously
    // (configurable staffing counts), so same-area overlap is NOT a conflict.
    conflicts.addAll(_detectRestPeriodViolation(assignment, others));
    conflicts.addAll(_detectMaxHoursViolation(assignment, others));
    conflicts.addAll(_detectAvailabilityConflict(assignment));
    conflicts.addAll(_detectLeaveConflict(assignment));
    conflicts.addAll(_detectInactiveArea(assignment));
    conflicts.addAll(_detectNotQualifiedArea(assignment));
    conflicts.addAll(_detectConsecutiveDays(assignment, others));

    return conflicts;
  }

  Map<String, List<ScheduleConflict>> validateSchedule(
    List<ScheduleAssignment> assignments,
  ) {
    final result = <String, List<ScheduleConflict>>{};
    for (final assignment in assignments) {
      result[assignment.id] = detectAssignmentConflicts(assignment, assignments);
    }
    return result;
  }

  List<ScheduleConflict> detectStaffingGaps(
    List<ScheduleAssignment> assignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    if (assignments.isEmpty || staffingRequirements.isEmpty) {
      return conflicts;
    }
    final calculator = const CoverageCalculator();
    final weekStart = DateTimeUtils.getStartOfWeek(
        assignments.map((a) => a.scheduledDate).reduce(
            (a, b) => a.isBefore(b) ? a : b));
    final week = calculator.calculateForWeek(
      weekStart: weekStart,
      assignments: assignments,
      requirements: staffingRequirements,
    );
    for (final day in week.days) {
      for (final interval in day.intervals) {
        if (interval.missingCount > 0) {
          final dateLabel =
              '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
          conflicts.add(ScheduleConflict(
            id: const Uuid().v4(),
            type: ConflictType.staffingNotSatisfied,
            severity: ConflictSeverity.warning,
            areaId: interval.areaId,
            message:
                'Staffing shortage on $dateLabel in area "${_getArea(interval.areaId)?.name ?? interval.areaId}" (${interval.scheduledCount}/${interval.requiredCount} covered)',
            isOverrideAllowed: true,
          ));
        }
      }
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectEmployeeTimeOverlap(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existing,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlapping = existing.where(
      (a) =>
          a.employeeId == newAssignment.employeeId &&
          newAssignment.overlapsWith(a),
    );
    for (final existing in overlapping) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.employeeTimeOverlap,
        severity: ConflictSeverity.error,
        employeeId: newAssignment.employeeId,
        assignmentId1: newAssignment.id,
        assignmentId2: existing.id,
        message: 'Employee already scheduled during this time',
      ));
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectRestPeriodViolation(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existing,
  ) {
    final conflicts = <ScheduleConflict>[];
    final employeeAssignments = existing.where(
      (a) => a.employeeId == newAssignment.employeeId,
    );
    for (final existing in employeeAssignments) {
      if (newAssignment.overlapsWith(existing)) continue;
      final gapBefore =
          newAssignment.startDateTime.difference(existing.endDateTime).inMinutes;
      final gapAfter =
          existing.startDateTime.difference(newAssignment.endDateTime).inMinutes;
      final gap = newAssignment.startDateTime.isAfter(existing.endDateTime)
          ? gapBefore
          : gapAfter;
      if (gap.abs() < settings.minRestPeriodMinutes && gap != 0) {
        conflicts.add(ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.insufficientRest,
          severity: ConflictSeverity.warning,
          employeeId: newAssignment.employeeId,
          assignmentId1: newAssignment.id,
          assignmentId2: existing.id,
          message:
              'Insufficient rest period (${gap.abs()} mins < ${settings.minRestPeriodMinutes} mins required)',
        ));
      }
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectMaxHoursViolation(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existing,
  ) {
    final conflicts = <ScheduleConflict>[];
    final weekStart = DateTimeUtils.getStartOfWeek(newAssignment.scheduledDate);
    final employeeAssignments = existing.where(
      (a) =>
          a.employeeId == newAssignment.employeeId &&
          a.scheduledDate.isAfter(weekStart.subtract(const Duration(days: 1))) &&
          a.scheduledDate
              .isBefore(weekStart.add(const Duration(days: 7))),
    );
    final totalHours = employeeAssignments.fold<double>(
            0, (sum, a) => sum + a.duration.inHours.toDouble()) +
        newAssignment.duration.inHours.toDouble();

    final employee = _getEmployee(newAssignment.employeeId);
    final limit = employee?.maxWeeklyHours ?? settings.maxWeeklyHours;

    if (totalHours > limit) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.maxHoursExceeded,
        severity: ConflictSeverity.error,
        employeeId: newAssignment.employeeId,
        assignmentId1: newAssignment.id,
        message:
            'Exceeds maximum weekly hours ($totalHours > ${limit.toStringAsFixed(1)})',
      ));
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectAvailabilityConflict(
    ScheduleAssignment newAssignment,
  ) {
    final conflicts = <ScheduleConflict>[];
    final employeeUnavailable = availabilities.where(
      (a) =>
          a.employeeId == newAssignment.employeeId &&
          a.isAvailable == false &&
          newAssignment.startDateTime.isAfter(a.startDateTime) &&
          newAssignment.endDateTime.isBefore(a.endDateTime),
    );
    if (employeeUnavailable.isNotEmpty) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.availabilityConflict,
        severity: ConflictSeverity.error,
        employeeId: newAssignment.employeeId,
        assignmentId1: newAssignment.id,
        message: 'Employee marked unavailable during this time',
      ));
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectLeaveConflict(
    ScheduleAssignment newAssignment,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlappingLeaves = leaves.where(
      (l) =>
          l.employeeId == newAssignment.employeeId &&
          l.status == LeaveStatus.approved &&
          newAssignment.startDateTime.isAfter(l.startDateTime) &&
          newAssignment.endDateTime.isBefore(l.endDateTime),
    );
    if (overlappingLeaves.isNotEmpty) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.leaveConflict,
        severity: ConflictSeverity.error,
        employeeId: newAssignment.employeeId,
        assignmentId1: newAssignment.id,
        message: 'Employee has approved leave during this time',
      ));
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectConsecutiveDays(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existing,
  ) {
    final limit = settings.maxConsecutiveWorkingDays;
    if (limit <= 0) return [];

    final dates = <DateTime>{
      DateTime(
        newAssignment.scheduledDate.year,
        newAssignment.scheduledDate.month,
        newAssignment.scheduledDate.day,
      ),
      ...existing
          .where((a) => a.employeeId == newAssignment.employeeId)
          .map((a) => DateTime(
                a.scheduledDate.year,
                a.scheduledDate.month,
                a.scheduledDate.day,
              )),
    }.toList()
      ..sort();

    // Walk backwards from the assignment date to measure the streak length.
    var streak = 1;
    final target = DateTime(
      newAssignment.scheduledDate.year,
      newAssignment.scheduledDate.month,
      newAssignment.scheduledDate.day,
    );
    var cursor = target;
    final dateSet = dates.toSet();
    while (dateSet.contains(cursor.subtract(const Duration(days: 1)))) {
      cursor = cursor.subtract(const Duration(days: 1));
      streak++;
    }

    if (streak > limit) {
      return [
        ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.consecutiveDaysExceeded,
          severity: ConflictSeverity.warning,
          employeeId: newAssignment.employeeId,
          assignmentId1: newAssignment.id,
          message:
              'Employee works $streak consecutive days (max $limit allowed)',
        )
      ];
    }
    return [];
  }

  List<ScheduleConflict> _detectInactiveArea(
    ScheduleAssignment newAssignment,
  ) {
    final area = _getArea(newAssignment.areaId);
    if (area != null && !area.isActive) {
      return [
        ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.inactiveArea,
          severity: ConflictSeverity.error,
          areaId: newAssignment.areaId,
          assignmentId1: newAssignment.id,
          message: 'Area "${area.name}" is inactive',
        )
      ];
    }
    return [];
  }

  List<ScheduleConflict> _detectNotQualifiedArea(
    ScheduleAssignment newAssignment,
  ) {
    final employee = _getEmployee(newAssignment.employeeId);
    if (employee != null &&
        employee.preferredAreas.isNotEmpty &&
        !employee.preferredAreas.contains(newAssignment.areaId)) {
      final area = _getArea(newAssignment.areaId);
      return [
        ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.notQualifiedArea,
          severity: ConflictSeverity.warning,
          employeeId: newAssignment.employeeId,
          areaId: newAssignment.areaId,
          assignmentId1: newAssignment.id,
          message:
              'Employee not qualified/allowed for area "${area?.name ?? newAssignment.areaId}"',
        )
      ];
    }
    return [];
  }
}
