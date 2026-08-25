import 'package:reception_workforce_scheduler/features/staffing/data/datasources/staffing_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/repositories/staffing_repository.dart';

class StaffingRepositoryImpl implements StaffingRepository {
  final StaffingRemoteDataSource remoteDataSource;

  StaffingRepositoryImpl({required this.remoteDataSource});

  @override
  Stream<List<StaffingRequirementEntity>> getRequirements() =>
      remoteDataSource.getRequirements();

  @override
  Future<List<StaffingRequirementEntity>> getRequirementsOnce() =>
      remoteDataSource.getRequirementsOnce();

  @override
  Future<void> saveRequirement(StaffingRequirementEntity requirement) =>
      remoteDataSource.saveRequirement(requirement);

  @override
  Future<void> deleteRequirement(String requirementId) =>
      remoteDataSource.deleteRequirement(requirementId);
}
