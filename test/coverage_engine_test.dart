import 'package:flutter_test/flutter_test.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';

ScheduleAssignment _assignment({
  required String id,
  required String employeeId,
  required String areaId,
  required DateTime start,
  required DateTime end,
}) {
  return ScheduleAssignment(
    id: id,
    employeeId: employeeId,
    areaId: areaId,
    startDateTime: start,
    endDateTime: end,
    scheduledDate: DateTime(start.year, start.month, start.day),
    createdBy: 'test',
    updatedBy: 'test',
  );
}

/// Builds a requirement whose window comes from a shift template (the same
/// resolution path the production engines use).
ResolvedRequirement _req({
  required String areaId,
  int dayOfWeek = 1,
  required int startMinute,
  required int endMinute,
  required int count,
}) {
  final duration = endMinute > startMinute
      ? endMinute - startMinute
      : (1440 - startMinute) + endMinute;
  final template = ShiftTemplateEntity(
    templateId: 'tpl-$areaId-$startMinute-$endMinute',
    name: 'T $startMinute',
    startMinute: startMinute,
    durationMinutes: duration,
    isNightShift: endMinute <= startMinute,
    colorValue: 0xFF000000,
    isActive: true,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );
  final entity = StaffingRequirementEntity(
    requirementId: 'r-$areaId-$startMinute',
    areaId: areaId,
    dayOfWeek: dayOfWeek,
    shiftTemplateId: template.templateId,
    requiredCount: count,
  );
  return resolveRequirements([entity], [template]).first;
}

DateTime _monday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - (now.weekday - 1));
}

