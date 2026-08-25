import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/assistant_engine.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/scheduling_assistant_commands.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';

Employee _emp(String id, String first,
    {List<String> areas = const [], double maxHours = 48}) {
  return Employee(
    id: id,
    firstName: first,
    lastName: 'Test',
    email: '$id@x.com',
    phone: '',
    hireDate: DateTime(2020),
    maxWeeklyHours: maxHours,
    preferredAreas: areas,
    isActive: true,
  );
}

ReceptionArea _area(String id) => ReceptionArea(
      areaId: id.toLowerCase(),
      name: id,
      description: '',
      orderIndex: 1,
      isActive: true,
    );

DateTime _monday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

ScheduleAssignment _a(String id, String empId, String areaId, int dayOffset,
    int startMin, int endMin) {
  final day = _monday().add(Duration(days: dayOffset));
  return ScheduleAssignment(
    id: id,
    employeeId: empId,
    areaId: areaId,
    scheduledDate: day,
    startDateTime:
        endMin <= startMin ? day.add(Duration(minutes: startMin)) : day.add(Duration(minutes: startMin)),
    endDateTime: endMin <= startMin
        ? day.add(Duration(days: 1, minutes: endMin))
        : day.add(Duration(minutes: endMin)),
    createdBy: 'admin',
    updatedBy: 'admin',
    status: AssignmentStatus.draft,
  );
}

SystemSettings _settings() => SystemSettings(
      settingsId: 'default',
      maxWeeklyHours: 48,
      minRestPeriodMinutes: 0,
      workingHoursStart: 0,
      workingHoursEnd: 1440,
      allowCustomSchedules: true,
      enableAttendanceTracking: false,
      timezone: 'UTC',
      weekStartDay: 1,
      updatedAt: DateTime(2024),
      updatedBy: 'test',
    );

List<Employee> get _staff => [
      _emp('ahmed', 'Ahmed'),
      _emp('mohamed', 'Mohamed'),
      _emp('mina', 'Mina'),
      _emp('sara', 'Sara'),
    ];

List<ReceptionArea> get _areas =>
    [_area('Window'), _area('Clinics'), _area('Emergency')];

