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
    final docRef = firestore.collection('weeklySchedules').doc(docId);

    await firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (snapshot.exists) {
        final remoteUpdatedAt =
            snapshot.data()?['updatedAt'] as Timestamp?;
        // Optimistic concurrency: refuse to silently overwrite another
        // admin's changes saved after this editor loaded the document.
        if (remoteUpdatedAt != null && schedule.updatedAt != null) {
          final localLoadedAt = Timestamp.fromDate(schedule.updatedAt!);
          if (remoteUpdatedAt.millisecondsSinceEpoch >
              localLoadedAt.millisecondsSinceEpoch + 2000) {
            throw StateError(
                'CONCURRENT_MODIFICATION: This schedule was changed by '
                'another admin. Reload the week to get their changes, then '
                're-apply yours.');
          }
        }
      }
      final data = schedule.toJson();
      data['updatedAt'] = FieldValue.serverTimestamp();
      tx.set(docRef, data, SetOptions(merge: true));
    });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await firestore.collection('weeklySchedules').doc(scheduleId).delete();
  }

  String _docId(DateTime weekStart) {
    return '${weekStart.year}-${weekStart.month}-${weekStart.day}';
  }
}
