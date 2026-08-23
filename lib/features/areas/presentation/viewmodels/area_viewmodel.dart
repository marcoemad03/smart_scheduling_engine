import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/repositories/area_repository.dart';

class AreaListViewModel extends StateNotifier<AsyncValue<List<ReceptionArea>>> {
  final AreaRepository repository;

  AreaListViewModel({required this.repository}) : super(const AsyncValue.loading()) {
    repository.getAreas().listen((areas) {
      state = AsyncValue.data(areas);
    });
  }
}

class AreaActions {
  final AreaRepository repository;

  AreaActions({required this.repository});

  Future<void> createArea(ReceptionArea area) => repository.createArea(area);
  Future<void> updateArea(ReceptionArea area) => repository.updateArea(area);
  Future<void> reorderAreas(List<String> areaIds) => repository.reorderAreas(areaIds);
  Future<void> deleteArea(String id) => repository.deleteArea(id);
}