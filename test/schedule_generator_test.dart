import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/schedule_generator.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';

Employee _emp(String id, {List<String> areas = const [], double maxHours = 48}) {
  return Employee(
    id: id,
    firstName: 'Emp',
    lastName: id,
    email: '$id@x.com',
    phone: '',
    hireDate: DateTime(2020),
    maxWeeklyHours: maxHours,
    preferredAreas: areas,
    isActive: true,
  );
}

ReceptionArea _area(String id) => ReceptionArea(
      areaId: id,
      name: id,
      description: '',
      orderIndex: 1,
      isActive: true,
    );

/// Templates created for test requirements, keyed by templateId. The
/// generator resolves requirement windows from these templates.
final _testTemplates = <String, ShiftTemplateEntity>{};

StaffingRequirementEntity _req(String area, int day, int s, int e, int count) {
  final duration = e > s ? e - s : (1440 - s) + e;
  final templateId = 'tpl-$area-$s-$e';
  _testTemplates[templateId] = ShiftTemplateEntity(
    templateId: templateId,
    name: 'T $s',
    startMinute: s,
    durationMinutes: duration,
    isNightShift: e <= s,
    colorValue: 0xFF000000,
    isActive: true,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
  return StaffingRequirementEntity(
    requirementId: 'r-$area-$day-$s',
    areaId: area,
    dayOfWeek: day,
    shiftTemplateId: templateId,
    requiredCount: count,
  );
}

SystemSettings _settings({int maxConsecutive = 6, double maxHours = 48}) {
  return SystemSettings(
    settingsId: 'default',
    maxWeeklyHours: maxHours,
    minRestPeriodMinutes: 480,
    workingHoursStart: 0,
    workingHoursEnd: 1440,
    allowCustomSchedules: true,
    enableAttendanceTracking: false,
    timezone: 'UTC',
    weekStartDay: 1,
    maxConsecutiveWorkingDays: maxConsecutive,
    updatedAt: DateTime(2024),
    updatedBy: 'test',
  );
}

DateTime _monday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

  ScheduleGenerator _gen({
    required List<Employee> employees,
    required List<StaffingRequirementEntity> requirements,
    SystemSettings? settings,
    List<ScheduleAssignment> fixed = const [],
  }) {
    return ScheduleGenerator(
      settings: settings ?? _settings(),
      employees: employees,
      areas: [_area('a'), _area('b')],
      requirements: requirements,
      shiftTemplates: _testTemplates.values.toList(),
      weekStart: _monday(),
      createdBy: 'test',
      fixedAssignments: fixed,
    );
  }

void main() {
  test('fully staffs a simple requirement set and stays DRAFT', () {
    final monday = _monday();
    final gen = _gen(
      employees: [_emp('e1'), _emp('e2')],
      requirements: [
        _req('a', 1, 480, 900, 2), // Monday morning, 2 people.
      ],
    );

    final result = gen.generate();

    expect(result.draft.status, ScheduleStatus.draft); // never published
    expect(result.isFullyValid, isTrue);
    expect(result.unfilled, isEmpty);
    expect(result.coverageReport.totalMissing, 0);
    final generated = result.draft.assignments
        .where((x) => x.scheduledDate.day == monday.day)
        .length;
    expect(generated, 2);
  });

  test('respects per-employee maximum weekly hours', () {
    final gen = _gen(
      employees: [
        _emp('e1', maxHours: 7), // can only take one 7h morning shift
        _emp('e2'),
      ],
      requirements: [
        _req('a', 1, 480, 900, 1),
        _req('a', 2, 480, 900, 1),
      ],
      settings: _settings(maxHours: 48),
    );

    final result = gen.generate();

    // e1 must not exceed 7h total for the week.
    final e1Hours = result.employeeStats
        .where((s) => s.employeeId == 'e1')
        .fold(0.0, (s, x) => s + x.totalHours);
    expect(e1Hours, lessThanOrEqualTo(7.01));
    expect(result.isFullyValid, isTrue);
  });

  test('reports unfilled requirements when nobody qualified is available',
      () {
    final gen = _gen(
      employees: [_emp('e1', areas: ['a'])],
      requirements: [
        _req('a', 1, 480, 900, 1),
        _req('b', 1, 480, 900, 1), // area b has no qualified employee
      ],
    );

    final result = gen.generate();

    expect(result.isFullyValid, isFalse);
    expect(result.unfilled, isNotEmpty);
    expect(result.warnings, isNotEmpty);
    // Best possible still fills area a.
    expect(result.coverageReport.totalMissing, greaterThanOrEqualTo(1));
    final aFilled = result.draft.assignments.any((x) => x.areaId == 'a');
    expect(aFilled, isTrue);
  });

  test('respects employee availability blocks', () {
    final monday = _monday();
    final gen = ScheduleGenerator(
      settings: _settings(),
      employees: [_emp('e1'), _emp('e2')],
      areas: [_area('a')],
      requirements: [_req('a', 1, 480, 900, 1)],
      shiftTemplates: _testTemplates.values.toList(),
      availabilities: [
        AvailabilityBlock(
          availabilityId: 'av1',
          employeeId: 'e1',
          startDateTime: monday.add(const Duration(minutes: 480)),
          endDateTime: monday.add(const Duration(minutes: 900)),
          isAvailable: false,
          isRecurring: false,
          recurrenceDays: [],
          createdAt: DateTime(2024),
        ),
      ],
      weekStart: monday,
      createdBy: 'test',
    );

    final result = gen.generate();

    // e1 unavailable -> e2 gets the shift.
    final assigned = result.draft.assignments.first;
    expect(assigned.employeeId, 'e2');
    expect(result.isFullyValid, isTrue);
  });

  test('distributes hours fairly between equal employees', () {
    final requirements = <StaffingRequirementEntity>[];
    for (var d = 1; d <= 5; d++) {
      requirements.add(_req('a', d, 480, 780, 1)); // 5h/day Mon-Fri
    }
    final gen = _gen(
      employees: [_emp('e1'), _emp('e2')],
      requirements: requirements,
    );

    final result = gen.generate();

    final stats = result.employeeStats;
    expect(stats.length, 2);
    final diff =
        (stats[0].totalHours - stats[1].totalHours).abs();
    // Fairness: no employee takes more than one extra shift (5h) over the other.
    expect(diff, lessThanOrEqualTo(5.0));
  });

  test('respects maximum consecutive working days', () {
    final requirements = <StaffingRequirementEntity>[];
    for (var d = 1; d <= 7; d++) {
      requirements.add(_req('a', d % 7 == 0 ? 7 : d, 480, 780, 1));
    }
    final gen = _gen(
      employees: [_emp('e1')], // single employee cannot work 7 straight days
      requirements: requirements,
      settings: _settings(maxConsecutive: 5),
    );

    final result = gen.generate();

    expect(result.isFullyValid, isFalse);
    expect(result.unfilled, isNotEmpty);
    // Verify no streak of consecutive worked days exceeds the limit.
    final dates = result.draft.assignments
        .map((a) => DateTime(a.startDateTime.year, a.startDateTime.month,
            a.startDateTime.day))
        .toSet()
        .toList()
      ..sort();
    var maxStreak = 0;
    var streak = 0;
    DateTime? prev;
    for (final d in dates) {
      streak = (prev != null && d.difference(prev).inDays == 1)
          ? streak + 1
          : 1;
      if (streak > maxStreak) maxStreak = streak;
      prev = d;
    }
    expect(maxStreak, lessThanOrEqualTo(5));
  });

  test('credits existing fixed assignments instead of duplicating them', () {
    final monday = _monday();
    final fixed = [
      ScheduleAssignment(
        id: 'fixed-1',
        employeeId: 'e9',
        areaId: 'a',
        scheduledDate: DateTime(monday.year, monday.month, monday.day),
        startDateTime: monday.add(const Duration(minutes: 480)),
        endDateTime: monday.add(const Duration(minutes: 900)),
        createdBy: 'admin',
        updatedBy: 'admin',
        status: AssignmentStatus.overridden,
      ),
    ];
    final gen = _gen(
      employees: [_emp('e1'), _emp('e2')],
      requirements: [_req('a', 1, 480, 900, 2)],
      fixed: fixed,
    );

    final result = gen.generate();

    // Only 1 additional assignment needed since the fixed one counts.
    final newOnes = result.draft.assignments
        .where((x) => x.id != 'fixed-1')
        .length;
    expect(newOnes, 1);
    expect(result.isFullyValid, isTrue);
  });

  test('never produces a published schedule even when fully covered', () {
    final gen = _gen(
      employees: [_emp('e1')],
      requirements: [_req('a', 3, 600, 800, 1)],
    );

    final result = gen.generate();

    expect(result.draft.status, ScheduleStatus.draft);
    for (final a in result.draft.assignments) {
      if (a.createdBy != 'admin') {
        expect(a.status, AssignmentStatus.draft);
      }
    }
  });
}
