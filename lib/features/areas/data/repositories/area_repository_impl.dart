import '../data/datasources/area_remote_datasource.dart';
import '../data/models/area_model.dart';
import '../../core/errors/exceptions.dart';

abstract class AreaRepository {
  Stream<List<ReceptionArea>> getAreas();
  Future<ReceptionArea> getAreaById(String id);
  Future<void> createArea(ReceptionArea area);
  Future<void> updateArea(ReceptionArea area);
  Future<void> reorderAreas(List<String> areaIds);
  Future<void> deleteArea(String id);
}

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
    try {
      final model = await remoteDataSource.getAreaById(id);
      return model.toDomain();
    } catch (e) {
      throw AppException('Failed to get area: $e');
    }
  }

  @override
  Future<void> createArea(ReceptionArea area) async {
    try {
      await remoteDataSource.createArea(area);
    } catch (e) {
      throw AppException('Failed to create area: $e');
    }
  }

  @override
  Future<void> updateArea(ReceptionArea area) async {
    try {
      await remoteDataSource.updateArea(area);
    } catch (e) {
      throw AppException('Failed to update area: $e');
    }
  }

  @override
  Future<void> reorderAreas(List<String> areaIds) async {
    try {
      await remoteDataSource.reorderAreas(areaIds);
    } catch (e) {
      throw AppException('Failed to reorder areas: $e');
    }
  }

  @override
  Future<void> deleteArea(String id) async {
    try {
      await remoteDataSource.deleteArea(id);
    } catch (e) {
      throw AppException('Failed to delete area: $e');
    }
  }
}