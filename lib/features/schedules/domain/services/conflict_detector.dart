import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

class ScheduleConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final String? employeeId;
  final String? areaId;
  final String? assignmentId1;
  final String? assignmentId2;
  final String message;

  ScheduleConflict({
    required this.id,
    required this.type,
    required this.severity,
    this.employeeId,
    this.areaId,
    this.assignmentId1,
    this.assignmentId2,
    required this.message,
  });
}

class AvailabilityBlock {
  final String id;
  final String employeeId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isAvailable;
  final bool isRecurring;
  final List<int>? recurrenceDays;

  AvailabilityBlock({
    required this.id,
    required this.employeeId,
    required this.startDateTime,
    required this.endDateTime,
    required this.isAvailable,
    required this.isRecurring,
    this.recurrenceDays,
  });
}

class LeaveRequest {
  final String id;
  final String employeeId;
  final LeaveType type;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final LeaveStatus status;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.startDateTime,
    required this.endDateTime,
    required this.status,
  });
}

class StaffingRequirement {
  final String id;
  final String areaId;
  final int dayOfWeek;
  final int requiredCount;
  final String? shiftTemplateId;
  final int minHoursPerWeek;

  StaffingRequirement({
    required this.id,
    required this.areaId,
    required this.dayOfWeek,
    required this.requiredCount,
    this.shiftTemplateId,
    required this.minHoursPerWeek,
  });
}

class ReceptionArea {
  final String areaId;
  final String name;
  final String description;
  final int orderIndex;
  final bool isActive;

  ReceptionArea({
    required this.areaId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.isActive,
  });
}

class ShiftTemplate {
  final String templateId;
  final String name;
  final int startMinute;
  final int durationMinutes;
  final bool isNightShift;
  final int colorValue;
  final bool isActive;

  ShiftTemplate({
    required this.templateId,
    required this.name,
    required this.startMinute,
    required this.durationMinutes,
    required this.isNightShift,
    required this.colorValue,
    required this.isActive,
  });
}

class SystemSettings {
  final String settingsId;
  final double maxWeeklyHours;
  final int minRestPeriodMinutes;
  final int workingHoursStart;
  final int workingHoursEnd;
  final bool allowCustomSchedules;
  final bool enableAttendanceTracking;
  final String timezone;
  final int weekStartDay;
  final List<ShiftTemplate> shiftTemplates;

  SystemSettings({
    required this.settingsId,
    required this.maxWeeklyHours,
    required this.minRestPeriodMinutes,
    required this.workingHoursStart,
    required this.workingHoursEnd,
    required this.allowCustomSchedules,
    required this.enableAttendanceTracking,
    required this.timezone,
    required this.weekStartDay,
    required this.shiftTemplates,
  });
}

class ConflictDetector {
  final SystemSettings settings;

  ConflictDetector({required this.settings});

  List<ScheduleConflict> detectAllConflicts(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existingAssignments,
    List<AvailabilityBlock> availabilities,
    List<LeaveRequest> leaves,
  ) {
    final conflicts = <ScheduleConflict>[];

    conflicts.addAll(_detectEmployeeTimeOverlap(newAssignment, existingAssignments));
    conflicts.addAll(_detectAreaTimeOverlap(newAssignment, existingAssignments));
    conflicts.addAll(_detectRestPeriodViolation(newAssignment, existingAssignments));
    conflicts.addAll(_detectMaxHoursViolation(newAssignment, existingAssignments));
    conflicts.addAll(_detectAvailabilityConflict(newAssignment, availabilities));
    conflicts.addAll(_detectLeaveConflict(newAssignment, leaves));

    return conflicts;
  }

  List<ScheduleConflict> _detectEmployeeTimeOverlap(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlapping = existingAssignments.where(
      (a) => a.employeeId == newAssignment.employeeId && a.id != newAssignment.id && newAssignment.overlapsWith(a),
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
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlapping = existingAssignments.where(
      (a) => a.areaId == newAssignment.areaId && a.id != newAssignment.id && newAssignment.overlapsWith(a),
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
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    final employeeAssignments = existingAssignments.where(
      (a) => a.employeeId == newAssignment.employeeId,
    );
    for (final existing in employeeAssignments) {
      final gapBefore = newAssignment.startDateTime.difference(existing.endDateTime).inMinutes;
      final gapAfter = existing.startDateTime.difference(newAssignment.endDateTime).inMinutes;
      final gap = newAssignment.startDateTime.isAfter(existing.endDateTime) ? gapBefore : gapAfter;
      if (gap.abs() < settings.minRestPeriodMinutes && gap != 0) {
        conflicts.add(ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.insufficientRest,
          severity: ConflictSeverity.warning,
          employeeId: newAssignment.employeeId,
          assignmentId1: newAssignment.id,
          assignmentId2: existing.id,
          message: 'Insufficient rest period (${gap.abs()} mins < ${settings.minRestPeriodMinutes} mins required)',
        ));
      }
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectMaxHoursViolation(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    final weekStart = DateTimeUtils.getStartOfWeek(newAssignment.scheduledDate);
    final employeeAssignments = existingAssignments.where(
      (a) => a.employeeId == newAssignment.employeeId &&
             a.scheduledDate.isAfter(weekStart) &&
             a.scheduledDate.isBefore(weekStart.add(const Duration(days: 7))),
    );
    final totalHours = employeeAssignments.fold<double>(0, (sum, a) => sum + a.duration.inHours.toDouble()) + 
                        newAssignment.duration.inHours.toDouble();
    if (totalHours > settings.maxWeeklyHours) {
      conflicts.add(ScheduleConflict(
        id: const Uuid().v4(),
        type: ConflictType.maxHoursExceeded,
        severity: ConflictSeverity.error,
        employeeId: newAssignment.employeeId,
        assignmentId1: newAssignment.id,
        message: 'Exceeds maximum weekly hours ($totalHours > ${settings.maxWeeklyHours})',
      ));
    }
    return conflicts;
  }

  List<ScheduleConflict> _detectAvailabilityConflict(
    ScheduleAssignment newAssignment,
    List<AvailabilityBlock> availabilities,
  ) {
    final conflicts = <ScheduleConflict>[];
    final employeeUnavailable = availabilities.where(
      (a) => a.employeeId == newAssignment.employeeId &&
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
    List<LeaveRequest> leaves,
  ) {
    final conflicts = <ScheduleConflict>[];
    final overlappingLeaves = leaves.where(
      (l) => l.employeeId == newAssignment.employeeId &&
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
}