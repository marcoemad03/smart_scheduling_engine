import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/swaps/domain/entities/swap_request.dart';

class SwapRemoteDataSource {
  final FirebaseFirestore firestore;
  SwapRemoteDataSource({required this.firestore});

  Stream<List<SwapRequest>> watchMine(String employeeId) {
    return firestore
        .collection('swapRequests')
        .where('requestingEmployeeId', isEqualTo: employeeId)
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Stream<List<SwapRequest>> watchAll() {
    return firestore
        .collection('swapRequests')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  Future<void> add(SwapRequest request) async {
    await firestore
        .collection('swapRequests')
        .doc(request.swapId)
        .set(_toMap(request));
  }

  Future<void> updateStatus(
      String swapId, String status, String actedBy) async {
    await firestore.collection('swapRequests').doc(swapId).update({
      'status': status,
      'actedBy': actedBy,
      'actedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  SwapRequest _fromDoc(String id, Map<String, dynamic> d) {
    return SwapRequest(
      swapId: d['swapId'] as String? ?? id,
      requestingEmployeeId: d['requestingEmployeeId'] as String? ?? '',
      targetEmployeeId: d['targetEmployeeId'] as String? ?? '',
      assignmentId: d['assignmentId'] as String? ?? '',
      preferredDatetime: d['preferredDatetime'] != null
          ? (d['preferredDatetime'] as Timestamp).toDate()
          : DateTime.now(),
      status: SwapStatus.values.firstWhere(
          (e) => e.name == (d['status'] as String? ?? 'pending'),
          orElse: () => SwapStatus.pending),
      notes: d['notes'] as String? ?? '',
      adminNotes: d['adminNotes'] as String? ?? '',
      actedBy: d['actedBy'] as String? ?? '',
      actedAt: d['actedAt'] != null
          ? (d['actedAt'] as Timestamp).toDate()
          : DateTime(2000),
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> _toMap(SwapRequest r) => {
        'swapId': r.swapId,
        'requestingEmployeeId': r.requestingEmployeeId,
        'targetEmployeeId': r.targetEmployeeId,
        'assignmentId': r.assignmentId,
        'preferredDatetime': Timestamp.fromDate(r.preferredDatetime),
        'status': r.status.name,
        'notes': r.notes,
        'adminNotes': r.adminNotes,
        'actedBy': r.actedBy,
        'actedAt': r.actedAt.isAfter(DateTime(2024))
            ? Timestamp.fromDate(r.actedAt)
            : null,
        'createdAt': Timestamp.fromDate(r.createdAt),
      };
}

class SwapViewModel extends StateNotifier<AsyncValue<List<SwapRequest>>> {
  final SwapRemoteDataSource dataSource;
  final String employeeId;
  final bool adminMode;

  SwapViewModel(this.dataSource,
      {required this.employeeId, required this.adminMode})
      : super(const AsyncValue.loading()) {
    (adminMode ? dataSource.watchAll() : dataSource.watchMine(employeeId))
        .listen((list) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      state = AsyncValue.data(list);
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  Future<void> submit({
    required String assignmentId,
    required DateTime shiftStart,
    String targetEmployeeId = '',
    String notes = '',
  }) async {
    await dataSource.add(SwapRequest(
      swapId: const Uuid().v4(),
      requestingEmployeeId: employeeId,
      targetEmployeeId: targetEmployeeId,
      assignmentId: assignmentId,
      preferredDatetime: shiftStart,
      status: SwapStatus.pending,
      notes: notes,
      adminNotes: '',
      actedBy: '',
      actedAt: DateTime(2000),
      createdAt: DateTime.now(),
    ));
  }

  Future<void> act({required String swapId, required bool approve}) async {
    await dataSource.updateStatus(
      swapId,
      approve ? SwapStatus.approved.name : SwapStatus.rejected.name,
      FirebaseAuth.instance.currentUser?.uid ?? 'admin',
    );
  }
}

final mySwapsViewModelProvider =
    StateNotifierProvider<SwapViewModel, AsyncValue<List<SwapRequest>>>((ref) {
  return SwapViewModel(
    SwapRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    employeeId: FirebaseAuth.instance.currentUser?.uid ?? '',
    adminMode: false,
  );
});

final adminSwapsViewModelProvider =
    StateNotifierProvider<SwapViewModel, AsyncValue<List<SwapRequest>>>((ref) {
  return SwapViewModel(
    SwapRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider)),
    employeeId: '',
    adminMode: true,
  );
});
