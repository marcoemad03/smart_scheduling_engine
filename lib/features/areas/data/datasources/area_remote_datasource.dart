import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';

class AreaRemoteDataSource {
  final FirebaseFirestore firestore;

  AreaRemoteDataSource({required this.firestore});

  Stream<List<AreaModel>> getAreas() {
    return firestore.collection('areas').orderBy('orderIndex').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => AreaModel.fromJson(doc.data()))
          .toList(),
    );
  }

  Future<AreaModel> getAreaById(String id) async {
    final doc = await firestore.collection('areas').doc(id).get();
    if (!doc.exists) throw Exception('Area not found');
    return AreaModel.fromJson(doc.data()!);
  }

  Future<void> createArea(ReceptionArea area) async {
    final maxIndexDoc = await firestore.collection('areas').orderBy('orderIndex', descending: true).limit(1).get();
    final maxIndex = maxIndexDoc.docs.isNotEmpty
        ? maxIndexDoc.docs.first.data()['orderIndex'] as int
        : 0;
    
    await firestore.collection('areas').doc(area.areaId).set({
      'areaId': area.areaId,
      'name': area.name,
      'description': area.description,
      'orderIndex': maxIndex + 1,
      'isActive': area.isActive,
      'icon': area.icon,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateArea(ReceptionArea area) async {
    await firestore.collection('areas').doc(area.areaId).update({
      'name': area.name,
      'description': area.description,
      'orderIndex': area.orderIndex,
      'isActive': area.isActive,
      'icon': area.icon,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reorderAreas(List<String> areaIds) async {
    final batch = firestore.batch();
    for (int i = 0; i < areaIds.length; i++) {
      batch.update(
        firestore.collection('areas').doc(areaIds[i]),
        {'orderIndex': i},
      );
    }
    await batch.commit();
  }

  Future<void> deleteArea(String id) async {
    await firestore.collection('areas').doc(id).delete();
  }
}

class AreaModel {
  final String areaId;
  final String name;
  final String description;
  final int orderIndex;
  final bool isActive;
  final String? icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  AreaModel({
    required this.areaId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.isActive,
    this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      areaId: json['areaId'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      icon: json['icon'] as String?,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'areaId': areaId,
      'name': name,
      'description': description,
      'orderIndex': orderIndex,
      'isActive': isActive,
      'icon': icon,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReceptionArea toDomain() {
    return ReceptionArea(
      areaId: areaId,
      name: name,
      description: description,
      orderIndex: orderIndex,
      isActive: isActive,
      icon: icon,
    );
  }
}
