import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

/// Pure Dart helper that derives an employee's live shift situation.
/// UI-independent so it can be unit tested and reused elsewhere.
class EmployeeShiftStatus {
  final ScheduleAssignment? currentShift;
  final ScheduleAssignment? nextShift;
  final String todayLabel;
  final bool isWorking;

  const EmployeeShiftStatus({
    this.currentShift,
    this.nextShift,
    required this.todayLabel,
    required this.isWorking,
  });

  static EmployeeShiftStatus compute({
    required DateTime now,
    required List<ScheduleAssignment> assignments,
  }) {
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrow = todayStart.add(const Duration(days: 1));

    final todays = assignments
        .where((a) =>
            !a.endDateTime.isBefore(todayStart) &&
            a.startDateTime.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    final current = todays.firstOrNullWhere((a) =>
        !a.startDateTime.isAfter(now) && a.endDateTime.isAfter(now));

    final next = assignments
        .where((a) => a.startDateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

    String label;
    if (current != null) {
      label = 'Working now';
    } else if (todays.any((a) => a.startDateTime.isAfter(now))) {
      label = 'Not started yet';
    } else if (todays.isNotEmpty) {
      label = 'Finished for today';
    } else {
      label = next.isEmpty ? 'No upcoming shifts' : 'Day off';
    }

    return EmployeeShiftStatus(
      currentShift: current,
      nextShift: next.isEmpty ? null : next.first,
      todayLabel: label,
      isWorking: current != null,
    );
  }
}

extension _FirstOrNullWhere<T> on Iterable<T> {
  T? firstOrNullWhere(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
