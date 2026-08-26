import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';

/// Smart schedule generator. Produces a DRAFT schedule only - it never
/// publishes. Validation results included in [GenerationResult] come from the
/// ConflictDetector/CoverageCalculator engines, so validity claims are always
/// engine-confirmed.
///
/// Hard constraints (an ineligible employee is never assigned):
/// - no overlapping assignment
/// - minimum rest period between shifts
/// - per-employee maximum weekly hours
/// - maximum consecutive working days
/// - availability blocks and approved leaves
/// - area qualification (employee.preferredAreas, empty = unrestricted)
///
/// Soft objectives (greedy scoring):
/// - fair distribution of total hours (highest weight)
/// - fair distribution of night shifts
/// - fair distribution of weekend shifts
/// - slight preference for shorter shifts over long ones
class ScheduleGenerator {
  final SystemSettings settings;
  final List<Employee> employees;
  final List<ReceptionArea> areas;
  final List<StaffingRequirementEntity> requirements;
  final List<ShiftTemplateEntity> shiftTemplates;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;
  final List<ScheduleAssignment> fixedAssignments;
  final DateTime weekStart;
  final String createdBy;

  ScheduleGenerator({
    required this.settings,
    required this.employees,
    required this.areas,
    required this.requirements,
    this.shiftTemplates = const [],
    this.availabilities = const [],
    this.leaves = const [],
    this.fixedAssignments = const [],
    required this.weekStart,
    required this.createdBy,
  });

  GenerationResult generate() {
    final start = DateTimeUtils.getStartOfWeek(weekStart);
    final working = [...fixedAssignments];
    final unfilled = <UnfilledSlot>[];
    final warnings = <String>[];
    final resolved = resolveRequirements(requirements, shiftTemplates);

    for (var d = 0; d < 7; d++) {
      final day = start.add(Duration(days: d));
      final dayReqs = resolved
          .where((r) => r.dayOfWeek == 0 || r.dayOfWeek == day.weekday)
          .toList();

      // Sort hardest-to-fill first: overnight windows, then scarcest areas.
      final sorted = dayReqs.toList()
        ..sort((a, b) {
          final aOver = a.isOvernightWindow ? 0 : 1;
          final bOver = b.isOvernightWindow ? 0 : 1;
          if (aOver != bOver) return aOver - bOver;
          return a.areaId.compareTo(b.areaId);
        });

      for (final req in sorted) {
        var need = req.requiredCount -
            _coveredCount(req, day, fixedAssignments);
        if (need <= 0) continue;

        final slot = _slotFor(req, day);
        while (need > 0) {
          final pick = _pickBestEmployee(req.areaId, slot, working);
          if (pick == null) {
            unfilled.add(UnfilledSlot(
              date: day,
              areaId: req.areaId,
              startMinute: req.startMinute,
              endMinute: req.endMinute,
              missing: need,
            ));
            break;
          }
          working.add(ScheduleAssignment(
            id: const Uuid().v4(),
            employeeId: pick.id,
            areaId: req.areaId,
            scheduledDate: DateTime(day.year, day.month, day.day),
            startDateTime: slot.start,
            endDateTime: slot.end,
            shiftTemplateId: req.shiftTemplateId,
            status: AssignmentStatus.draft,
            createdBy: createdBy,
            updatedBy: createdBy,
          ));
          need--;
        }
      }
    }

    // Warnings about employees who hit their hour cap.
    for (final e in employees) {
      final limit = e.maxWeeklyHours > 0 ? e.maxWeeklyHours : settings.maxWeeklyHours;
      final hours =
          _hoursInWeek(e.id, working, start);
      if (hours >= limit - 0.01 && hours > 0) {
        warnings.add(
            '${e.fullName} reached their maximum weekly hours (${_fmt(hours)}h)');
      }
    }

    // ---- Engine-confirmed validation (never trust the generator itself) ----
    final detector = ConflictDetector(
      settings: settings,
      areas: areas,
      employees: employees,
      availabilities: availabilities,
      leaves: leaves,
      staffingRequirements: requirements,
      shiftTemplates: shiftTemplates,
    );
    final conflictsMap = detector.validateSchedule(working);
    final conflicts = <ScheduleConflict>[];
    for (final c in conflictsMap.values) {
      conflicts.addAll(c);
    }
    final staffingConflicts = detector.detectStaffingGaps(working);

    final coverageReport = const CoverageCalculator().calculateForWeek(
      weekStart: start,
      assignments: working,
      requirements: resolved,
    );

    final hasErrors =
        conflicts.any((c) => c.severity == ConflictSeverity.error);
    final isValid = !hasErrors &&
        staffingConflicts.isEmpty &&
        unfilled.isEmpty &&
        coverageReport.totalMissing == 0;

    if (!isValid) {
      warnings.add(_explain(isValid, hasErrors, staffingConflicts, unfilled,
          coverageReport));
    }

    final draft = WeeklySchedule(
      id:
          '${start.year}-${start.month}-${start.day}',
      weekStartDate: start,
      weekEndDate: start.add(const Duration(days: 6, hours: 23, minutes: 59)),
      version: 1,
      status: ScheduleStatus.draft, // NEVER published automatically.
      createdBy: createdBy,
      assignments: List.unmodifiable(working),
    );

    return GenerationResult(
      draft: draft,
      coverageReport: coverageReport,
      conflicts: conflicts,
      staffingConflicts: staffingConflicts,
      warnings: warnings,
      unfilled: unfilled,
      employeeStats: _buildStats(working, start),
      isFullyValid: isValid,
    );
  }

