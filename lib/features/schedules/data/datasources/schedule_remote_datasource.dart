import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/weekly_schedule_model.dart';

class ScheduleRemoteDataSource {
  final FirebaseFirestore firestore;

  ScheduleRemoteDataSource({required this.firestore});

  Stream<List<WeeklyScheduleModel>> getAllSchedules() {
    return firestore.collection('weeklySchedules').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => WeeklyScheduleModel.fromJson(doc.data()))
              .toList(),
        );
  }

  Stream<WeeklyScheduleModel?> getScheduleByWeek(DateTime weekStart) {
    final docId = _docId(weekStart);
    return firestore.collection('weeklySchedules').doc(docId).snapshots().map(
          (doc) => doc.exists ? WeeklyScheduleModel.fromJson(doc.data()!) : null,
        );
  }

  Future<WeeklyScheduleModel?> getScheduleByWeekOnce(DateTime weekStart) async {
    final docId = _docId(weekStart);
    final doc =
        await firestore.collection('weeklySchedules').doc(docId).get();
    return doc.exists ? WeeklyScheduleModel.fromJson(doc.data()!) : null;
  }

  Future<List<WeeklyScheduleModel>> getAllSchedulesOnce() async {
    final snapshot = await firestore.collection('weeklySchedules').get();
    return snapshot.docs
        .map((doc) => WeeklyScheduleModel.fromJson(doc.data()))
        .toList();
  }

  Future<void> saveSchedule(WeeklyScheduleModel schedule) async {
    final docId = _docId(schedule.weekStartDate);
    await firestore.collection('weeklySchedules').doc(docId).set(
          schedule.toJson(),
        );
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await firestore.collection('weeklySchedules').doc(scheduleId).delete();
  }

  String _docId(DateTime weekStart) {
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }
}
