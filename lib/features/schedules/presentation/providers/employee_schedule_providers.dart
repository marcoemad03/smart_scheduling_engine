import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

/// The signed-in employee's id. Assignments store employeeId == auth uid.
final currentEmployeeIdProvider = Provider<String>((ref) {
  return FirebaseAuth.instance.currentUser?.uid ?? '';
});

class MyWeekData {
  final WeeklySchedule? publishedSchedule;
  final Map<String, String> areaNames;

  const MyWeekData({
    required this.publishedSchedule,
    required this.areaNames,
  });

  /// Only THIS employee's assignments from the PUBLISHED schedule.
  List<ScheduleAssignment> myAssignments(String employeeId) {
    final s = publishedSchedule;
    if (s == null) return [];
    return s.assignments.where((a) => a.employeeId == employeeId).toList();
  }
}

/// Loads the PUBLISHED schedule for a week plus area display names.
final myWeekProvider =
    FutureProvider.family<MyWeekData, DateTime>((ref, weekStart) async {
  final repo = ref.watch(scheduleRepositoryProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  final week = DateTimeUtils.getStartOfWeek(weekStart);
  final schedule = await repo.getPublishedScheduleByWeek(week);
  final areasSnapshot =
      await firestore.collection('areas').orderBy('orderIndex').get();

  final areaNames = <String, String>{};
  for (final doc in areasSnapshot.docs) {
    final data = doc.data();
    areaNames[data['areaId'] as String? ?? doc.id] =
        data['name'] as String? ?? doc.id;
  }

  return MyWeekData(publishedSchedule: schedule, areaNames: areaNames);
});
