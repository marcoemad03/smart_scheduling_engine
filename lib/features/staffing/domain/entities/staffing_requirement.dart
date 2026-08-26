import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';

/// A staffing requirement expressed WITHOUT concrete times: the Admin picks
/// a reception area, a shift template and a headcount. The shift template is
/// the single source of truth for the start/end time.
///
/// [dayOfWeek] uses ISO weekdays (1=Monday..7=Sunday); `0` means the
/// requirement applies to EVERY day of the week.
class StaffingRequirementEntity {
  final String requirementId;
  final String areaId;

  /// ISO weekday (1=Mon..7=Sun) or 0 for every day.
  final int dayOfWeek;

  /// Shift template providing the start/end time. Never store times here.
  final String shiftTemplateId;
  final int requiredCount;
  final int minHoursPerWeek;
  final DateTime createdAt;

  StaffingRequirementEntity({
    required this.requirementId,
    required this.areaId,
    required this.dayOfWeek,
    required this.shiftTemplateId,
    required this.requiredCount,
    this.minHoursPerWeek = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  StaffingRequirementEntity copyWith({
    String? requirementId,
    String? areaId,
    int? dayOfWeek,
    String? shiftTemplateId,
    int? requiredCount,
    int? minHoursPerWeek,
  }) {
    return StaffingRequirementEntity(
      requirementId: requirementId ?? this.requirementId,
      areaId: areaId ?? this.areaId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      shiftTemplateId: shiftTemplateId ?? this.shiftTemplateId,
      requiredCount: requiredCount ?? this.requiredCount,
      minHoursPerWeek: minHoursPerWeek ?? this.minHoursPerWeek,
      createdAt: createdAt,
    );
  }
}

/// A [StaffingRequirementEntity] with its time window resolved from the
/// linked shift template. This is what the coverage/scheduling engines
/// consume; times are never persisted on the requirement itself.
class ResolvedRequirement {
  final String requirementId;
  final String areaId;
  final int dayOfWeek;
  final int requiredCount;
  final String shiftTemplateId;
  final String templateName;
  final int startMinute;
  final int endMinute;

  const ResolvedRequirement({
    required this.requirementId,
    required this.areaId,
    required this.dayOfWeek,
    required this.requiredCount,
    required this.shiftTemplateId,
    required this.templateName,
    required this.startMinute,
    required this.endMinute,
  });

  bool get isOvernightWindow => endMinute <= startMinute;

  String get windowLabel =>
      '${_formatMinute(startMinute)} → ${_formatMinute(endMinute)}';

  static String _formatMinute(int minute) {
    final m = ((minute % 1440) + 1440) % 1440;
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mins = (m % 60).toString().padLeft(2, '0');
    return '$h:$mins';
  }
}

/// Resolves requirements against shift templates. Requirements whose
/// template no longer exists are skipped (the admin UI surfaces them as
/// broken instead of feeding wrong times into the engines).
List<ResolvedRequirement> resolveRequirements(
  List<StaffingRequirementEntity> requirements,
  List<ShiftTemplateEntity> templates,
) {
  final byId = {for (final t in templates) t.templateId: t};
  final resolved = <ResolvedRequirement>[];
  for (final r in requirements) {
    final template = byId[r.shiftTemplateId];
    if (template == null) continue;
    final end = template.startMinute + template.durationMinutes;
    resolved.add(ResolvedRequirement(
      requirementId: r.requirementId,
      areaId: r.areaId,
      dayOfWeek: r.dayOfWeek,
      requiredCount: r.requiredCount,
      shiftTemplateId: r.shiftTemplateId,
      templateName: template.name,
      // Normalize a 24h+ shift into a (possibly overnight) window.
      startMinute: template.startMinute % 1440,
      endMinute: end % 1440 == 0 ? 1440 : end % 1440,
    ));
  }
  return resolved;
}