void main() {
  group('CoverageCalculator', () {
    final calculator = const CoverageCalculator();
    final monday = _monday();

    test('counts missing employees per time window (understaffed)', () {
      final requirements = [
        _req(areaId: 'window', startMinute: 480, endMinute: 900, count: 2),
        _req(areaId: 'window', startMinute: 900, endMinute: 1320, count: 2),
        _req(areaId: 'window', startMinute: 1320, endMinute: 360, count: 1),
      ];
      final assignments = [
        // Morning fully covered by 2 employees during 08:00 -> 15:00.
        _assignment(
            id: 'a1',
            employeeId: 'e1',
            areaId: 'window',
            start: monday.add(const Duration(minutes: 480)),
            end: monday.add(const Duration(minutes: 900))),
        _assignment(
            id: 'a2',
            employeeId: 'e2',
            areaId: 'window',
            start: monday.add(const Duration(minutes: 480)),
            end: monday.add(const Duration(minutes: 1200))),
      ];

      final result = calculator.calculateForDay(
        day: monday,
        assignments: assignments,
        requirements: requirements,
      );

      expect(result.totalRequired, 5);
      // Morning window: min 2 employees -> OK. Evening window 15:00-22:00:
      // e2 leaves at 20:00 -> guaranteed level is 0 -> missing 2.
      // Night: nobody -> missing 1.
      expect(result.totalScheduled, 2);
      expect(result.totalMissing, 3);
      expect(result.coveragePercentage, closeTo(40.0, 0.1));
      expect(result.status, CoverageStatus.understaffed);
    });

    test('long shift 08:00 -> 20:00 covers morning and evening windows', () {
      final requirements = [
        _req(areaId: 'clinics', startMinute: 480, endMinute: 900, count: 1),
        // Evening window ends at 20:00, so the long shift covers it fully.
        _req(areaId: 'clinics', startMinute: 900, endMinute: 1200, count: 1),
      ];
      final assignments = [
        _assignment(
          id: 'a1',
          employeeId: 'e1',
          areaId: 'clinics',
          start: monday.add(const Duration(minutes: 480)),
          end: monday.add(const Duration(minutes: 1200)),
        ),
      ];

      final result = calculator.calculateForDay(
        day: monday,
        assignments: assignments,
        requirements: requirements,
      );

      expect(result.totalMissing, 0);
      expect(result.totalExtra, 0);
      expect(result.status, CoverageStatus.fullyCovered);
      expect(result.coveragePercentage, 100);
    });

    test('overnight shift 22:00 -> 06:00 covers night windows on both days',
        () {
      final tuesday = monday.add(const Duration(days: 1));
      final requirements = [
        _req(areaId: 'er', dayOfWeek: 1, startMinute: 1320, endMinute: 360, count: 1),
        _req(areaId: 'er', dayOfWeek: 2, startMinute: 1320, endMinute: 360, count: 1),
      ];
      final assignments = [
        // 22:00 Monday -> 06:00 Tuesday.
        _assignment(
          id: 'night',
          employeeId: 'e1',
          areaId: 'er',
          start: monday.add(const Duration(minutes: 1320)),
          end: tuesday.add(const Duration(minutes: 360)),
        ),
      ];

      final mondayResult = calculator.calculateForDay(
          day: monday, assignments: assignments, requirements: requirements);
      final tuesdayResult = calculator.calculateForDay(
          day: tuesday, assignments: assignments, requirements: requirements);

      expect(mondayResult.totalMissing, 0);
      expect(mondayResult.status, CoverageStatus.fullyCovered);
      // Tuesday's own night window (22:00 Tue -> 06:00 Wed) has nobody.
      expect(tuesdayResult.totalMissing, 1);
      expect(tuesdayResult.status, CoverageStatus.understaffed);
    });

    test('detects overstaffed when more employees than required', () {
      final requirements = [
        _req(areaId: 'window', startMinute: 480, endMinute: 900, count: 2),
      ];
      final assignments = List.generate(4, (i) {
        return _assignment(
          id: 'a$i',
          employeeId: 'e$i',
          areaId: 'window',
          start: monday.add(const Duration(minutes: 480)),
          end: monday.add(const Duration(minutes: 900)),
        );
      });

      final result = calculator.calculateForDay(
        day: monday,
        assignments: assignments,
        requirements: requirements,
      );

      expect(result.totalMissing, 0);
      expect(result.totalExtra, 2);
      expect(result.coveragePercentage, 100);
      expect(result.status, CoverageStatus.overstaffed);
    });

    test('matches the example: 19 required, 17 scheduled, 89.4% understaffed',
        () {
      // One day, three areas. Required totals:
      // Window 2+2+1 = 5, Clinics 3+2+1 = 6, Operations 2+2+1 = 5,
      // plus Emergency morning 3 => 19.
      final requirements = [
        _req(areaId: 'window', startMinute: 480, endMinute: 900, count: 2),
        _req(areaId: 'window', startMinute: 900, endMinute: 1320, count: 2),
        _req(areaId: 'window', startMinute: 1320, endMinute: 360, count: 1),
        _req(areaId: 'clinics', startMinute: 480, endMinute: 900, count: 3),
        _req(areaId: 'clinics', startMinute: 900, endMinute: 1320, count: 2),
        _req(areaId: 'clinics', startMinute: 1320, endMinute: 360, count: 1),
        _req(areaId: 'ops', startMinute: 480, endMinute: 900, count: 2),
        _req(areaId: 'ops', startMinute: 900, endMinute: 1320, count: 2),
        _req(areaId: 'ops', startMinute: 1320, endMinute: 360, count: 1),
        _req(areaId: 'er', startMinute: 480, endMinute: 900, count: 3),
      ];

      // Schedule every slot exactly except 2 (one clinics evening and one
      // window night) -> 17 scheduled of 19 required.
      final assignments = <ScheduleAssignment>[];
      void fill(String area, int startMin, int endMin, int n,
          {bool skipLast = false}) {
        for (var i = 0; i < (skipLast ? n - 1 : n); i++) {
          final isOvernight = endMin <= startMin;
          assignments.add(_assignment(
            id: '$area-$startMin-$i',
            employeeId: 'emp-$area-$startMin-$i',
            areaId: area,
            start: monday.add(Duration(minutes: startMin)),
            end: isOvernight
                ? monday.add(const Duration(days: 1),).add(Duration(minutes: endMin))
                : monday.add(Duration(minutes: endMin)),
          ));
        }
      }

      fill('window', 480, 900, 2);
      fill('window', 900, 1320, 2);
      fill('window', 1320, 360, 1, skipLast: true);
      fill('clinics', 480, 900, 3);
      fill('clinics', 900, 1320, 2, skipLast: true);
      fill('clinics', 1320, 360, 1);
      fill('ops', 480, 900, 2);
      fill('ops', 900, 1320, 2);
      fill('ops', 1320, 360, 1);
      fill('er', 480, 900, 3);

      final result = calculator.calculateForDay(
        day: monday,
        assignments: assignments,
        requirements: requirements,
      );

      expect(result.totalRequired, 19);
      expect(result.totalScheduled, 17);
      expect(result.totalMissing, 2);
      expect(result.coveragePercentage, closeTo(89.4, 0.1));
      expect(result.status, CoverageStatus.understaffed);
    });
  });

  group('ConflictDetector (UI-independent)', () {
    late SystemSettings settings;
    late ConflictDetector detector;

    setUp(() {
      settings = SystemSettings(
        settingsId: 'default',
        maxWeeklyHours: 48,
        minRestPeriodMinutes: 480,
        workingHoursStart: 0,
        workingHoursEnd: 1440,
        allowCustomSchedules: true,
        enableAttendanceTracking: false,
        timezone: 'UTC',
        weekStartDay: 1,
        maxConsecutiveWorkingDays: 5,
        updatedAt: DateTime.now(),
        updatedBy: 'test',
      );
      detector = ConflictDetector(
        settings: settings,
        areas: [
          ReceptionArea(
              areaId: 'window',
              name: 'Window',
              description: '',
              orderIndex: 1,
              isActive: true),
          ReceptionArea(
              areaId: 'old',
              name: 'Old Area',
              description: '',
              orderIndex: 2,
              isActive: false),
        ],
        employees: [
          Employee(
            id: 'e1',
            firstName: 'Test',
            lastName: 'Employee',
            email: 't@x.com',
            phone: '',
            hireDate: DateTime(2020),
            maxWeeklyHours: 48,
            preferredAreas: ['window'],
            isActive: true,
          ),
        ],
        availabilities: [],
        leaves: [],
        staffingRequirements: [],
      );
    });

    ScheduleAssignment _on(int dayOffset, int startMin, int endMin) {
      final day = _monday().add(Duration(days: dayOffset));
      final endDate = endMin <= startMin
          ? day.add(const Duration(days: 1))
          : day;
      return _assignment(
        id: 'x-$dayOffset-$startMin',
        employeeId: 'e1',
        areaId: 'window',
        start: day.add(Duration(minutes: startMin)),
        end: endDate.add(Duration(minutes: endMin)),
      );
    }

    test('flags overlapping assignments for same employee', () {
      final existing = [_on(0, 480, 900)];
      final newOne = _on(0, 800, 1000);
      final conflicts =
          detector.detectAssignmentConflicts(newOne, existing);
      expect(
        conflicts.any((c) => c.type == ConflictType.employeeTimeOverlap),
        isTrue,
      );
    });

    test('flags insufficient rest between shifts', () {
      final existing = [_on(0, 480, 900)]; // ends 15:00
      final newOne = _on(0, 960, 1320); // starts 16:00 -> only 60m rest
      final conflicts =
          detector.detectAssignmentConflicts(newOne, existing);
      expect(
        conflicts.any((c) => c.type == ConflictType.insufficientRest),
        isTrue,
      );
    });

    test('flags assignment in inactive area', () {
      final conflicts = detector.detectAssignmentConflicts(
          _on(0, 480, 900).copyWith(areaId: 'old'), []);
      expect(conflicts.any((c) => c.type == ConflictType.inactiveArea), isTrue);
    });

    test('flags unqualified area assignment', () {
      final conflicts = detector.detectAssignmentConflicts(
          _on(0, 480, 900).copyWith(areaId: 'other'), []);
      expect(
        conflicts.any((c) => c.type == ConflictType.notQualifiedArea),
        isTrue,
      );
    });

    test('flags exceeding consecutive working days', () {
      // e1 already worked Mon-Fri (5 days); adding Saturday exceeds limit of 5.
      final existing = [
        _on(0, 480, 900),
        _on(1, 480, 900),
        _on(2, 480, 900),
        _on(3, 480, 900),
        _on(4, 480, 900),
      ];
      final newOne = _on(5, 480, 900);
      final conflicts =
          detector.detectAssignmentConflicts(newOne, existing);
      expect(
        conflicts.any((c) => c.type == ConflictType.consecutiveDaysExceeded),
        isTrue,
      );
    });

    test('does not flag consecutive days within limit', () {
      final existing = [_on(0, 480, 900), _on(1, 480, 900)];
      final newOne = _on(2, 480, 900);
      final conflicts =
          detector.detectAssignmentConflicts(newOne, existing);
      expect(
        conflicts.any((c) => c.type == ConflictType.consecutiveDaysExceeded),
        isFalse,
      );
    });
  });
}
