import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';

class ShiftTemplatesViewModel
    extends StateNotifier<AsyncValue<List<ShiftTemplateEntity>>> {
  final FirebaseFirestore firestore;
  StreamSubscription? _sub;

  ShiftTemplatesViewModel(this.firestore)
      : super(const AsyncValue.loading()) {
    _sub = firestore
        .collection('shiftTemplates')
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList())
        .listen((list) {
      list.sort((a, b) => a.startMinute.compareTo(b.startMinute));
      state = AsyncValue.data(list);
    }, onError: (e) => state = AsyncValue.error(e, StackTrace.current));
  }

  ShiftTemplateEntity _fromDoc(String id, Map<String, dynamic> d) {
    return ShiftTemplateEntity(
      templateId: d['templateId'] as String? ?? id,
      name: d['name'] as String? ?? '',
      startMinute: d['startMinute'] as int? ?? 480,
      durationMinutes: d['durationMinutes'] as int? ?? 480,
      isNightShift: d['isNightShift'] as bool? ?? false,
      colorValue: d['colorValue'] as int? ?? 0xFF2196F3,
      isActive: d['isActive'] as bool? ?? true,
      createdAt: d['createdAt'] != null
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> save(ShiftTemplateEntity t) async {
    await firestore.collection('shiftTemplates').doc(t.templateId).set({
      'templateId': t.templateId,
      'name': t.name,
      'startMinute': t.startMinute,
      'durationMinutes': t.durationMinutes,
      'isNightShift': t.isNightShift,
      'colorValue': t.colorValue,
      'isActive': t.isActive,
      'createdAt': Timestamp.fromDate(t.createdAt),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
  }

  Future<void> delete(String templateId) async {
    await firestore.collection('shiftTemplates').doc(templateId).delete();
  }

  Future<ShiftTemplateEntity> createDraft() async {
    return ShiftTemplateEntity(
      templateId: const Uuid().v4(),
      name: '',
      startMinute: 480,
      durationMinutes: 480,
      isNightShift: false,
      colorValue: 0xFF2196F3,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final shiftTemplatesProvider = StateNotifierProvider<
    ShiftTemplatesViewModel, AsyncValue<List<ShiftTemplateEntity>>>((ref) {
  return ShiftTemplatesViewModel(ref.watch(firebaseFirestoreProvider));
});
