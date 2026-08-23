import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';

abstract class AreaRepository {
  Stream<List<ReceptionArea>> getAreas();
  Future<ReceptionArea> getAreaById(String id);
  Future<void> createArea(ReceptionArea area);
  Future<void> updateArea(ReceptionArea area);
  Future<void> reorderAreas(List<String> areaIds);
  Future<void> deleteArea(String id);
}

class GetAreasUseCase {
  final AreaRepository repository;
  GetAreasUseCase(this.repository);
  Stream<List<ReceptionArea>> call() => repository.getAreas();
}

class CreateAreaUseCase {
  final AreaRepository repository;
  CreateAreaUseCase(this.repository);
  Future<void> call(ReceptionArea area) => repository.createArea(area);
}

class UpdateAreaUseCase {
  final AreaRepository repository;
  UpdateAreaUseCase(this.repository);
  Future<void> call(ReceptionArea area) => repository.updateArea(area);
}

class ReorderAreasUseCase {
  final AreaRepository repository;
  ReorderAreasUseCase(this.repository);
  Future<void> call(List<String> areaIds) => repository.reorderAreas(areaIds);
}

class DeleteAreaUseCase {
  final AreaRepository repository;
  DeleteAreaUseCase(this.repository);
  Future<void> call(String id) => repository.deleteArea(id);
}