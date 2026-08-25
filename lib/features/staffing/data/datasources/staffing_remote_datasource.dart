import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';

class StaffingRemoteDataSource {
  final FirebaseFirestore firestore;

  StaffingRemoteDataSource({required this.firestore});

  Stream<List<StaffingRequirementEntity>> getRequirements() {
    return firestore
        .collection('staffingRequirements')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<List<StaffingRequirementEntity>> getRequirementsOnce() async {
    final snapshot = await firestore.collection('staffingRequirements').get();
    return snapshot.docs
        .map((doc) => _fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> saveRequirement(StaffingRequirementEntity requirement) async {
    await firestore
        .collection('staffingRequirements')
        .doc(requirement.requirementId)
        .set(_toMap(requirement));
  }

  Future<void> deleteRequirement(String requirementId) async {
    await firestore
        .collection('staffingRequirements')
        .doc(requirementId)
        .delete();
  }

  Map<String, dynamic> _toMap(StaffingRequirementEntity r) {
    return {
      'requirementId': r.requirementId,
      'areaId': r.areaId,
      'dayOfWeek': r.dayOfWeek,
      'startMinute': r.startMinute,
      'endMinute': r.endMinute,
      'requiredCount': r.requiredCount,
      'shiftTemplateId': r.shiftTemplateId,
      'minHoursPerWeek': r.minHoursPerWeek,
      'createdAt': Timestamp.fromDate(r.createdAt),
    };
  }

  StaffingRequirementEntity _fromMap(String docId, Map<String, dynamic> data) {
    return StaffingRequirementEntity(
      requirementId: data['requirementId'] as String? ?? docId,
      areaId: data['areaId'] as String? ?? '',
      dayOfWeek: data['dayOfWeek'] as int? ?? 1,
      startMinute: data['startMinute'] as int? ?? 0,
      endMinute: data['endMinute'] as int? ?? 1440,
      requiredCount: data['requiredCount'] as int? ?? 1,
      shiftTemplateId: data['shiftTemplateId'] as String?,
      minHoursPerWeek: data['minHoursPerWeek'] as int? ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
