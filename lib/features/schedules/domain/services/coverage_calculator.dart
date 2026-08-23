import '../../domain/entities/schedule_entities.dart';
import '../../../core/constants/enums.dart';
import 'package:collection/collection.dart';

class CoverageCalculator {
  final SystemSettings settings;

  CoverageCalculator({required this.settings});

  CoverageResult calculateDayCoverage(
    DateTime date,
    List<ScheduleAssignment> assignments,
    List<StaffingRequirement> requirements,
    List<ReceptionArea> areas,
  ) {
    final areaCoverages = <AreaCoverage>[];
    final dayRequirements = requirements.where((r) => r.dayOfWeek == date.weekday % 7).toList();
    
    for (final requirement in dayRequirements) {
      final area = areas.firstWhere((a) => a.areaId == requirement.areaId);
      final shiftTemplate = settings.shiftTemplates.firstWhere(
        (st) => st.templateId == requirement.shiftTemplateId,
        orElse: () => settings.shiftTemplates.first,
      );
      
      final expectedStart = _calculateStartDateTime(date, shiftTemplate);
      final expectedEnd = expectedStart.add(Duration(minutes: shiftTemplate.durationMinutes));
      
      final relevantAssignments = assignments.where((a) => 
        a.areaId == area.areaId &&
        a.startDateTime.isBefore(expectedEnd) &&
        a.endDateTime.isAfter(expectedStart)
      ).toList();
      
      final requiredCount = requirement.requiredCount;
      final assignedCount = relevantAssignments.length;
      final coveragePct = requiredCount > 0 
          ? (assignedCount / requiredCount * 100).clamp(0, 100)
          : 100.0;
          
      final gaps = _findCoverageGaps(
        expectedStart, 
        expectedEnd, 
        relevantAssignments,
      );

      areaCoverages.add(AreaCoverage(
        areaId: area.areaId,
        areaName: area.name,
        requiredCount: requiredCount,
        assignedCount: assignedCount,
        coveragePercentage: coveragePct,
        assignments: relevantAssignments,
        gaps: gaps,
      ));
    }

    final overallCoverage = areaCoverages.isNotEmpty
        ? areaCoverages.map((a) => a.coveragePercentage).average
        : 0.0;

    final allGaps = areaCoverages.expand((a) => a.gaps).toList();

    return CoverageResult(
      date: date,
      areaCoverages: areaCoverages,
      gaps: allGaps,
      overallCoveragePercentage: overallCoverage,
    );
  }

  List<ShiftGap> _findCoverageGaps(
    DateTime shiftStart,
    DateTime shiftEnd,
    List<ScheduleAssignment> assignments,
  ) {
    if (assignments.isEmpty) return [ShiftGap(start: shiftStart, end: shiftEnd)];
    
    final sortedAssignments = assignments..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
    final gaps = <ShiftGap>[];
    
    var current = shiftStart;
    for (final assignment in sortedAssignments) {
      if (assignment.startDateTime.isAfter(current)) {
        gaps.add(ShiftGap(start: current, end: assignment.startDateTime));
      }
      current = assignment.endDateTime.isAfter(current) 
          ? assignment.endDateTime 
          : current;
    }
    
    if (current.isBefore(shiftEnd)) {
      gaps.add(ShiftGap(start: current, end: shiftEnd));
    }
    
    return gaps;
  }

  DateTime _calculateStartDateTime(DateTime date, ShiftTemplate template) {
    final hour = template.startMinute ~/ 60;
    final minute = template.startMinute % 60;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

// Domain models for coverage
class CoverageResult {
  final DateTime date;
  final List<AreaCoverage> areaCoverages;
  final List<ShiftGap> gaps;
  final double overallCoveragePercentage;

  CoverageResult({
    required this.date,
    required this.areaCoverages,
    required this.gaps,
    required this.overallCoveragePercentage,
  });
}

class AreaCoverage {
  final String areaId;
  final String areaName;
  final int requiredCount;
  final int assignedCount;
  final double coveragePercentage;
  final List<ScheduleAssignment> assignments;
  final List<ShiftGap> gaps;

  AreaCoverage({
    required this.areaId,
    required this.areaName,
    required this.requiredCount,
    required this.assignedCount,
    required this.coveragePercentage,
    required this.assignments,
    required this.gaps,
  });
}

class ShiftGap {
  final DateTime start;
  final DateTime end;
  final Duration duration => end.difference(start);

  ShiftGap({required this.start, required this.end});
}

class ScheduleConflict {
  final String id;
  final ConflictType type;
  final ConflictSeverity severity;
  final String? employeeId;
  final String? areaId;
  final String? assignmentId1;
  final String? assignmentId2;
  final String message;

  ScheduleConflict({
    required this.id,
    required this.type,
    required this.severity,
    this.employeeId,
    this.areaId,
    this.assignmentId1,
    this.assignmentId2,
    required this.message,
  });
}

class AvailabilityBlock {
  final String employeeId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isAvailable;
  final bool isRecurring;
  final List<int>? recurrenceDays;

  AvailabilityBlock({
    required this.employeeId,
    required this.startDateTime,
    required this.endDateTime,
    required this.isAvailable,
    required this.isRecurring,
    this.recurrenceDays,
  });
}

class LeaveRequest {
  final String employeeId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final LeaveStatus status;

  LeaveRequest({
    required this.employeeId,
    required this.startDateTime,
    required this.endDateTime,
    required this.status,
  });
}

class ReceptionArea {
  final String areaId;
  final String name;

  ReceptionArea({required this.areaId, required this.name});
}

class ShiftTemplate {
  final String templateId;
  final String name;
  final int startMinute;
  final int durationMinutes;
  final bool isNightShift;
  final int colorValue;

  ShiftTemplate({
    required this.templateId,
    required this.name,
    required this.startMinute,
    required this.durationMinutes,
    required this.isNightShift,
    required this.colorValue,
  });
}

class StaffingRequirement {
  final String areaId;
  final int dayOfWeek;
  final int requiredCount;
  final String? shiftTemplateId;
  final int minHoursPerWeek;

  StaffingRequirement({
    required this.areaId,
    required this.dayOfWeek,
    required this.requiredCount,
    this.shiftTemplateId,
    required this.minHoursPerWeek,
  });
}

class SystemSettings {
  final double maxWeeklyHours;
  final int minRestPeriodMinutes;
  final int workingHoursStart;
  final int workingHoursEnd;
  final List<ShiftTemplate> shiftTemplates;

  SystemSettings({
    required this.maxWeeklyHours,
    required this.minRestPeriodMinutes,
    required this.workingHoursStart,
    required this.workingHoursEnd,
    required this.shiftTemplates,
  });
}