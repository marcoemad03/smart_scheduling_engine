// Attendance
class AttendanceRecord {
  final String recordId;
  final String assignmentId;
  final String employeeId;
  final DateTime date;
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final DateTime actualEndDateTime;
  final AttendanceStatus status;
  final String notes;
  final DateTime createdAt;

  AttendanceRecord({
    required this.recordId,
    required this.assignmentId,
    required this.employeeId,
    required this.date,
    required this.clockInTime,
    required this.clockOutTime,
    required this.actualEndDateTime,
    required this.status,
    required this.notes,
    required this.createdAt,
  });
}

enum AttendanceStatus { present, absent, late, onTime }

