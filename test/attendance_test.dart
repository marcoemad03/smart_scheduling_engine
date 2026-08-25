import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/features/attendance/domain/entities/attendance_record.dart';

void main() {
  final day = DateTime(2026, 3, 2); // Monday
  final shift = (
    start: day.add(const Duration(minutes: 480)), // 08:00
    end: day.add(const Duration(minutes: 900)), // 15:00
  );

  AttendanceRecord planned() => AttendanceRecord.planned(
        assignmentId: 'a1',
        employeeId: 'e1',
        scheduledStart: shift.start,
        scheduledEnd: shift.end,
      );


  test('planned record preserves schedule and never touches it', () {
    final r = planned();
    expect(r.scheduledStart, shift.start);
    expect(r.scheduledEnd, shift.end);
    expect(r.status, AttendanceStatus.scheduled);
    expect(r.lateMinutes, 0);
    expect(r.earlyLeaveMinutes, 0);
    expect(r.overtimeMinutes, 0);
  });

  test('on-time check-in within grace period is present', () {
    final r = planned().withCheckIn(shift.start.add(const Duration(minutes: 4)));
    expect(r.actualCheckIn, isNotNull);
    expect(r.lateMinutes, 0);
    expect(r.status, AttendanceStatus.present);
  });

  test('late check-in computes late minutes', () {
    final r = planned().withCheckIn(shift.start.add(const Duration(minutes: 23)));
    expect(r.lateMinutes, 23);
    expect(r.status, AttendanceStatus.late);
  });

  test('early leave is detected on check-out', () {
    var r = planned().withCheckIn(shift.start); // on time
    r = r.withCheckOut(shift.end.subtract(const Duration(minutes: 45)));
    expect(r.actualCheckOut, isNotNull);
    expect(r.earlyLeaveMinutes, 45);
    expect(r.overtimeMinutes, 0);
    expect(r.status, AttendanceStatus.earlyLeave);
    // Planned side untouched.
    expect(r.scheduledEnd, shift.end);
  });

  test('overtime is detected on late check-out', () {
    var r = planned().withCheckIn(shift.start);
    r = r.withCheckOut(shift.end.add(const Duration(hours: 1, minutes: 10)));
    expect(r.overtimeMinutes, 70);
    expect(r.earlyLeaveMinutes, 0);
    expect(r.status, AttendanceStatus.present); // worked fully + more
  });

  test('late AND overtime can coexist', () {
    var r = planned().withCheckIn(shift.start.add(const Duration(minutes: 30)));
    r = r.withCheckOut(shift.end.add(const Duration(minutes: 40)));
    expect(r.lateMinutes, 30);
    expect(r.overtimeMinutes, 40);
    expect(r.status, AttendanceStatus.late);
  });

  test('overnight shift: checking in before midnight works normally', () {
    final nightStart = day.add(const Duration(minutes: 1320)); // 22:00
    final nightEnd = day.add(const Duration(days: 1, minutes: 360)); // 06:00
    var r = AttendanceRecord.planned(
      assignmentId: 'night',
      employeeId: 'e1',
      scheduledStart: nightStart,
      scheduledEnd: nightEnd,
    );
    r = r.withCheckIn(nightStart);
    // Leaves at 04:00 -> 2h early.
    r = r.withCheckOut(nightEnd.subtract(const Duration(hours: 2)));
    expect(r.earlyLeaveMinutes, 120);
    expect(r.actualDuration!.inHours, 6);
  });

  test('mark absent keeps planned times intact', () {
    final r = planned().markAbsent('No show');
    expect(r.status, AttendanceStatus.absent);
    expect(r.notes, 'No show');
    expect(r.scheduledStart, shift.start);
    expect(r.scheduledEnd, shift.end);
  });

  test('summary aggregates present/late/absent/early/overtime', () {
    final present = planned().withCheckIn(shift.start);
    final late = planned()
        .withCheckIn(shift.start.add(const Duration(minutes: 20)))
        .withCheckOut(shift.end.add(const Duration(minutes: 30)));
    final absent = planned().markAbsent();
    final early = planned()
        .withCheckIn(shift.start)
        .withCheckOut(shift.end.subtract(const Duration(minutes: 30)));

    final summary =
        AttendanceSummary.of([present, late, absent, early]);

    expect(summary.total, 4);
    expect(summary.presentCount, 1); // only the clean shift
    expect(summary.lateCount, 1);
    expect(summary.absentCount, 1);
    expect(summary.earlyLeaveCount, 1);
    expect(summary.overtimeCount, 1); // 'late' worked +30m overtime
    expect(summary.totalOvertimeMinutes, 30);
    expect(summary.totalLateMinutes, 20);
  });
}
