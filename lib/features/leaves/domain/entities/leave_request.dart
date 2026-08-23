// Leaves
class LeaveRequest {
  final String requestId;
  final String employeeId;
  final LeaveType type;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final LeaveStatus status;
  final String notes;
  final String adminNotes;
  final DateTime createdAt;
  final String approvedBy;
  final DateTime approvedAt;

  LeaveRequest({
    required this.requestId,
    required this.employeeId,
    required this.type,
    required this.startDateTime,
    required this.endDateTime,
    required this.status,
    required this.notes,
    required this.adminNotes,
    required this.createdAt,
    required this.approvedBy,
    required this.approvedAt,
  });
}

enum LeaveStatus { pending, approved, rejected, cancelled }
enum LeaveType { vacation, sick, personal, other }

