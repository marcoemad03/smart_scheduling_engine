import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

class ScheduleTimeline extends ConsumerWidget {
  final DateTime weekStart;

  const ScheduleTimeline({Key? key, required this.weekStart}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Placeholder - would normally fetch schedule data
    final appointments = <Appointment>[
      Appointment(
        startTime: DateTime.now().add(const Duration(hours: 1)),
        endTime: DateTime.now().add(const Duration(hours: 8)),
        subject: 'Emergency - Night Shift',
        color: Colors.blue,
        isAllDay: false,
      ),
    ];

    return SfCalendar(
      view: CalendarView.week,
      dataSource: _DataSource(appointments),
      firstDayOfWeek: 1,
    );
  }
}

class _DataSource extends CalendarDataSource {
  _DataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}

class ShiftDisplayHelper {
  static String formatShiftTime(ScheduleAssignment assignment) {
    final startTime = _formatTime(assignment.startDateTime);
    final endTime = _formatTime(assignment.endDateTime);

    if (assignment.isOvernight) {
      final nextDay = assignment.endDateTime.add(const Duration(days: 1));
      return "$startTime → $endTime+ (${nextDay.day}/${nextDay.month})";
    }

    return "$startTime → $endTime";
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  static Color getShiftColor(BuildContext context, ScheduleAssignment assignment) {
    if (assignment.isOvernight) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  static IconData getShiftIcon(ScheduleAssignment assignment) {
    if (assignment.isOvernight) {
      return Icons.nightlight_round;
    }
    return Icons.wb_sunny_outlined;
  }

  static String getShiftDurationDisplay(ScheduleAssignment assignment) {
    final duration = assignment.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}