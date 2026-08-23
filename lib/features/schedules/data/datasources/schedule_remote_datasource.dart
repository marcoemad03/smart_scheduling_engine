import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_assignment_model.dart';
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
    final docId = weekStart.toString().split(' ')[0];
    return firestore.collection('weeklySchedules').doc(docId).snapshots().map(
      (doc) => doc.exists 
          ? WeeklyScheduleModel.fromJson(doc.data()!) 
          : null,
    );
  }

  Future<void> saveSchedule(WeeklyScheduleModel schedule) async {
    final docId = schedule.weekStartDate.toString().split(' ')[0];
    await firestore.collection('weeklySchedules').doc(docId).set(
      schedule.toJson(),
    );
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await firestore.collection('weeklySchedules').doc(scheduleId).delete();
  }

  Stream<List<ScheduleAssignmentModel>> getAssignmentsForEmployee(
    String employeeId, 
    DateTime startDate,
    DateTime endDate,
  ) {
    return firestore
        .collection('weeklySchedules')
        .where('weekStartDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('weekStartDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .snapshots()
        .map((snapshot) => snapshot.docs.expand((doc) {
            final schedule = WeeklyScheduleModel.fromJson(doc.data());
            return schedule.assignments.where((a) => a.employeeId == employeeId);
          }).toList());
  }
}