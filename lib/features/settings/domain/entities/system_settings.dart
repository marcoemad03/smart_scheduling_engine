import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Scheduling rules.
  final int maxConsecutiveWorkingDays;
  final double maxOvertimeHoursPerWeek;
  final bool allowScheduleOverride;
  final bool allowLongShifts;
  final bool allowSplitShifts;

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
    this.maxConsecutiveWorkingDays = 6,
    this.maxOvertimeHoursPerWeek = 0,
    this.allowScheduleOverride = true,
    this.allowLongShifts = true,
    this.allowSplitShifts = true,
    required this.updatedAt,
    required this.updatedBy,
  });

  factory SystemSettings.fromMap(String id, Map<String, dynamic> d) {
    return SystemSettings(
      settingsId: id,
      maxWeeklyHours: (d['maxWeeklyHours'] as num?)?.toDouble() ?? 48,
      minRestPeriodMinutes: d['minRestPeriodMinutes'] as int? ?? 480,
      workingHoursStart: d['workingHoursStart'] as int? ?? 480,
      workingHoursEnd: d['workingHoursEnd'] as int? ?? 1320,
      allowCustomSchedules: d['allowCustomSchedules'] as bool? ?? true,
      enableAttendanceTracking: d['enableAttendanceTracking'] as bool? ?? false,
      timezone: d['timezone'] as String? ?? 'UTC',
      weekStartDay: d['weekStartDay'] as int? ?? 1,
      maxConsecutiveWorkingDays: d['maxConsecutiveWorkingDays'] as int? ?? 6,
      maxOvertimeHoursPerWeek:
          (d['maxOvertimeHoursPerWeek'] as num?)?.toDouble() ?? 0,
      allowScheduleOverride: d['allowScheduleOverride'] as bool? ?? true,
      allowLongShifts: d['allowLongShifts'] as bool? ?? true,
      allowSplitShifts: d['allowSplitShifts'] as bool? ?? true,
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedBy: d['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'maxWeeklyHours': maxWeeklyHours,
        'minRestPeriodMinutes': minRestPeriodMinutes,
        'workingHoursStart': workingHoursStart,
        'workingHoursEnd': workingHoursEnd,
        'allowCustomSchedules': allowCustomSchedules,
        'enableAttendanceTracking': enableAttendanceTracking,
        'timezone': timezone,
        'weekStartDay': weekStartDay,
        'maxConsecutiveWorkingDays': maxConsecutiveWorkingDays,
        'maxOvertimeHoursPerWeek': maxOvertimeHoursPerWeek,
        'allowScheduleOverride': allowScheduleOverride,
        'allowLongShifts': allowLongShifts,
        'allowSplitShifts': allowSplitShifts,
        'updatedAt': Timestamp.fromDate(updatedAt),
        'updatedBy': updatedBy,
      };
}
