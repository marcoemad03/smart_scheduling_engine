import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/workload_calculator.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';

Employee _emp(String id, {double maxHours = 40, bool active = true}) =>
    Employee(
      id: id,
      firstName: id,
      lastName: 'T',
      email: '$id@x',
      phone: '',
      hireDate: DateTime(2020),
      maxWeeklyHours: maxHours,
      preferredAreas: const [],
      isActive: active,
    );

ScheduleAssignment _a(String empId, int dayOffset, int startMin, int endMin) {
  final day = DateTime(2026, 3, 2).add(Duration(days: dayOffset));
  final overnight = endMin <= startMin;
  return ScheduleAssignment(
    id: '$empId-$dayOffset-$startMin',
    employeeId: empId,
    areaId: 'a',
    scheduledDate: day,
    startDateTime: day.add(Duration(minutes: startMin)),
    endDateTime: overnight
        ? day.add(const Duration(days: 1)).add(Duration(minutes: endMin))
        : day.add(Duration(minutes: endMin)),
    createdBy: 't',
    updatedBy: 't',
  );
}

SystemSettings _settings() => SystemSettings(
      settingsId: 'd',
      maxWeeklyHours: 40,
      minRestPeriodMinutes: 0,
      workingHoursStart: 0,
      workingHoursEnd: 1440,
      allowCustomSchedules: true,
      enableAttendanceTracking: false,
      timezone: 'UTC',
      weekStartDay: 1,
      updatedAt: DateTime(2024),
      updatedBy: 't',
    );

void main() {
  final calculator = const WorkloadCalculator();
  final weekStart = DateTime(2026, 3, 2);

  test('computes hours, days and shift categories', () {
    final workloads = calculator.compute(
      weekStart: weekStart,
      employees: [_emp('e1')],
      settings: _settings(),
      assignments: [
        _a('e1', 0, 480, 900), // Mon 7h
        _a('e1', 1, 480, 1200), // Tue 12h long
        _a('e1', 5, 480, 900), // Sat weekend
        _a('e1', 2, 1320, 360), // Wed night (overnight)
      ],
    );

    final w = workloads.single;
    expect(w.totalHours, closeTo(7 + 12 + 7 + 8, 0.01)); // night = 8h
    expect(w.daysWorked, 4);
    expect(w.longShifts, 1);
    expect(w.weekendShifts, 1);
    expect(w.nightShifts, 1);
    expect(w.overtimeHours, 0); // 35h <= 40h limit
  });

  test('overtime is measured against per-employee limits', () {
    final workloads = calculator.compute(
      weekStart: weekStart,
      employees: [_emp('e1', maxHours: 40)],
      settings: _settings(),
      assignments: List.generate(
          6, (i) => _a('e1', i, 480, 900)), // 6 x 7h = 42h
    );
    expect(workloads.single.overtimeHours, closeTo(2, 0.01));
  });

  test('flags significantly overworked vs team average', () {
    final workloads = calculator.compute(
      weekStart: weekStart,
      employees: [_emp('busy'), _emp('normal'), _emp('light')],
      settings: _settings(),
      assignments: [
        ...List.generate(5, (i) => _a('busy', i, 480, 900)), // 35h
        ...List.generate(3, (i) => _a('normal', i, 480, 900)), // 21h
        _a('light', 0, 480, 900), // 7h
      ],
    );
    final avg = calculator.averageHours(workloads); // 21
    expect(avg, closeTo(21, 0.01));

    final byId = {for (final w in workloads) w.employeeId: w};
    expect(calculator.isSignificantlyOverworked(byId['busy']!, avg), isTrue);
    expect(calculator.isSignificantlyOverworked(byId['normal']!, avg), isFalse);
    expect(calculator.isSignificantlyOverworked(byId['light']!, avg), isFalse);
  });

  test('inactive employees are excluded', () {
    final workloads = calculator.compute(
      weekStart: weekStart,
      employees: [_emp('active'), _emp('gone', active: false)],
      settings: _settings(),
      assignments: [
        _a('active', 0, 480, 900),
        _a('gone', 0, 480, 900),
      ],
    );
    expect(workloads.length, 1);
    expect(workloads.single.employeeId, 'active');
  });
}
