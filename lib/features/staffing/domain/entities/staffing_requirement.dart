class StaffingRequirementEntity {
  final String requirementId;
  final String areaId;
  final int dayOfWeek;
  final int requiredCount;
  final String? shiftTemplateId;
  final int minHoursPerWeek;
  final DateTime createdAt;

  StaffingRequirementEntity({
    required this.requirementId,
    required this.areaId,
    required this.dayOfWeek,
    required this.requiredCount,
    this.shiftTemplateId,
    required this.minHoursPerWeek,
    required this.createdAt,
  });
}

