// Swaps
class SwapRequest {
  final String swapId;
  final String requestingEmployeeId;
  final String targetEmployeeId;
  final String assignmentId;
  final DateTime preferredDatetime;
  final SwapStatus status;
  final String notes;
  final String adminNotes;
  final String actedBy;
  final DateTime actedAt;
  final DateTime createdAt;

  SwapRequest({
    required this.swapId,
    required this.requestingEmployeeId,
    required this.targetEmployeeId,
    required this.assignmentId,
    required this.preferredDatetime,
    required this.status,
    required this.notes,
    required this.adminNotes,
    required this.actedBy,
    required this.actedAt,
    required this.createdAt,
  });
}

enum SwapStatus { pending, approved, rejected, cancelled }

