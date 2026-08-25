// Enums
enum UserRole { admin, employee }

enum ScheduleStatus { draft, published, archived }

enum ConflictSeverity { warning, error }

enum ConflictType {
  employeeTimeOverlap,
  areaTimeOverlap,
  insufficientRest,
  maxHoursExceeded,
  availabilityConflict,
  leaveConflict,
  inactiveArea,
  notQualifiedArea,
  staffingNotSatisfied,
}