  // ---------------------------------------------------------------- helpers

  _TimeWindow _slotFor(ResolvedRequirement req, DateTime day) {
    // The requirement's window comes from its shift template (already
    // resolved); overnight windows end on the next day.
    final start = day.add(Duration(minutes: req.startMinute));
    final end = req.isOvernightWindow
        ? day.add(Duration(days: 1, minutes: req.endMinute))
        : day.add(Duration(minutes: req.endMinute));
    return _TimeWindow(start, end);
  }

  /// How many employees already cover the requirement window based on fixed
  /// assignments, measured by the coverage engine's guaranteed concurrency.
  int _coveredCount(ResolvedRequirement req, DateTime day,
      List<ScheduleAssignment> assignments) {
    final dayResult = const CoverageCalculator().calculateForDay(
      day: day,
      assignments: assignments,
      requirements: [req],
    );
    if (dayResult.intervals.isEmpty) return 0;
    return dayResult.intervals.first.scheduledCount;
  }

  /// Picks the eligible employee with the best (lowest) fairness score, or
  /// null when nobody satisfies all hard constraints.
  Employee? _pickBestEmployee(
      String areaId, _TimeWindow slot, List<ScheduleAssignment> working) {
    Employee? best;
    var bestScore = double.infinity;

    final sortedEmployees = [...employees]..sort((a, b) => a.id.compareTo(b.id));
    for (final e in sortedEmployees) {
      final score = scoreCandidate(e, slot, areaId, working);
      if (score != null && score < bestScore) {
        bestScore = score;
        best = e;
      }
    }
    return best;
  }

  /// Public scoring entry point for external tools (e.g. the AI assistant):
  /// returns null when the employee violates any hard constraint for the
  /// given concrete time window, otherwise the fairness score (lower=better).
  double? scoreCandidateForWindow(
    Employee e,
    DateTime windowStart,
    DateTime windowEnd,
    String areaId,
    List<ScheduleAssignment> working,
  ) {
    return scoreCandidate(e, _TimeWindow(windowStart, windowEnd), areaId, working);
  }

