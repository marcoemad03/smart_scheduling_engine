import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';

class SystemSettingsRemoteDataSource {
  final FirebaseFirestore firestore;
  SystemSettingsRemoteDataSource({required this.firestore});

  static const docId = 'default';

  Stream<SystemSettings?> watch() {
    return firestore
        .collection('systemSettings')
        .doc(docId)
        .snapshots()
        .map((doc) =>
            doc.exists ? SystemSettings.fromMap(doc.id, doc.data()!) : null);
  }

  Future<SystemSettings?> loadOnce() async {
    final doc = await firestore
        .collection('systemSettings')
        .doc(docId)
        .get();
    return doc.exists ? SystemSettings.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> save(SystemSettings settings) async {
    await firestore
        .collection('systemSettings')
        .doc(SystemSettingsRemoteDataSource.docId)
        .set({
      ...settings.toMap(),
      'settingsId': SystemSettingsRemoteDataSource.docId,
    }, SetOptions(merge: true));
  }
}

class SystemSettingsViewModel
    extends StateNotifier<AsyncValue<SystemSettings>> {
  final SystemSettingsRemoteDataSource dataSource;
  final String currentUserId;

  SystemSettingsViewModel(this.dataSource, this.currentUserId)
      : super(const AsyncValue.loading()) {
    dataSource.watch().listen((s) {
      state = AsyncValue.data(s ?? _defaults());
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  SystemSettings _defaults() => SystemSettings(
        settingsId: 'default',
        maxWeeklyHours: 48,
        minRestPeriodMinutes: 480,
        workingHoursStart: 480,
        workingHoursEnd: 1320,
        allowCustomSchedules: true,
        enableAttendanceTracking: false,
        timezone: 'UTC',
        weekStartDay: 1,
        updatedAt: DateTime.now(),
        updatedBy: '',
      );

  Future<void> save(SystemSettings settings) async {
    await dataSource.save(SystemSettings(
      settingsId: settings.settingsId,
      maxWeeklyHours: settings.maxWeeklyHours,
      minRestPeriodMinutes: settings.minRestPeriodMinutes,
      workingHoursStart: settings.workingHoursStart,
      workingHoursEnd: settings.workingHoursEnd,
      allowCustomSchedules: settings.allowCustomSchedules,
      enableAttendanceTracking: settings.enableAttendanceTracking,
      timezone: settings.timezone,
      weekStartDay: settings.weekStartDay,
      maxConsecutiveWorkingDays: settings.maxConsecutiveWorkingDays,
      maxOvertimeHoursPerWeek: settings.maxOvertimeHoursPerWeek,
      allowScheduleOverride: settings.allowScheduleOverride,
      allowLongShifts: settings.allowLongShifts,
      allowSplitShifts: settings.allowSplitShifts,
      updatedAt: DateTime.now(),
      updatedBy: currentUserId,
    ));
  }
}

final systemSettingsDataSourceProvider =
    Provider<SystemSettingsRemoteDataSource>((ref) {
  return SystemSettingsRemoteDataSource(
      firestore: ref.watch(firebaseFirestoreProvider));
});

final systemSettingsViewModelProvider = StateNotifierProvider<
    SystemSettingsViewModel, AsyncValue<SystemSettings>>((ref) {
  return SystemSettingsViewModel(
    ref.watch(systemSettingsDataSourceProvider),
    FirebaseAuth.instance.currentUser?.uid ?? 'admin',
  );
});
