import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/reception_area.dart';
import '../models/area_model.dart';
import '../../core/errors/exceptions.dart';

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
        ? (maxIndexDoc.docs.first.data() as Map<String, dynamic>)['orderIndex'] as int
        : 0;
    
    await firestore.collection('areas').doc(area.areaId).set({
      'areaId': area.areaId,
      'name': area.name,
      'description': area.description,
      'orderIndex': maxIndex + 1,
      'isActive': area.isActive,
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