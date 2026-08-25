import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

class EmployeeWorkload {
  final String employeeId;
  final double totalHours;
  final int daysWorked;
  final int nightShifts;
  final int weekendShifts;
  final int longShifts;
  final double overtimeHours;

  const EmployeeWorkload({
    required this.employeeId,
    required this.totalHours,
    required this.daysWorked,
    required this.nightShifts,
    required this.weekendShifts,
    required this.longShifts,
    required this.overtimeHours,
  });

  bool get isOverloaded =>
      overtimeHours > 0 || longShifts > 0 || nightShifts > 5 || daysWorked > 6;
}

/// Pure Dart workload analytics - independent from UI and persistence.
class WorkloadCalculator {
  const WorkloadCalculator();

  /// How far above team-average an employee must be to be flagged.
  static const overloadRatio = 1.3;

  List<EmployeeWorkload> compute({
    required DateTime weekStart,
    required List<ScheduleAssignment> assignments,
    required List<Employee> employees,
    required SystemSettings settings,
  }) {
    final start = DateTime(
        weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final weekAssignments = assignments
        .where((a) =>
            !a.startDateTime.isBefore(start) &&
            a.startDateTime.isBefore(end))
        .toList();

    final result = <EmployeeWorkload>[];
    for (final e in employees.where((e) => e.isActive)) {
      final mine =
          weekAssignments.where((a) => a.employeeId == e.id).toList();
      final hours =
          mine.fold<double>(0, (s, a) => s + a.duration.inMinutes / 60);
      final limit =
          e.maxWeeklyHours > 0 ? e.maxWeeklyHours : settings.maxWeeklyHours;

      result.add(EmployeeWorkload(
        employeeId: e.id,
        totalHours: hours,
        daysWorked: mine
            .map((a) => DateTime(a.startDateTime.year, a.startDateTime.month,
                a.startDateTime.day))
            .toSet()
            .length,
        nightShifts: mine.where((a) => _isNight(a)).length,
        weekendShifts:
            mine.where((a) => a.startDateTime.weekday >= 6).length,
        longShifts:
            mine.where((a) => a.duration.inHours >= 12).length,
        overtimeHours:
            hours > limit ? hours - limit : 0,
      ));
    }
    return result;
  }

  double averageHours(List<EmployeeWorkload> workloads) {
    if (workloads.isEmpty) return 0;
    return workloads.fold<double>(0, (s, w) => s + w.totalHours) /
        workloads.length;
  }

  bool isSignificantlyOverworked(
      EmployeeWorkload w, double teamAverageHours) {
    if (teamAverageHours <= 0) return false;
    return w.totalHours >= teamAverageHours * overloadRatio &&
        w.totalHours > 0;
  }

  bool _isNight(ScheduleAssignment a) =>
      a.isOvernight ||
      a.startDateTime.hour >= 21 ||
      (a.endDateTime.hour <= 6 &&
          a.endDateTime.day != a.startDateTime.day);
}
