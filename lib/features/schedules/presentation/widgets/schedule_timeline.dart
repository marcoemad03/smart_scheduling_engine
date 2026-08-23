import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class ScheduleTimeline extends ConsumerWidget {
  final DateTime weekStart;
  
  const ScheduleTimeline({Key? key, required this.weekStart}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(weeklyScheduleStreamProvider(weekStart));
    
    return scheduleAsync.when(
      data: (schedule) => _buildTimeline(context, schedule),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildTimeline(BuildContext context, WeeklySchedule? schedule) {
    if (schedule == null || schedule.assignments.isEmpty) {
      return const Center(child: Text('No schedule data'));
    }

    final appointments = schedule.assignments.map((assignment) {
      return Appointment(
        startTime: assignment.startDateTime,
        endTime: assignment.endDateTime,
        subject: '${assignment.areaId}-${assignment.employeeId}',
        color: _getAssignmentColor(context, assignment),
        isAllDay: false,
      );
    }).toList();

    return SfCalendar(
      view: CalendarView.week,
      dataSource: AppointmentDataSource(appointments),
      firstDayOfWeek: 1,
      controller: CalendarController(),
      onViewChange: (ViewChangeDetails viewChangeDetails) {},
    );
  }

  Color _getAssignmentColor(BuildContext context, ScheduleAssignment assignment) {
    final isOvernight = assignment.isOvernight;
    return isOvernight
        ? Theme.of(context).colorScheme.tertiaryContainer
        : Theme.of(context).colorScheme.secondaryContainer;
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}