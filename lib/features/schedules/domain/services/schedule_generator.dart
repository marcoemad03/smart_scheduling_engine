import '../../domain/entities/schedule_entities.dart';
import '../../../core/constants/enums.dart';

class ScheduleGenerator {
  final SystemSettings settings;
  final List<Employee> employees;
  final List<ReceptionArea> areas;
  final List<StaffingRequirement> requirements;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;

  ScheduleGenerator({
    required this.settings,
    required this.employees,
    required this.areas,
    required this.requirements,
    required this.availabilities,
    required this.leaves,
  });

  Future<WeeklySchedule> generateWeekSchedule(DateTime weekStart) async {
    final assignments = <ScheduleAssignment>[];
    final weekEnd = weekStart.add(const Duration(days: 6));

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final currentDate = weekStart.add(Duration(days: dayOffset));
      final dayAssignments = await _generateDayAssignments(currentDate);
      assignments.addAll(dayAssignments);
    }

    return WeeklySchedule(
      id: '${weekStart.year}-${weekStart.month}-${weekStart.day}',
      weekStartDate: weekStart,
      weekEndDate: weekEnd,
      version: 1,
      status: ScheduleStatus.draft,
      createdBy: '',
      createdAt: DateTime.now(),
      assignments: assignments,
    );
  }

  Future<List<ScheduleAssignment>> _generateDayAssignments(DateTime date) async {
    final assignments = <ScheduleAssignment>[];
    final dayOfWeek = date.weekday % 7;

    for (final requirement in requirements.where((r) => r.dayOfWeek == dayOfWeek)) {
      final area = areas.firstWhere((a) => a.areaId == requirement.areaId);
      final shiftTemplate = _getShiftTemplate(requirement.shiftTemplateId);
      
      final neededCount = requirement.requiredCount;
      int assignedCount = 0;

      final availableEmployees = await _getAvailableEmployees(date, area, shiftTemplate);
      
      for (final employee in availableEmployees) {
        if (assignedCount >= neededCount) break;

        final assignment = _createAssignment(employee.employeeId, area.areaId, date, shiftTemplate);
        
        if (_canAssignEmployee(employee, assignment, assignments)) {
          assignments.add(assignment);
          assignedCount++;
        }
      }
    }

    return assignments;
  }

  ShiftTemplate _getShiftTemplate(String? templateId) {
    if (templateId == null) return settings.shiftTemplates.first;
    return settings.shiftTemplates.firstWhere(
      (st) => st.templateId == templateId,
      orElse: () => settings.shiftTemplates.first,
    );
  }

  Future<List<Employee>> _getAvailableEmployees(
    DateTime date,
    ReceptionArea area,
    ShiftTemplate shiftTemplate,
  ) async {
    final startDateTime = _calculateStartDateTime(date, shiftTemplate);
    final endDateTime = startDateTime.add(Duration(minutes: shiftTemplate.durationMinutes));

    return employees.where((employee) => employee.isActive).where((employee) {
      // Check availability
      final hasBlock = availabilities.any((a) => 
        a.employeeId == employee.employeeId &&
        !a.isAvailable &&
        startDateTime.isAfter(a.startDateTime) &&
        endDateTime.isBefore(a.endDateTime)
      );
      if (hasBlock) return false;

      // Check leave conflicts
      final hasLeave = leaves.any((l) =>
        l.employeeId == employee.employeeId &&
        l.status == LeaveStatus.approved &&
        startDateTime.isAfter(l.startDateTime) &&
        endDateTime.isBefore(l.endDateTime)
      );
      if (hasLeave) return false;

      // Prefer employees who prefer this area
      final prefersArea = employee.preferredAreas.contains(area.areaId);
      return true;
    }).toList()
      ..sort((a, b) {
        final aPrefers = a.preferredAreas.contains(area.areaId);
        final bPrefers = b.preferredAreas.contains(area.areaId);
        if (aPrefers && !bPrefers) return -1;
        if (!aPrefers && bPrefers) return 1;
        return 0;
      });
  }

  ScheduleAssignment _createAssignment(
    String employeeId,
    String areaId,
    DateTime date,
    ShiftTemplate shiftTemplate,
  ) {
    final startDateTime = _calculateStartDateTime(date, shiftTemplate);
    final endDateTime = startDateTime.add(Duration(minutes: shiftTemplate.durationMinutes));

    return ScheduleAssignment(
      id: Uuid().v4(),
      employeeId: employeeId,
      areaId: areaId,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      shiftTemplateId: shiftTemplate.templateId,
      scheduledDate: date,
    );
  }

  bool _canAssignEmployee(
    Employee employee,
    ScheduleAssignment assignment,
    List<ScheduleAssignment> existingAssignments,
  ) {
    final employeeAssignments = existingAssignments.where(
      (a) => a.employeeId == employee.employeeId,
    );

    // Check overlaps
    for (final existing in employeeAssignments) {
      if (assignment.overlapsWith(existing)) return false;
    }

    // Check rest period
    for (final existing in employeeAssignments) {
      if (assignment.startDateTime.isAfter(existing.endDateTime)) {
        final gap = assignment.startDateTime.difference(existing.endDateTime).inMinutes;
        if (gap < settings.minRestPeriodMinutes && gap > 0) return false;
      }
    }

    // Check max hours
    final weekStart = DateTimeUtils.getStartOfWeek(assignment.scheduledDate);
    final weekAssignments = existingAssignments.where(
      (a) => a.employeeId == employee.employeeId &&
             a.scheduledDate.isAfter(weekStart) &&
             a.scheduledDate.isBefore(weekStart.add(const Duration(days: 7))),
    );
    
    final totalHours = weekAssignments.fold<double>(
      0,
      (sum, a) => sum + a.duration.inHours.toDouble(),
    ) + assignment.duration.inHours.toDouble();

    if (totalHours > employee.maxWeeklyHours) return false;

    return true;
  }

  DateTime _calculateStartDateTime(DateTime date, ShiftTemplate template) {
    final hour = template.startMinute ~/ 60;
    final minute = template.startMinute % 60;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

// Employee domain entity (simplified)
class Employee {
  final String employeeId;
  final String firstName;
  final String lastName;
  final double maxWeeklyHours;
  final List<String> preferredAreas;
  final bool isActive;

  Employee({
    required this.employeeId,
    required this.firstName,
    required this.lastName,
    required this.maxWeeklyHours,
    required this.preferredAreas,
    required this.isActive,
  });

  String get fullName => '$firstName $lastName';
}