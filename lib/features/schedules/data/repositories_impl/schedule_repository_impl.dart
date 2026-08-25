import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/data/datasources/schedule_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/schedules/data/models/weekly_schedule_model.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/repositories/schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDataSource remoteDataSource;

  ScheduleRepositoryImpl({required this.remoteDataSource});

  @override
  Future<WeeklySchedule?> getScheduleByWeek(DateTime weekStart) async {
    final model = await remoteDataSource.getScheduleByWeekOnce(weekStart);
    return model?.toDomain();
  }

  @override
  Future<WeeklySchedule?> getPublishedScheduleByWeek(DateTime weekStart) async {
    final model = await remoteDataSource.getScheduleByWeekOnce(weekStart);
    if (model == null || model.status != ScheduleStatus.published) return null;
    return model.toDomain();
  }

  @override
  Stream<WeeklySchedule?> watchPublishedScheduleByWeek(DateTime weekStart) {
    return remoteDataSource.getScheduleByWeek(weekStart).map((model) =>
        (model != null && model.status == ScheduleStatus.published)
            ? model.toDomain()
            : null);
  }

  @override
  Future<List<WeeklySchedule>> getAllSchedules() async {
    final models = await remoteDataSource.getAllSchedulesOnce();
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<void> saveSchedule(WeeklySchedule schedule) async {
    final model = WeeklyScheduleModel.fromDomain(schedule);
    await remoteDataSource.saveSchedule(model);
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    await remoteDataSource.deleteSchedule(scheduleId);
  }

  @override
  Future<List<WeeklySchedule>> getScheduleTemplates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('scheduleTemplates')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['scheduleId'] = doc.id;
      return WeeklyScheduleModel.fromJson(data).toDomain();
    }).toList();
  }

  @override
  Future<void> saveScheduleTemplate(WeeklySchedule template, String name) async {
    final model = WeeklyScheduleModel.fromDomain(template);
    final data = model.toJson();
    data['templateName'] = name;
    data['createdAt'] = Timestamp.fromDate(DateTime.now());
    await FirebaseFirestore.instance
        .collection('scheduleTemplates')
        .add(data);
  }
}

