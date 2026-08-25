import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';

class LeaveRemoteDataSource {
  final FirebaseFirestore firestore;
  LeaveRemoteDataSource({required this.firestore});

  Stream<List<LeaveRequest>> watchMine(String employeeId) {
    return firestore
        .collection('leaveRequests')
        .where('employeeId', isEqualTo: employeeId)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Stream<List<LeaveRequest>> watchAll() {
    return firestore
        .collection('leaveRequests')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Future<void> add(LeaveRequest request) async {
    await firestore
        .collection('leaveRequests')
        .doc(request.requestId)
        .set(_toMap(request));
  }

  Future<void> updateStatus(
      String requestId, String status, String adminNotes, String actedBy) async {
    await firestore.collection('leaveRequests').doc(requestId).update({
      'status': status,
      'adminNotes': adminNotes,
      'approvedBy': actedBy,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  LeaveRequest _fromDoc(String id, Map<String, dynamic> d) {
    return LeaveRequest(
      requestId: d['requestId'] as String? ?? id,
      employeeId: d['employeeId'] as String? ?? '',
      type: LeaveType.values.firstWhere(
          (e) => e.name == (d['type'] as String? ?? 'other'),
          orElse: () => LeaveType.other),
      startDateTime: (d['startDateTime'] as Timestamp).toDate(),
      endDateTime: (d['endDateTime'] as Timestamp).toDate(),
      status: LeaveStatus.values.firstWhere(
          (e) => e.name == (d['status'] as String? ?? 'pending'),
          orElse: () => LeaveStatus.pending),
      notes: d['notes'] as String? ?? '',
      adminNotes: d['adminNotes'] as String? ?? '',
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      approvedBy: d['approvedBy'] as String? ?? '',
      approvedAt: d['approvedAt'] != null
          ? (d['approvedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> _toMap(LeaveRequest r) => {
        'requestId': r.requestId,
        'employeeId': r.employeeId,
        'type': r.type.name,
        'startDateTime': Timestamp.fromDate(r.startDateTime),
        'endDateTime': Timestamp.fromDate(r.endDateTime),
        'status': r.status.name,
        'notes': r.notes,
        'adminNotes': r.adminNotes,
        'createdAt': Timestamp.fromDate(r.createdAt),
        'approvedBy': r.approvedBy,
        'approvedAt':
            r.approvedAt.isAfter(DateTime(2024)) ? Timestamp.fromDate(r.approvedAt) : null,
      };
}

class LeaveViewModel extends StateNotifier<AsyncValue<List<LeaveRequest>>> {
  final LeaveRemoteDataSource dataSource;
  final String employeeId;
  final bool adminMode;

  LeaveViewModel(this.dataSource,
      {required this.employeeId, required this.adminMode})
      : super(const AsyncValue.loading()) {
    (adminMode ? dataSource.watchAll() : dataSource.watchMine(employeeId))
        .listen((list) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncValue.data(list);
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  /// Submits a leave or single-day-off request. Always starts PENDING —
  /// approval is an admin-only action.
  Future<void> submit({
    required LeaveType type,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String notes = '',
    bool isDayOff = false,
  }) async {
    final request = LeaveRequest(
      requestId: const Uuid().v4(),
      employeeId: employeeId,
      type: type,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      status: LeaveStatus.pending,
      notes: isDayOff ? '[Day off] $notes' : notes,
      adminNotes: '',
      createdAt: DateTime.now(),
      approvedBy: '',
      approvedAt: DateTime(2000),
    );
    await dataSource.add(request);
  }

  Future<void> act({
    required String requestId,
    required bool approve,
    String adminNotes = '',
  }) async {
    await dataSource.updateStatus(
      requestId,
      approve ? LeaveStatus.approved.name : LeaveStatus.rejected.name,
      adminNotes,
      FirebaseAuth.instance.currentUser?.uid ?? 'admin',
    );
  }
}

final myLeavesViewModelProvider =
    StateNotifierProvider<LeaveViewModel, AsyncValue<List<LeaveRequest>>>((ref) {
  return LeaveViewModel(
    LeaveRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    employeeId: FirebaseAuth.instance.currentUser?.uid ?? '',
    adminMode: false,
  );
});

final adminLeavesViewModelProvider =
    StateNotifierProvider<LeaveViewModel, AsyncValue<List<LeaveRequest>>>((ref) {
  return LeaveViewModel(
    LeaveRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    employeeId: '',
    adminMode: true,
  );
});
