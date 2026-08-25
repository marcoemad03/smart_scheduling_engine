import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/attendance/domain/entities/attendance_record.dart';

class AttendanceRemoteDataSource {
  final FirebaseFirestore firestore;
  AttendanceRemoteDataSource({required this.firestore});

  Stream<List<AttendanceRecord>> watchMine(String employeeId, DateTime from,
      DateTime to) {
    return firestore
        .collection('attendance')
        .where('employeeId', isEqualTo: employeeId)
        .where('scheduledStart', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('scheduledStart', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Stream<List<AttendanceRecord>> watchRange(DateTime from, DateTime to) {
    return firestore
        .collection('attendance')
        .where('scheduledStart', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('scheduledStart', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Future<Set<String>> existingAssignmentIds(DateTime from, DateTime to) async {
    final snapshot = await firestore
        .collection('attendance')
        .where('scheduledStart', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('scheduledStart', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();
    return snapshot.docs
        .map((d) => d.data()['assignmentId'] as String?)
        .whereType<String>()
        .toSet();
  }

  /// Creates planned records from published assignments. READ-ONLY towards
  /// the schedule collection — attendance never modifies schedules.
  Future<int> ensureRecordsForAssignments(
      List<AttendanceRecord> plannedRecords) async {
    final batch = firestore.batch();
    for (final r in plannedRecords) {
      batch.set(
        firestore.collection('attendance').doc(r.recordId),
        _toMap(r),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return plannedRecords.length;
  }

  Future<void> update(AttendanceRecord record) async {
    await firestore
        .collection('attendance')
        .doc(record.recordId)
        .update(_toMap(record));
  }

  Map<String, dynamic> _toMap(AttendanceRecord r) => {
        'recordId': r.recordId,
        'employeeId': r.employeeId,
        'assignmentId': r.assignmentId,
        'scheduledStart': Timestamp.fromDate(r.scheduledStart),
        'scheduledEnd': Timestamp.fromDate(r.scheduledEnd),
        'actualCheckIn':
            r.actualCheckIn != null ? Timestamp.fromDate(r.actualCheckIn!) : null,
        'actualCheckOut': r.actualCheckOut != null
            ? Timestamp.fromDate(r.actualCheckOut!)
            : null,
        'lateMinutes': r.lateMinutes,
        'earlyLeaveMinutes': r.earlyLeaveMinutes,
        'overtimeMinutes': r.overtimeMinutes,
        'status': r.status.name,
        'notes': r.notes,
        'createdAt': Timestamp.fromDate(r.createdAt),
        'updatedAt': Timestamp.fromDate(r.updatedAt),
      };

  AttendanceRecord _fromDoc(String id, Map<String, dynamic> d) {
    return AttendanceRecord(
      recordId: d['recordId'] as String? ?? id,
      employeeId: d['employeeId'] as String? ?? '',
      assignmentId: d['assignmentId'] as String? ?? id,
      scheduledStart: (d['scheduledStart'] as Timestamp).toDate(),
      scheduledEnd: (d['scheduledEnd'] as Timestamp).toDate(),
      actualCheckIn: d['actualCheckIn'] != null
          ? (d['actualCheckIn'] as Timestamp).toDate()
          : null,
      actualCheckOut: d['actualCheckOut'] != null
          ? (d['actualCheckOut'] as Timestamp).toDate()
          : null,
      lateMinutes: d['lateMinutes'] as int? ?? 0,
      earlyLeaveMinutes: d['earlyLeaveMinutes'] as int? ?? 0,
      overtimeMinutes: d['overtimeMinutes'] as int? ?? 0,
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == (d['status'] as String? ?? 'scheduled'),
        orElse: () => AttendanceStatus.scheduled,
      ),
      notes: d['notes'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: d['updatedAt'] != null
          ? (d['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class AttendanceViewModel
    extends StateNotifier<AsyncValue<List<AttendanceRecord>>> {
  final AttendanceRemoteDataSource dataSource;
  final bool adminMode;
  StreamSubscription? _sub;

  AttendanceViewModel(this.dataSource, {required this.adminMode})
      : super(const AsyncValue.loading());

  void watch({required String employeeId, required DateTime from, required DateTime to}) {
    _sub?.cancel();
    _sub = (adminMode
            ? dataSource.watchRange(from, to)
            : dataSource.watchMine(employeeId, from, to))
        .listen((list) {
      list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
      state = AsyncValue.data(list);
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  Future<void> checkIn(AttendanceRecord record, DateTime now) =>
      dataSource.update(record.withCheckIn(now));

  Future<void> checkOut(AttendanceRecord record, DateTime now) =>
      dataSource.update(record.withCheckOut(now));

  Future<void> markAbsent(AttendanceRecord record, [String note = '']) =>
      dataSource.update(record.markAbsent(note));

  Future<void> addNote(AttendanceRecord record, String note) =>
      dataSource.update(record.withNotes(note));

  /// Generates planned records for any published assignment that does not
  /// have one yet. The schedule collection is only read, never written.
  Future<int> syncFromSchedule({
    required List<Map<String, dynamic>> publishedAssignments,
    required DateTime from,
    required DateTime to,
  }) async {
    final existing =
        await dataSource.existingAssignmentIds(from, to);
    final missing = <AttendanceRecord>[];
    for (final a in publishedAssignments) {
      final assignmentId = a['assignmentId'] as String;
      if (existing.contains(assignmentId)) continue;
      missing.add(AttendanceRecord.planned(
        assignmentId: assignmentId,
        employeeId: a['employeeId'] as String,
        scheduledStart: (a['startDateTime'] as DateTime),
        scheduledEnd: (a['endDateTime'] as DateTime),
      ));
    }
    if (missing.isEmpty) return 0;
    return dataSource.ensureRecordsForAssignments(missing);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final myAttendanceProvider = StateNotifierProvider<AttendanceViewModel,
    AsyncValue<List<AttendanceRecord>>>((ref) {
  return AttendanceViewModel(
    AttendanceRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    adminMode: false,
  );
});

final adminAttendanceProvider = StateNotifierProvider<AttendanceViewModel,
    AsyncValue<List<AttendanceRecord>>>((ref) {
  return AttendanceViewModel(
    AttendanceRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    adminMode: true,
  );
});
