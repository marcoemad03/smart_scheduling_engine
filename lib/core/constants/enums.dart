// Enums
enum UserRole { admin, employee }

enum ScheduleStatus { draft, published, archived }

enum LeaveStatus { pending, approved, rejected, cancelled }

enum LeaveType { vacation, sick, personal, other }

enum SwapStatus { pending, approved, rejected, cancelled }

enum AttendanceStatus { present, absent, late, onTime }

enum ConflictSeverity { warning, error }

enum ConflictType {
  employeeTimeOverlap,
  areaTimeOverlap,
  insufficientRest,
  maxHoursExceeded,
  availabilityConflict,
  leaveConflict,
}

enum TimeSlotType { morning, afternoon, night }

