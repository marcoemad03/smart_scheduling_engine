import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';

abstract class StaffingRepository {
  Stream<List<StaffingRequirementEntity>> getRequirements();
  Future<List<StaffingRequirementEntity>> getRequirementsOnce();
  Future<void> saveRequirement(StaffingRequirementEntity requirement);
  Future<void> deleteRequirement(String requirementId);
}
