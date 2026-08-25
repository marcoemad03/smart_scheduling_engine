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

  ShiftTemplateEntity copyWith({
    String? name,
    int? startMinute,
    int? durationMinutes,
    bool? isNightShift,
    int? colorValue,
    bool? isActive,
  }) {
    return ShiftTemplateEntity(
      templateId: templateId,
      name: name ?? this.name,
      startMinute: startMinute ?? this.startMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isNightShift: isNightShift ?? this.isNightShift,
      colorValue: colorValue ?? this.colorValue,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
