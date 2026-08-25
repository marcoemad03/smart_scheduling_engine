import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
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
    conflicts.addAll(_detectAreaTimeOverlap(assignment, others));
    conflicts.addAll(_detectRestPeriodViolation(assignment, others));
    conflicts.addAll(_detectMaxHoursViolation(assignment, others));
    conflicts.addAll(_detectAvailabilityConflict(assignment));
    conflicts.addAll(_detectLeaveConflict(assignment));
    conflicts.addAll(_detectInactiveArea(assignment));
    conflicts.addAll(_detectNotQualifiedArea(assignment));

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
    for (final req in staffingRequirements) {
      final dayAssignments = assignments.where((a) {
        final weekday = a.scheduledDate.weekday;
        return a.areaId == req.areaId && weekday == req.dayOfWeek;
      }).toList();
      if (dayAssignments.length < req.requiredCount) {
        conflicts.add(ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.staffingNotSatisfied,
          severity: ConflictSeverity.warning,
          areaId: req.areaId,
          message:
              'Staffing requirement not met for area on day ${req.dayOfWeek}: ${dayAssignments.length}/${req.requiredCount} assigned',
          isOverrideAllowed: true,
        ));
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

  List<ScheduleConflict> _detectAreaTimeOverlap(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existing,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlapping = existing.where(
      (a) =>
          a.areaId == newAssignment.areaId &&
          newAssignment.overlapsWith(a),
    );
    for (final existing in overlapping) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.areaTimeOverlap,
        severity: ConflictSeverity.error,
        areaId: newAssignment.areaId,
        assignmentId1: newAssignment.id,
        assignmentId2: existing.id,
        message: 'Area already assigned to another employee during this time',
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
