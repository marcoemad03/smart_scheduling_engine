import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';

/// Pure Dart coverage engine. Independent from any UI or persistence layer so
/// it can be reused by an automated scheduler, tests, or exports.
///
/// Coverage is calculated from actual time ranges, not shift names:
/// - A shift 08:00 -> 20:00 covers whatever portion of a requirement window
///   lies between 08:00 and 20:00.
/// - Overnight shifts (e.g. 22:00 -> 06:00 next day) are split at midnight:
///   the late-night piece is measured on the anchor day and the early-morning
///   piece is measured on the following day.
class CoverageCalculator {
  const CoverageCalculator();

  DayCoverageResult calculateForDay({
    required DateTime day,
    required List<ScheduleAssignment> assignments,
    required List<StaffingRequirementEntity> requirements,
  }) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final nextDayStart = dayStart.add(const Duration(days: 1));
    final weekday = dayStart.weekday;

    final dayRequirements =
        requirements.where((r) => r.dayOfWeek == weekday).toList();
    if (dayRequirements.isEmpty) {
      return DayCoverageResult(date: dayStart, intervals: []);
    }

    // Clip shifts touching this day and the next day into minutes-of-day
    // segments per area (overnight shifts are split correctly at midnight).
    final todaySegments = _clipAssignments(assignments, dayStart, nextDayStart);
    final tomorrowSegments =
        _clipAssignments(assignments, nextDayStart, nextDayStart.add(const Duration(days: 1)));

    final intervals = <IntervalCoverage>[];
    for (final req in dayRequirements) {
      // Decompose the requirement window into concrete pieces:
      // - normal window: one piece on today.
      // - overnight window: late-night piece on today + early-morning piece
      //   taken from tomorrow's shifts.
      final pieces = <_Piece>[];
      if (!req.isOvernightWindow) {
        pieces.add(_Piece(
            startMinute: req.startMinute,
            endMinute: req.endMinute,
            segments: todaySegments[req.areaId] ?? const []));
      } else {
        pieces.add(_Piece(
            startMinute: req.startMinute,
            endMinute: 1440,
            segments: todaySegments[req.areaId] ?? const []));
        if (req.endMinute > 0) {
          pieces.add(_Piece(
              startMinute: 0,
              endMinute: req.endMinute,
              segments: tomorrowSegments[req.areaId] ?? const []));
        }
      }

      var scheduledMin = 1 << 30;
      var peakMax = 0;
      for (final piece in pieces) {
        final concurrency = _buildConcurrency(
          piece.segments,
          extraBreakpoints: [piece.startMinute, piece.endMinute],
        );
        final relevant = concurrency
            .where((p) => p.endMinute > piece.startMinute && p.startMinute < piece.endMinute)
            .toList();
        if (relevant.isEmpty) {
          scheduledMin = 0;
        } else {
          scheduledMin =
              relevant.map((p) => p.count).reduce((a, b) => a < b ? a : b);
          final piecePeak =
              relevant.map((p) => p.count).reduce((a, b) => a > b ? a : b);
          if (piecePeak > peakMax) peakMax = piecePeak;
        }
      }
      if (pieces.isEmpty) scheduledMin = 0;

      intervals.add(IntervalCoverage(
        areaId: req.areaId,
        startMinute: req.startMinute,
        endMinute: req.endMinute,
        requiredCount: req.requiredCount,
        scheduledCount: scheduledMin == 1 << 30 ? 0 : scheduledMin,
        peakScheduledCount: peakMax,
      ));
    }

    return DayCoverageResult(date: dayStart, intervals: intervals);
  }

  WeekCoverageResult calculateForWeek({
    required DateTime weekStart,
    required List<ScheduleAssignment> assignments,
    required List<StaffingRequirementEntity> requirements,
  }) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final days = List.generate(7, (i) {
      return calculateForDay(
        day: start.add(Duration(days: i)),
        assignments: assignments,
        requirements: requirements,
      );
    });
    return WeekCoverageResult(days: days);
  }

  Map<String, List<_MinuteSegment>> _clipAssignments(List<ScheduleAssignment>
      assignments, DateTime rangeStart, DateTime rangeEnd) {
    final byArea = <String, List<_MinuteSegment>>{};
    final rangeMinutes = rangeEnd.difference(rangeStart).inMinutes;
    for (final a in assignments) {
      final s = a.startDateTime.isBefore(rangeStart) ? rangeStart : a.startDateTime;
      final e = a.endDateTime.isAfter(rangeEnd) ? rangeEnd : a.endDateTime;
      if (!s.isBefore(e)) continue;
      final startMinutes = s.difference(rangeStart).inMinutes;
      var endMinutes = e.difference(rangeStart).inMinutes;
      if (startMinutes >= rangeMinutes || endMinutes <= startMinutes) {
        if (!(startMinutes < rangeMinutes)) continue;
      }
      if (endMinutes > rangeMinutes) endMinutes = rangeMinutes;
      byArea.putIfAbsent(a.areaId, () => []).add(
            _MinuteSegment(startMinute: startMinutes, endMinute: endMinutes),
          );
    }
    return byArea;
  }

  /// Builds breakpoint pairs with concurrent employee counts across the day
  /// based on actual shift time ranges.
  List<_ConcurrencyPoint> _buildConcurrency(
    List<_MinuteSegment> segments, {
    List<int> extraBreakpoints = const [],
  }) {
    final points = <int>{0, 1440, ...extraBreakpoints};
    for (final seg in segments) {
      points.add(seg.startMinute);
      points.add(seg.endMinute);
    }
    final sorted = points.toList()..sort();
    final result = <_ConcurrencyPoint>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final mid = (sorted[i] + sorted[i + 1]) / 2;
      final count = segments
          .where((s) => s.startMinute <= mid && mid < s.endMinute)
          .length;
      result.add(_ConcurrencyPoint(
        startMinute: sorted[i],
        endMinute: sorted[i + 1],
        count: count,
      ));
    }
    return result;
  }
}

