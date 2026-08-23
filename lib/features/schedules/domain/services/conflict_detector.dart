import '../../domain/entities/schedule_entities.dart';
import '../../../core/constants/enums.dart';

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
      (a) => a.employeeId == newAssignment.employeeId && 
             a.id != newAssignment.id &&
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
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    
    final overlapping = existingAssignments.where(
      (a) => a.areaId == newAssignment.areaId && 
             a.id != newAssignment.id &&
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
    List<ScheduleAssignment> existingAssignments,
  ) {
    final conflicts = <ScheduleConflict>[];
    
    final employeeAssignments = existingAssignments.where(
      (a) => a.employeeId == newAssignment.employeeId,
    );
    
    for (final existing in employeeAssignments) {
      final gapBefore = newAssignment.startDateTime.difference(existing.endDateTime).inMinutes;
      final gapAfter = existing.startDateTime.difference(newAssignment.endDateTime).inMinutes;
      
      final gap = newAssignment.startDateTime.isAfter(existing.endDateTime) 
          ? gapBefore 
          : gapAfter;
      
      if (gap < settings.minRestPeriodMinutes && gap > 0) {
        conflicts.add(ScheduleConflict(
          id: const Uuid().v4(),
          type: ConflictType.insufficientRest,
          severity: ConflictSeverity.warning,
          employeeId: newAssignment.employeeId,
          assignmentId1: newAssignment.id,
          assignmentId2: existing.id,
          message: 'Insufficient rest period (${gap} mins < ${settings.minRestPeriodMinutes} mins required)',
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
    
    final employeeAssignments = existingAssignments.where(
      (a) => a.employeeId == newAssignment.employeeId &&
             a.scheduledDate.isInSameWeekAs(newAssignment.scheduledDate),
    );
    
    final totalHours = employeeAssignments.fold<double>(
      0, 
      (sum, a) => sum + a.duration.inHours.toDouble(),
    ) + newAssignment.duration.inHours.toDouble();
    
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

// Extension to check if dates are in same week
extension WeekComparison on DateTime {
  bool isInSameWeekAs(DateTime other) {
    final start1 = DateTimeUtils.getStartOfWeek(this);
    final start2 = DateTimeUtils.getStartOfWeek(other);
    return start1 == start2;
  }
}