  /// Full eligibility check + soft scoring in one pass. Returns null when the
  /// employee violates any hard constraint.
  double? scoreCandidate(Employee e, _TimeWindow slot, String areaId,
      List<ScheduleAssignment> working) {
    // Area qualification.
    if (e.preferredAreas.isNotEmpty && !e.preferredAreas.contains(areaId)) {
      return null;
    }

    final slotHours = slot.hours;

    // Max weekly hours.
    final limit =
        e.maxWeeklyHours > 0 ? e.maxWeeklyHours : settings.maxWeeklyHours;
    final currentHours = _hoursInWeek(e.id, working, weekStart);
    if (currentHours + slotHours > limit + 0.01) return null;

    final mine = working.where((a) => a.employeeId == e.id).toList();
    for (final a in mine) {
      // Overlap.
      if (slot.start.isBefore(a.endDateTime) &&
          a.startDateTime.isBefore(slot.end)) {
        return null;
      }
      // Rest period (both directions).
      final gapBefore =
          slot.start.difference(a.endDateTime).inMinutes;
      final gapAfter = a.startDateTime.difference(slot.end).inMinutes;
      if (gapBefore >= 0 &&
          gapBefore < settings.minRestPeriodMinutes) {
        return null;
      }
      if (gapAfter >= 0 && gapAfter < settings.minRestPeriodMinutes) {
        return null;
      }
    }

    // Availability blocks.
    for (final block in availabilities) {
      if (block.employeeId != e.id || block.isAvailable) continue;
      if (_overlapsBlock(slot, block)) return null;
    }

    // Approved leave.
    for (final leave in leaves) {
      if (leave.employeeId != e.id || leave.status != LeaveStatus.approved) {
        continue;
      }
      if (slot.start.isBefore(leave.endDateTime) &&
          leave.startDateTime.isBefore(slot.end)) {
        return null;
      }
    }

    // Consecutive days.
    final slotDay = DateTime(
        slot.start.year, slot.start.month, slot.start.day);
    final dates = <DateTime>{
      ...mine.map((a) => DateTime(a.startDateTime.year,
          a.startDateTime.month, a.startDateTime.day)),
      slotDay,
    };
    var streak = 1;
    var cursor = slotDay;
    while (dates.contains(cursor.subtract(const Duration(days: 1)))) {
      cursor = cursor.subtract(const Duration(days: 1));
      streak++;
    }
    final limitDays = settings.maxConsecutiveWorkingDays <= 0
        ? 7
        : settings.maxConsecutiveWorkingDays;
    if (streak > limitDays) return null;

    // ---------------- soft scoring (lower is better) ----------------
    final nights = mine.where((a) => _isNight(a)).length;
    final weekendShifts = mine
        .where((a) => a.startDateTime.weekday >= 6)
        .length;
    final isNightSlot = _isNightWindow(slot);
    final isWeekendSlot = slot.start.weekday >= 6;

    var score = 3.0 * ((currentHours + slotHours) / limit);
    score += 1.0 * (nights + (isNightSlot ? 1 : 0));
    score += 0.5 * (weekendShifts + (isWeekendSlot ? 1 : 0));
    score += 0.01 * slotHours; // prefer shorter shifts
    return score;
  }

  bool _overlapsBlock(_TimeWindow slot, AvailabilityBlock block) {
    if (block.isRecurring) {
      if (!(block.recurrenceDays.contains(slot.start.weekday))) return false;
      final blockStart = slot.start.add(Duration(
          minutes: block.startDateTime.hour * 60 + block.startDateTime.minute));
      final blockEnd = slot.start.add(Duration(
          minutes: block.endDateTime.hour * 60 + block.endDateTime.minute));
      return slot.start.isBefore(blockEnd) && blockStart.isBefore(slot.end);
    }
    return slot.start.isBefore(block.endDateTime) &&
        block.startDateTime.isBefore(slot.end);
  }

  bool _isNight(ScheduleAssignment a) =>
      a.isOvernight || a.startDateTime.hour >= 21;

  bool _isNightWindow(_TimeWindow w) => w.end.isBefore(w.start) ||
      w.start.difference(DateTime(w.start.year, w.start.month, w.start.day))
              .inMinutes >=
          1260;

  double _hoursInWeek(String employeeId, List<ScheduleAssignment> list,
      DateTime weekStartDate) {
    final s = DateTimeUtils.getStartOfWeek(weekStartDate);
    final e2 = s.add(const Duration(days: 7));
    return list
        .where((a) =>
            a.employeeId == employeeId &&
            !a.startDateTime.isBefore(s) &&
            a.startDateTime.isBefore(e2))
        .fold(0.0, (sum, a) => sum + a.duration.inMinutes / 60.0);
  }