class _MinuteSegment {
  final int startMinute;
  final int endMinute;
  const _MinuteSegment({required this.startMinute, required this.endMinute});
}

class _Piece {
  final int startMinute;
  final int endMinute;
  final List<_MinuteSegment> segments;
  const _Piece({
    required this.startMinute,
    required this.endMinute,
    required this.segments,
  });
}

class _ConcurrencyPoint {
  final int startMinute;
  final int endMinute;
  final int count;
  const _ConcurrencyPoint({
    required this.startMinute,
    required this.endMinute,
    required this.count,
  });
}

enum CoverageStatus { fullyCovered, overstaffed, understaffed }

class IntervalCoverage {
  final String areaId;
  final int startMinute;
  final int endMinute;
  final int requiredCount;

  /// Guaranteed (minimum) number of employees present at any moment inside
  /// the requirement window.
  final int scheduledCount;

  /// Peak number of employees present at any moment inside the window.
  final int peakScheduledCount;

  IntervalCoverage({
    required this.areaId,
    required this.startMinute,
    required this.endMinute,
    required this.requiredCount,
    required this.scheduledCount,
    required this.peakScheduledCount,
  });

  int get missingCount {
    final m = requiredCount - scheduledCount;
    return m > 0 ? m : 0;
  }

  int get extraCount {
    final e = peakScheduledCount - requiredCount;
    return e > 0 ? e : 0;
  }

  double get coveragePercentage => requiredCount <= 0
      ? 100
      : _cap((scheduledCount / requiredCount) * 100);

  CoverageStatus get status {
    if (missingCount > 0) return CoverageStatus.understaffed;
    if (extraCount > 0) return CoverageStatus.overstaffed;
    return CoverageStatus.fullyCovered;
  }
}

class DayCoverageResult {
  final DateTime date;
  final List<IntervalCoverage> intervals;

  const DayCoverageResult({required this.date, required this.intervals});

  bool get hasRequirements => intervals.isNotEmpty;

  int get totalRequired => intervals.fold(0, (sum, i) => sum + i.requiredCount);

  int get totalScheduled => intervals.fold(0, (sum, i) => sum + i.scheduledCount);

  int get totalMissing => intervals.fold(0, (sum, i) => sum + i.missingCount);

  int get totalExtra => intervals.fold(0, (sum, i) => sum + i.extraCount);

  double get coveragePercentage => totalRequired <= 0
      ? 100
      : _cap((totalScheduled / totalRequired) * 100);

  CoverageStatus get status {
    if (totalMissing > 0) return CoverageStatus.understaffed;
    if (totalExtra > 0) return CoverageStatus.overstaffed;
    return CoverageStatus.fullyCovered;
  }
}

class WeekCoverageResult {
  final List<DayCoverageResult> days;

  const WeekCoverageResult({required this.days});

  int get totalRequired => days.fold(0, (sum, d) => sum + d.totalRequired);

  int get totalScheduled => days.fold(0, (sum, d) => sum + d.totalScheduled);

  int get totalMissing => days.fold(0, (sum, d) => sum + d.totalMissing);

  int get totalExtra => days.fold(0, (sum, d) => sum + d.totalExtra);

  double get coveragePercentage => totalRequired <= 0
      ? 100
      : _cap((totalScheduled / totalRequired) * 100);

  CoverageStatus get status {
    if (totalMissing > 0) return CoverageStatus.understaffed;
    if (totalExtra > 0) return CoverageStatus.overstaffed;
    return CoverageStatus.fullyCovered;
  }
}

double _cap(double value) => value > 100 ? 100 : value;
