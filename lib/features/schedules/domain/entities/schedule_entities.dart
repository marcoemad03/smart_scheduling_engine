import 'package:reception_workforce_scheduler/core/constants/enums.dart';

class ScheduleAssignment {
  final String id;
  final String employeeId;
  final String areaId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? shiftTemplateId;
  final DateTime scheduledDate;
  final AssignmentStatus status;
  final String? notes;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleAssignment({
    required this.id,
    required this.employeeId,
    required this.areaId,
    required this.startDateTime,
    required this.endDateTime,
    this.shiftTemplateId,
    required this.scheduledDate,
    this.status = AssignmentStatus.draft,
    this.notes,
    required this.createdBy,
    required this.updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Duration get duration => endDateTime.difference(startDateTime);

  bool get isOvernight => endDateTime.day != startDateTime.day ||
      endDateTime.isBefore(startDateTime);

  bool get isLongShift => duration.inHours >= 12;

  bool overlapsWith(ScheduleAssignment other) {
    return startDateTime.isBefore(other.endDateTime) &&
        other.startDateTime.isBefore(endDateTime);
  }

  ScheduleAssignment copyWith({
    String? id,
    String? employeeId,
    String? areaId,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? shiftTemplateId,
    DateTime? scheduledDate,
    AssignmentStatus? status,
    String? notes,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return ScheduleAssignment(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      areaId: areaId ?? this.areaId,
      startDateTime: startDateTime ?? this.startDateTime,
      endDateTime: endDateTime ?? this.endDateTime,
      shiftTemplateId: shiftTemplateId ?? this.shiftTemplateId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

enum AssignmentStatus {
  draft,
  published,
  overridden,
}

class WeeklySchedule {
  final String id;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int version;
  final ScheduleStatus status;
  final String createdBy;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final List<ScheduleAssignment> assignments;

  WeeklySchedule({
    required this.id,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.version,
    required this.status,
    required this.createdBy,
    this.publishedAt,
    DateTime? createdAt,
    required this.assignments,
  }) : createdAt = createdAt ?? DateTime.now();

  List<ScheduleAssignment> getAssignmentsForEmployee(String employeeId) {
    return assignments.where((a) => a.employeeId == employeeId).toList();
  }

  List<ScheduleAssignment> getAssignmentsForDay(DateTime day) {
    return assignments.where((a) =>
      a.scheduledDate.year == day.year &&
      a.scheduledDate.month == day.month &&
      a.scheduledDate.day == day.day
    ).toList();
  }

  double getWeeklyHoursForEmployee(String employeeId) {
    final employeeAssignments = getAssignmentsForEmployee(employeeId);
    return employeeAssignments.fold<double>(
      0,
      (sum, a) => sum + a.duration.inHours.toDouble(),
    );
  }

  WeeklySchedule copyWith({
    String? id,
    DateTime? weekStartDate,
    DateTime? weekEndDate,
    int? version,
    ScheduleStatus? status,
    DateTime? publishedAt,
    List<ScheduleAssignment>? assignments,
  }) {
    return WeeklySchedule(
      id: id ?? this.id,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      weekEndDate: weekEndDate ?? this.weekEndDate,
      version: version ?? this.version,
      status: status ?? this.status,
      createdBy: createdBy,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt,
      assignments: assignments ?? this.assignments,
    );
  }
}
