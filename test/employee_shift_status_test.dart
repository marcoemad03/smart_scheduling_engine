import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/employee_shift_status.dart';

ScheduleAssignment _a(DateTime start, DateTime end) {
  return ScheduleAssignment(
    id: 'x-${start.millisecondsSinceEpoch}',
    employeeId: 'e1',
    areaId: 'window',
    startDateTime: start,
    endDateTime: end,
    scheduledDate: DateTime(start.year, start.month, start.day),
    status: AssignmentStatus.published,
    createdBy: 'admin',
    updatedBy: 'admin',
  );
}

void main() {
  final day = DateTime(2026, 3, 2); // a Monday

  test('detects working now with countdown target', () {
    final shift = _a(day.add(const Duration(minutes: 480)),
        day.add(const Duration(minutes: 900)));
    final status = EmployeeShiftStatus.compute(
      now: day.add(const Duration(minutes: 600)), // 10:00
      assignments: [shift],
    );

    expect(status.isWorking, isTrue);
    expect(status.currentShift, shift);
    expect(status.todayLabel, 'Working now');
  });

  test('not started yet before shift', () {
    final shift = _a(day.add(const Duration(minutes: 480)),
        day.add(const Duration(minutes: 900)));
    final status = EmployeeShiftStatus.compute(
      now: day.add(const Duration(minutes: 300)),
      assignments: [shift],
    );

    expect(status.isWorking, isFalse);
    expect(status.currentShift, isNull);
    expect(status.nextShift, shift);
    expect(status.todayLabel, 'Not started yet');
  });

  test('finished for today after shift ends', () {
    final shift = _a(day.add(const Duration(minutes: 480)),
        day.add(const Duration(minutes: 900)));
    final status = EmployeeShiftStatus.compute(
      now: day.add(const Duration(minutes: 1000)),
      assignments: [shift],
    );

    expect(status.todayLabel, 'Finished for today');
  });

  test('overnight shift counts as working past midnight', () {
    // Night shift 22:00 Monday -> 06:00 Tuesday.
    final night = _a(day.add(const Duration(minutes: 1320)),
        day.add(const Duration(days: 1, minutes: 360)));
    final status = EmployeeShiftStatus.compute(
      now: day.add(const Duration(days: 1, minutes: 120)), // Tue 02:00
      assignments: [night],
    );

    expect(status.isWorking, isTrue);
    expect(status.currentShift, night);
  });

  test('day off with future shift later in week', () {
    final later = _a(day.add(const Duration(days: 2, minutes: 480)),
        day.add(const Duration(days: 2, minutes: 900)));
    final status = EmployeeShiftStatus.compute(
      now: day.add(const Duration(minutes: 600)),
      assignments: [later],
    );

    expect(status.isWorking, isFalse);
    expect(status.todayLabel, 'Day off');
    expect(status.nextShift, later);
  });

  test('no upcoming shifts when nothing published', () {
    final status = EmployeeShiftStatus.compute(
      now: day,
      assignments: [],
    );

    expect(status.todayLabel, 'No upcoming shifts');
    expect(status.nextShift, isNull);
  });
}
