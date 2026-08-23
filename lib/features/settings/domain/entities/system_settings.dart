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
  final DateTime updatedAt;
  final String updatedBy;

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
    required this.updatedAt,
    required this.updatedBy,
  });
}