void main() {
  group('RuleBasedCommandInterpreter', () {
    final interpreter = const RuleBasedCommandInterpreter();

    InterpreterResult parse(String text) => interpreter.interpret(
        request: text,
        employees: _staff,
        areas: _areas,
        weekStart: _monday());

    test('parses day-off request', () {
      final r = parse('Make Ahmed off on Tuesday.');
      expect(r.commands.single, isA<SetDayOffCommand>());
      final c = r.commands.single as SetDayOffCommand;
      expect(c.employeeId, 'ahmed');
      expect(c.date.weekday, DateTime.tuesday);
    });

    test('parses move request with area', () {
      final r = parse('Move Mohamed from Window to Clinics on Wednesday.');
      expect(r.commands.single, isA<MoveAssignmentAreaCommand>());
      final c = r.commands.single as MoveAssignmentAreaCommand;
      expect(c.employeeId, 'mohamed');
      expect(c.fromAreaId, 'window');
      expect(c.newAreaId, 'clinics');
      expect(c.date.weekday, DateTime.wednesday);
    });

    test('parses additional coverage with count and time window', () {
      final r =
          parse('I need two additional employees from 8 AM to 3 PM on Friday.');
      expect(r.commands.single, isA<AddCoverageCommand>());
      final c = r.commands.single as AddCoverageCommand;
      expect(c.count, 2);
      expect(c.startMinute, 480);
      expect(c.endMinute, 900);
      expect(c.date.weekday, DateTime.friday);
    });

    test('parses night restriction', () {
      final r = parse('Do not assign Mina to night shifts this week.');
      expect(r.commands.single, isA<RestrictNightShiftsCommand>());
      final c = r.commands.single as RestrictNightShiftsCommand;
      expect(c.employeeId, 'mina');
    });

    test('parses generate command', () {
      final r = parse('Generate the best schedule for next week.');
      expect(r.commands.single, isA<GenerateBestScheduleCommand>());
    });

    test('returns note for unparseable input', () {
      final r = parse('hello world something random');
      expect(r.commands, isEmpty);
      expect(r.notes, isNotEmpty);
    });
  });

  group('AssistantEngine', () {
    AssistantEngine engine(WeeklySchedule base) => AssistantEngine(
          settings: _settings(),
          employees: _staff,
          areas: _areas,
          requirements: const [],
          baseSchedule: base,
          currentUserId: 'admin',
        );

    WeeklySchedule baseWith(List<ScheduleAssignment> assignments) {
      final ws = _monday();
      return WeeklySchedule(
        id: 'w',
        weekStartDate: ws,
        weekEndDate: ws.add(const Duration(days: 6)),
        version: 1,
        status: ScheduleStatus.draft,
        createdBy: 'admin',
        assignments: assignments,
      );
    }

    test('day off removes only that employee\'s assignments that day', () {
      final tuesday = 1;
      final base = baseWith([
        _a('a1', 'ahmed', 'window', tuesday, 480, 900),
        _a('a2', 'mohamed', 'window', tuesday, 480, 900),
        _a('a3', 'ahmed', 'clinics', 2, 480, 900), // Wednesday - untouched
      ]);
      final proposal = engine(base).execute([
        SetDayOffCommand(
            employeeId: 'ahmed',
            employeeName: 'Ahmed',
            date: _monday().add(Duration(days: tuesday))),
      ]);

      expect(proposal.removed.map((r) => r.id), ['a1']);
      expect(proposal.proposedDraft.assignments.map((a) => a.id),
          containsAll(['a2', 'a3']));
    });

    test('move changes area of matching assignment only', () {
      final base = baseWith([
        _a('a1', 'mohamed', 'window', 2, 480, 900),
        _a('a2', 'mohamed', 'window', 3, 480, 900),
      ]);
      final proposal = engine(base).execute([
        MoveAssignmentAreaCommand(
          employeeId: 'mohamed',
          employeeName: 'Mohamed',
          date: _monday().add(const Duration(days: 2)),
          newAreaId: 'clinics',
          newAreaName: 'Clinics',
          fromAreaId: 'window',
        ),
      ]);

      expect(proposal.modified.length, 1);
      final updated = proposal.modified.single.$2;
      expect(updated.areaId, 'clinics');
      // Wednesday untouched.
      expect(
          proposal.proposedDraft.assignments
              .singleWhere((a) => a.id == 'a2')
              .areaId,
          'window');
    });

    test('extra coverage assigns eligible, non-busy employees', () {
      final friday = 4;
      final base = baseWith([
        _a('busy1', 'ahmed', 'window', friday, 480, 900),
        _a('other-day', 'mina', 'window', 0, 480, 900),
      ]);
      final proposal = engine(base).execute([
        AddCoverageCommand(
          date: _monday().add(Duration(days: friday)),
          startMinute: 480,
          endMinute: 900,
          areaId: 'window',
          areaName: 'Window',
          count: 2,
        ),
      ]);

      expect(proposal.added.length, 2);
      final addedIds = proposal.added.map((a) => a.employeeId).toSet();
      expect(addedIds.contains('ahmed'), isFalse); // already busy
      expect(addedIds.length, 2);
      for (final a in proposal.added) {
        expect(a.areaId, 'window');
        expect(a.startDateTime.hour, 8);
        expect(a.endDateTime.hour, 15);
      }
    });

    test('night restriction removes overnight shifts for that employee', () {
      final base = baseWith([
        _a('n1', 'mina', 'emergency', 1, 1320, 360), // overnight
        _a('d1', 'mina', 'window', 2, 480, 900), // day - untouched
        _a('n2', 'sara', 'emergency', 1, 1320, 360), // other emp - untouched
      ]);
      final proposal = engine(base).execute([
        const RestrictNightShiftsCommand(employeeId: 'mina', employeeName: 'Mina'),
      ]);

      expect(proposal.removed.map((r) => r.id), ['n1']);
      final remaining = proposal.proposedDraft.assignments.map((a) => a.id);
      expect(remaining, containsAll(['d1', 'n2']));
    });

    test('proposal surfaces validation results without writing anywhere', () {
      final base = baseWith([
        _a('a1', 'ahmed', 'window', 1, 480, 900),
        _a('overlap', 'ahmed', 'clinics', 1, 500, 800),
      ]);
      final proposal = engine(base).execute([]);

      expect(
        proposal.conflicts.any((c) => c.type == ConflictType.employeeTimeOverlap),
        isTrue,
      );
      expect(proposal.isFullyValid, isFalse);
    });

    test('generate replaces the whole schedule via the generator', () {
      final base = baseWith([_a('old1', 'ahmed', 'window', 0, 480, 900)]);
      final proposal = engine(base).execute([
        GenerateBestScheduleCommand(weekStart: _monday()),
      ]);
      expect(proposal.removed.map((r) => r.id), ['old1']);
      expect(proposal.proposedDraft.status, ScheduleStatus.draft);
    });
  });
}