  List<EmployeeGenerationStats> _buildStats(
      List<ScheduleAssignment> working, DateTime weekStartDate) {
    final stats = <EmployeeGenerationStats>[];
    final ids = working.map((a) => a.employeeId).toSet();
    for (final id in ids) {
      final mine =
          working.where((a) => a.employeeId == id).toList();
      stats.add(EmployeeGenerationStats(
        employeeId: id,
        totalHours: mine.fold(0.0, (s, a) => s + a.duration.inMinutes / 60.0),
        shiftCount: mine.length,
        nightShifts: mine.where(_isNight).length,
        weekendShifts:
            mine.where((a) => a.startDateTime.weekday >= 6).length,
      ));
    }
    stats.sort((a, b) => a.employeeId.compareTo(b.employeeId));
    return stats;
  }

  String _explain(
      bool valid,
      bool hasErrors,
      List<ScheduleConflict> staffingConflicts,
      List<UnfilledSlot> unfilled,
      WeekCoverageResult coverage) {
    final parts = <String>[];
    parts.add('Coverage ${coverage.coveragePercentage.toStringAsFixed(1)}% '
        '(${coverage.totalScheduled}/${coverage.totalRequired})');
    if (unfilled.isNotEmpty) {
      final totalMissing = unfilled.fold(0, (s, u) => s + u.missing);
      parts.add('$totalMissing required slot(s) could not be filled:');
      for (final u in unfilled.take(10)) {
        parts.add(
            '  • ${u.areaId} ${u.windowLabel} on ${u.dateLabel}: missing ${u.missing}');
      }
    }
    if (hasErrors) {
      parts.add('Validation reported blocking conflicts that need review.');
    }
    if (staffingConflicts.isNotEmpty && unfilled.isEmpty) {
      parts.add(
          '${staffingConflicts.length} staffing gap(s) remain despite full assignment attempts.');
    }
    return parts.join('\n');
  }

  String _fmt(double v) => v.toStringAsFixed(1);
}

class _TimeWindow {
  final DateTime start;
  final DateTime end;
  const _TimeWindow(this.start, this.end);

  double get hours => end.difference(start).inMinutes / 60.0;
}

class UnfilledSlot {
  final DateTime date;
  final String areaId;
  final int startMinute;
  final int endMinute;
  final int missing;

  const UnfilledSlot({
    required this.date,
    required this.areaId,
    required this.startMinute,
    required this.endMinute,
    required this.missing,
  });

  String get windowLabel {
    String f(int m) =>
        '${((m % 1440) ~/ 60).toString().padLeft(2, '0')}:${((m % 1440) % 60).toString().padLeft(2, '0')}';
    return '${f(startMinute)}→${f(endMinute)}';
  }

  String get dateLabel =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class EmployeeGenerationStats {
  final String employeeId;
  final double totalHours;
  final int shiftCount;
  final int nightShifts;
  final int weekendShifts;

  const EmployeeGenerationStats({
    required this.employeeId,
    required this.totalHours,
    required this.shiftCount,
    required this.nightShifts,
    required this.weekendShifts,
  });
}

class GenerationResult {
  final WeeklySchedule draft;
  final WeekCoverageResult coverageReport;
  final List<ScheduleConflict> conflicts;

  /// Staffing gaps reported by the validation engine.
  final List<ScheduleConflict> staffingConflicts;
  final List<String> warnings;
  final List<UnfilledSlot> unfilled;
  final List<EmployeeGenerationStats> employeeStats;

  /// True only when the validation engines confirm zero errors, zero staffing
  /// gaps and zero missing coverage. The generator never self-certifies.
  final bool isFullyValid;

  const GenerationResult({
    required this.draft,
    required this.coverageReport,
    required this.conflicts,
    required this.staffingConflicts,
    required this.warnings,
    required this.unfilled,
    required this.employeeStats,
    required this.isFullyValid,
  });

  bool get hasErrors => conflicts.any((c) => c.severity == ConflictSeverity.error);
}
