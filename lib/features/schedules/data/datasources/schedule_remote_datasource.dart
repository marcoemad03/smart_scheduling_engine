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
    final docId = '${weekStart.year}-${weekStart.month}-${weekStart.day}';
    return firestore.collection('weeklySchedules').doc(docId).snapshots().map(
      (doc) => doc.exists ? WeeklyScheduleModel.fromJson(doc.data()!) : null,
    );
  }

  Future<void> saveSchedule(WeeklyScheduleModel schedule) async {
    final docId = '${schedule.weekStartDate.year}-${schedule.weekStartDate.month}-${schedule.weekStartDate.day}';
    await firestore.collection('weeklySchedules').doc(docId).set(
      schedule.toJson(),
    );
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await firestore.collection('weeklySchedules').doc(scheduleId).delete();
  }
}