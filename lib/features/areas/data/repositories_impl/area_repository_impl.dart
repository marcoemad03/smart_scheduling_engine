import 'package:reception_workforce_scheduler/features/areas/data/datasources/area_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/repositories/area_repository.dart';

class AreaRepositoryImpl implements AreaRepository {
  final AreaRemoteDataSource remoteDataSource;

  AreaRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<ReceptionArea>> getAreas() {
    return remoteDataSource.getAreas().map(
      (models) => models.map((model) => model.toDomain()).toList(),
    );
  }

  @override
  Future<ReceptionArea> getAreaById(String id) async {
    final model = await remoteDataSource.getAreaById(id);
    return model.toDomain();
  }

  @override
  Future<void> createArea(ReceptionArea area) => remoteDataSource.createArea(area);
  
  @override
  Future<void> updateArea(ReceptionArea area) => remoteDataSource.updateArea(area);
  
  @override
  Future<void> reorderAreas(List<String> areaIds) => remoteDataSource.reorderAreas(areaIds);
  
  @override
  Future<void> deleteArea(String id) => remoteDataSource.deleteArea(id);
}
