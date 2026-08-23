import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../domain/entities/schedule_entities.dart';

class ScheduleViewPage extends ConsumerWidget {
  final DateTime weekStart;
  
  const ScheduleViewPage({Key? key, required this.weekStart}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(weeklyScheduleStreamProvider(weekStart));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () => _goToCurrentWeek(context),
          ),
        ],
      ),
      body: scheduleAsync.when(
        data: (schedule) => _buildCalendar(context, schedule),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, WeeklySchedule? schedule) {
    final appointments = schedule?.assignments.map((assignment) {
      return Appointment(
        startTime: assignment.startDateTime,
        endTime: assignment.endDateTime,
        subject: assignment.areaId,
        color: assignment.isOvernight
            ? Theme.of(context).colorScheme.tertiary
            : Theme.of(context).colorScheme.primary,
        notes: assignment.employeeId,
      );
    }).toList() ?? [];

    return SfCalendar(
      view: CalendarView.week,
      dataSource: AppointmentDataSource(appointments),
      firstDayOfWeek: 1,
      showNavigationArrow: true,
      showWeekNumber: true,
      weekNumberStyle: const WeekNumberStyle(),
      timeSlotSize: const Size(double.infinity, 60),
      appointmentBuilder: (context, appointmentDetails) {
        final appointment = appointmentDetails.appointments.first as Appointment;
        return Container(
          decoration: BoxDecoration(
            color: appointment.color,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appointment.subject.isNotEmpty)
                Text(
                  appointment.subject,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (appointment.notes != null && appointment.notes!.isNotEmpty)
                Text(
                  appointment.notes!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
      onViewChange: (viewChangeDetails) {},
      onTap: (calendarTapDetails) {
        if (calendarTapDetails.appointments != null &&
            calendarTapDetails.appointments!.isNotEmpty) {
          _showAppointmentDetails(context, calendarTapDetails.appointments!.first);
        }
      },
    );
  }

  void _goToCurrentWeek(BuildContext context) {
    final today = DateTime.now();
    final currentWeekStart = DateTimeUtils.getStartOfWeek(today);
    // Navigate to current week
  }

  void _showAppointmentDetails(BuildContext context, dynamic appointment) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Shift Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Area'),
              subtitle: Text(appointment.subject),
            ),
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Time'),
              subtitle: Text(
                '${appointment.startTime} - ${appointment.endTime}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}