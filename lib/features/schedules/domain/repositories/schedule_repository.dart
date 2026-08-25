import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

abstract class ScheduleRepository {
  Future<WeeklySchedule?> getScheduleByWeek(DateTime weekStart);
  Future<List<WeeklySchedule>> getAllSchedules();
  Future<void> saveSchedule(WeeklySchedule schedule);
  Future<void> deleteSchedule(String scheduleId);
  Future<List<WeeklySchedule>> getScheduleTemplates();
  Future<void> saveScheduleTemplate(WeeklySchedule template, String name);
}
