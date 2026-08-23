// Scheduling Domain Entities

class ScheduleAssignment {
  final String id;
  final String employeeId;
  final String areaId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? shiftTemplateId;
  final DateTime scheduledDate;

  ScheduleAssignment({
    required this.id,
    required this.employeeId,
    required this.areaId,
    required this.startDateTime,
    required this.endDateTime,
    this.shiftTemplateId,
    required this.scheduledDate,
  });

  Duration get duration => endDateTime.difference(startDateTime);

  bool get isOvernight => 
      endDateTime.isAfter(DateTime(endDateTime.year, endDateTime.month, endDateTime.day));

  // Check if this assignment overlaps with another
  bool overlapsWith(ScheduleAssignment other) {
    return startDateTime.isBefore(other.endDateTime) && 
           other.startDateTime.isBefore(endDateTime);
  }
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
    required this.createdAt,
    required this.assignments,
  });

  // Get all assignments for a specific employee in this week
  List<ScheduleAssignment> getAssignmentsForEmployee(String employeeId) {
    return assignments.where((a) => a.employeeId == employeeId).toList();
  }

  // Get all assignments for a specific area on a specific day
  List<ScheduleAssignment> getAssignmentsForAreaOnDay(String areaId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return assignments.where(
      (a) => a.areaId == areaId && 
             a.startDateTime.isAfter(startOfDay) && 
             a.startDateTime.isBefore(endOfDay),
    ).toList();
  }

  // Total hours scheduled for an employee this week
  double getWeeklyHoursForEmployee(String employeeId) {
    final employeeAssignments = getAssignmentsForEmployee(employeeId);
    return employeeAssignments.fold<double>(
      0, 
      (sum, a) => sum + a.duration.inHours.toDouble(),
    );
  }
}