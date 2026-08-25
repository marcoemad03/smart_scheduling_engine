import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/schedules/data/datasources/schedule_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/schedules/data/repositories_impl/schedule_repository_impl.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/repositories/schedule_repository.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/viewmodels/scheduler_view_model.dart';

final scheduleRemoteDataSourceProvider =
    Provider<ScheduleRemoteDataSource>((ref) {
  return ScheduleRemoteDataSource(
      firestore: ref.watch(firebaseFirestoreProvider));
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepositoryImpl(
      remoteDataSource: ref.watch(scheduleRemoteDataSourceProvider));
});

final schedulerViewModelProvider =
    StateNotifierProvider<SchedulerViewModel, SchedulerState>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  return SchedulerViewModel(
    repository: ref.watch(scheduleRepositoryProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    currentUserId: user?.uid ?? 'admin',
  );
});
