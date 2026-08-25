class StaffingRequirementEntity {
  final String requirementId;
  final String areaId;
  final int dayOfWeek;
  final int startMinute;
  final int endMinute;
  final int requiredCount;
  final String? shiftTemplateId;
  final int minHoursPerWeek;
  final DateTime createdAt;

  StaffingRequirementEntity({
    required this.requirementId,
    required this.areaId,
    required this.dayOfWeek,
    this.startMinute = 0,
    this.endMinute = 1440,
    required this.requiredCount,
    this.shiftTemplateId,
    this.minHoursPerWeek = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOvernightWindow => endMinute <= startMinute;

  int get windowDurationMinutes =>
      isOvernightWindow ? (1440 - startMinute) + endMinute : endMinute - startMinute;

  String get windowLabel =>
      '${_formatMinute(startMinute)} → ${_formatMinute(endMinute)}';

  static String _formatMinute(int minute) {
    final m = ((minute % 1440) + 1440) % 1440;
    final h = (m ~/ 60).toString().padLeft(2, '0');
    final mins = (m % 60).toString().padLeft(2, '0');
    return '$h:$mins';
  }

  /// Returns the overlap duration in minutes between this requirement window
  /// and a shift segment expressed in minutes-of-day. Handles overnight windows.
  int overlapWithSegment(int segStartMinute, int segEndMinute) {
    int windowOverlap(int winStart, int winEnd) {
      final s = segStartMinute > winStart ? segStartMinute : winStart;
      final e = segEndMinute < winEnd ? segEndMinute : winEnd;
      return e > s ? e - s : 0;
    }

    if (!isOvernightWindow) {
      return windowOverlap(startMinute, endMinute);
    }
    return windowOverlap(startMinute, 1440) + windowOverlap(0, endMinute);
  }

  StaffingRequirementEntity copyWith({
    String? requirementId,
    String? areaId,
    int? dayOfWeek,
    int? startMinute,
    int? endMinute,
    int? requiredCount,
    String? shiftTemplateId,
    int? minHoursPerWeek,
  }) {
    return StaffingRequirementEntity(
      requirementId: requirementId ?? this.requirementId,
      areaId: areaId ?? this.areaId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      requiredCount: requiredCount ?? this.requiredCount,
      shiftTemplateId: shiftTemplateId ?? this.shiftTemplateId,
      minHoursPerWeek: minHoursPerWeek ?? this.minHoursPerWeek,
      createdAt: createdAt,
    );
  }
}
