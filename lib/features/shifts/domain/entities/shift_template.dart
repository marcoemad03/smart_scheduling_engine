class ShiftTemplateEntity {
  final String templateId;
  final String name;
  final int startMinute;
  final int durationMinutes;
  final bool isNightShift;
  final int colorValue;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShiftTemplateEntity({
    required this.templateId,
    required this.name,
    required this.startMinute,
    required this.durationMinutes,
    required this.isNightShift,
    required this.colorValue,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}

