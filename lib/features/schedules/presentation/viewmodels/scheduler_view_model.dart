import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/repositories/schedule_repository.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/schedule_generator.dart';
import 'package:uuid/uuid.dart';

class SchedulerState {
  final bool isLoading;
  final String? error;
  final DateTime weekStart;
  final WeeklySchedule? schedule;
  final List<Employee> employees;
  final List<ReceptionArea> areas;
  final SystemSettings? settings;
  final List<StaffingRequirementEntity> staffingRequirements;
  final List<ShiftTemplateEntity> shiftTemplates;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;
  final Map<String, List<ScheduleConflict>> conflictsByAssignment;
  final List<ScheduleConflict> staffingConflicts;
  final WeekCoverageResult? weekCoverage;
  final Set<String> overriddenAssignmentIds;
  final bool hasUnsavedChanges;
  final ScheduleAssignment? selectedAssignment;

  const SchedulerState({
    this.isLoading = false,
    this.error,
    required this.weekStart,
    this.schedule,
    this.employees = const [],
    this.areas = const [],
    this.settings,
    this.staffingRequirements = const [],
    this.shiftTemplates = const [],
    this.availabilities = const [],
    this.leaves = const [],
    this.conflictsByAssignment = const {},
    this.staffingConflicts = const [],
    this.weekCoverage,
    this.overriddenAssignmentIds = const {},
    this.hasUnsavedChanges = false,
    this.selectedAssignment,
  });

  SchedulerState copyWith({
    bool? isLoading,
    String? error,
    DateTime? weekStart,
    WeeklySchedule? schedule,
    List<Employee>? employees,
    List<ReceptionArea>? areas,
    SystemSettings? settings,
    List<StaffingRequirementEntity>? staffingRequirements,
    List<ShiftTemplateEntity>? shiftTemplates,
    List<AvailabilityBlock>? availabilities,
    List<LeaveRequest>? leaves,
    Map<String, List<ScheduleConflict>>? conflictsByAssignment,
    List<ScheduleConflict>? staffingConflicts,
    WeekCoverageResult? weekCoverage,
    Set<String>? overriddenAssignmentIds,
    bool? hasUnsavedChanges,
    ScheduleAssignment? selectedAssignment,
  }) {
    return SchedulerState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      weekStart: weekStart ?? this.weekStart,
      schedule: schedule ?? this.schedule,
      employees: employees ?? this.employees,
      areas: areas ?? this.areas,
      settings: settings ?? this.settings,
      staffingRequirements: staffingRequirements ?? this.staffingRequirements,
      shiftTemplates: shiftTemplates ?? this.shiftTemplates,
      availabilities: availabilities ?? this.availabilities,
      leaves: leaves ?? this.leaves,
      conflictsByAssignment: conflictsByAssignment ?? this.conflictsByAssignment,
      staffingConflicts: staffingConflicts ?? this.staffingConflicts,
      weekCoverage: weekCoverage ?? this.weekCoverage,
      overriddenAssignmentIds:
          overriddenAssignmentIds ?? this.overriddenAssignmentIds,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      selectedAssignment: selectedAssignment ?? this.selectedAssignment,
    );
  }
}

class SchedulerViewModel extends StateNotifier<SchedulerState> {
  final ScheduleRepository repository;
  final FirebaseFirestore firestore;
  final String currentUserId;
  int _loadToken = 0;

  SchedulerViewModel({
    required this.repository,
    required this.firestore,
    required this.currentUserId,
  }) : super(SchedulerState(weekStart: DateTimeUtils.getStartOfWeek(DateTime.now())));

  Future<void> loadWeek(DateTime weekStart) async {
    final token = ++_loadToken;
    state = state.copyWith(isLoading: true, error: null, weekStart: weekStart);
    try {
      final fetchedWeekStart = DateTimeUtils.getStartOfWeek(weekStart);
      final results = await Future.wait([
        repository.getScheduleByWeek(fetchedWeekStart),
        _fetchEmployees(),
        _fetchAreas(),
        _fetchSettings(),
        _fetchStaffingRequirements(),
        _fetchAvailabilities(fetchedWeekStart),
        _fetchLeaves(fetchedWeekStart),
        _fetchShiftTemplates(),
      ]);

      // A newer loadWeek call superseded this one - discard the stale data.
      if (token != _loadToken) return;

      final schedule = results[0] as WeeklySchedule?;
      final employees = results[1] as List<Employee>;
      final areas = results[2] as List<ReceptionArea>;
      final settings = results[3] as SystemSettings?;
      final staffing = results[4] as List<StaffingRequirementEntity>;
      final availabilities = results[5] as List<AvailabilityBlock>;
      final leaves = results[6] as List<LeaveRequest>;
      final templates = results[7] as List<ShiftTemplateEntity>;

      final newSchedule = schedule ??
          WeeklySchedule(
            id: '${fetchedWeekStart.year}-${fetchedWeekStart.month}-${fetchedWeekStart.day}',
            weekStartDate: fetchedWeekStart,
            weekEndDate:
                fetchedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59)),
            version: 1,
            status: ScheduleStatus.draft,
            createdBy: currentUserId,
            assignments: [],
          );

      state = state.copyWith(
        isLoading: false,
        schedule: newSchedule,
        employees: employees,
        areas: areas,
        settings: settings,
        staffingRequirements: staffing,
        availabilities: availabilities,
        leaves: leaves,
        shiftTemplates: templates,
        hasUnsavedChanges: false,
      );
      _recomputeConflicts();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<List<Employee>> _fetchEmployees() async {
    final snapshot = await firestore.collection('employees').get();
    return snapshot.docs
        .map((doc) => _employeeFromDoc(doc.data()))
        .where((e) => e.isActive)
        .toList();
  }

  Employee _employeeFromDoc(Map<String, dynamic> data) {
    return Employee(
      id: data['employeeId'] as String? ?? data['id'] as String? ?? '',
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      hireDate: data['hireDate'] != null
          ? (data['hireDate'] as Timestamp).toDate()
          : DateTime.now(),
      maxWeeklyHours:
          (data['maxWeeklyHours'] as num?)?.toDouble() ?? 48.0,
      preferredAreas: (data['preferredAreas'] as List?)?.cast<String>() ?? [],
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Future<List<ReceptionArea>> _fetchAreas() async {
    final snapshot =
        await firestore.collection('areas').orderBy('orderIndex').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ReceptionArea(
        areaId: data['areaId'] as String? ?? doc.id,
        name: data['name'] as String? ?? '',
        description: data['description'] as String? ?? '',
        orderIndex: data['orderIndex'] as int? ?? 0,
        isActive: data['isActive'] as bool? ?? true,
      );
    }).toList();
  }

  Future<SystemSettings?> _fetchSettings() async {
    final doc =
        await firestore.collection('systemSettings').doc('default').get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    return SystemSettings(
      settingsId: doc.id,
      maxWeeklyHours: (data['maxWeeklyHours'] as num?)?.toDouble() ?? 48.0,
      minRestPeriodMinutes: data['minRestPeriodMinutes'] as int? ?? 480,
      workingHoursStart: data['workingHoursStart'] as int? ?? 480,
      workingHoursEnd: data['workingHoursEnd'] as int? ?? 1320,
      allowCustomSchedules: data['allowCustomSchedules'] as bool? ?? true,
      enableAttendanceTracking:
          data['enableAttendanceTracking'] as bool? ?? false,
      timezone: data['timezone'] as String? ?? 'UTC',
      weekStartDay: data['weekStartDay'] as int? ?? 1,
      maxConsecutiveWorkingDays:
          data['maxConsecutiveWorkingDays'] as int? ?? 6,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }

  Future<List<StaffingRequirementEntity>> _fetchStaffingRequirements() async {
    final snapshot =
        await firestore.collection('staffingRequirements').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return StaffingRequirementEntity(
        requirementId: data['requirementId'] as String? ?? doc.id,
        areaId: data['areaId'] as String? ?? '',
        // 0 = applies to every day of the week.
        dayOfWeek: data['dayOfWeek'] as int? ?? 0,
        shiftTemplateId: data['shiftTemplateId'] as String? ?? '',
        requiredCount: data['requiredCount'] as int? ?? 1,
        minHoursPerWeek: data['minHoursPerWeek'] as int? ?? 0,
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<List<AvailabilityBlock>> _fetchAvailabilities(DateTime weekStart) async {
    final start = weekStart.subtract(const Duration(days: 1));
    final end = weekStart.add(const Duration(days: 8));
    final snapshot = await firestore
        .collection('availability')
        .where('startDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startDateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return AvailabilityBlock(
        availabilityId: data['availabilityId'] as String? ?? doc.id,
        employeeId: data['employeeId'] as String? ?? '',
        startDateTime: (data['startDateTime'] as Timestamp).toDate(),
        endDateTime: (data['endDateTime'] as Timestamp).toDate(),
        isAvailable: data['isAvailable'] as bool? ?? true,
        isRecurring: data['isRecurring'] as bool? ?? false,
        recurrenceDays: (data['recurrenceDays'] as List?)?.cast<int>() ?? [],
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  Future<List<LeaveRequest>> _fetchLeaves(DateTime weekStart) async {
    final start = weekStart.subtract(const Duration(days: 1));
    final end = weekStart.add(const Duration(days: 8));
    final snapshot = await firestore
        .collection('leaveRequests')
        .where('startDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startDateTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return LeaveRequest(
        requestId: data['requestId'] as String? ?? doc.id,
        employeeId: data['employeeId'] as String? ?? '',
        type: LeaveType.values.firstWhere(
          (e) => e.name == (data['type'] as String? ?? 'other'),
          orElse: () => LeaveType.other,
        ),
        startDateTime: (data['startDateTime'] as Timestamp).toDate(),
        endDateTime: (data['endDateTime'] as Timestamp).toDate(),
        status: LeaveStatus.values.firstWhere(
          (e) => e.name == (data['status'] as String? ?? 'pending'),
          orElse: () => LeaveStatus.pending,
        ),
        notes: data['notes'] as String? ?? '',
        adminNotes: data['adminNotes'] as String? ?? '',
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        approvedBy: data['approvedBy'] as String? ?? '',
        approvedAt: data['approvedAt'] != null
            ? (data['approvedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  ConflictDetector _buildDetector() {
    return ConflictDetector(
      settings: state.settings ??
          SystemSettings(
            settingsId: 'default',
            maxWeeklyHours: 48,
            minRestPeriodMinutes: 480,
            workingHoursStart: 480,
            workingHoursEnd: 1320,
            allowCustomSchedules: true,
            enableAttendanceTracking: false,
            timezone: 'UTC',
            weekStartDay: 1,
            updatedAt: DateTime.now(),
            updatedBy: currentUserId,
          ),
      areas: state.areas,
      employees: state.employees,
      availabilities: state.availabilities,
      leaves: state.leaves,
      staffingRequirements: state.staffingRequirements,
      shiftTemplates: state.shiftTemplates,
    );
  }

  void _recomputeConflicts() {
    if (state.schedule == null) return;
    final detector = _buildDetector();
    final conflicts = detector.validateSchedule(state.schedule!.assignments);
    final staffing = detector.detectStaffingGaps(state.schedule!.assignments);
    final coverage = const CoverageCalculator().calculateForWeek(
      weekStart: state.weekStart,
      assignments: state.schedule!.assignments,
      requirements:
          resolveRequirements(state.staffingRequirements, state.shiftTemplates),
    );
    state = state.copyWith(
      conflictsByAssignment: conflicts,
      staffingConflicts: staffing,
      weekCoverage: coverage,
    );
  }

  List<ScheduleConflict> getConflictsForAssignment(String assignmentId) {
    return state.conflictsByAssignment[assignmentId] ?? [];
  }

  bool hasBlockingConflicts(String assignmentId) {
    final conflicts = getConflictsForAssignment(assignmentId);
    return conflicts.any((c) =>
        c.severity == ConflictSeverity.error &&
        !state.overriddenAssignmentIds.contains(assignmentId));
  }

  // ---- Assignment mutations ----

  Future<void> _mutateAssignments(
      List<ScheduleAssignment> newAssignments, String? selectedId) async {
    if (state.schedule == null) return;
    final updated = state.schedule!.copyWith(assignments: newAssignments);
    state = state.copyWith(
      schedule: updated,
      hasUnsavedChanges: true,
      selectedAssignment: selectedId != null
          ? newAssignments.where((a) => a.id == selectedId).firstOrNull
          : state.selectedAssignment,
    );
    _recomputeConflicts();
  }

  ScheduleAssignment _newAssignment({
    required String employeeId,
    required String areaId,
    required DateTime date,
    required DateTime start,
    required DateTime end,
    String? shiftTemplateId,
    String? notes,
  }) {
    return ScheduleAssignment(
      id: const Uuid().v4(),
      employeeId: employeeId,
      areaId: areaId,
      scheduledDate: date,
      startDateTime: start,
      endDateTime: end,
      shiftTemplateId: shiftTemplateId,
      status: AssignmentStatus.draft,
      notes: notes,
      createdBy: currentUserId,
      updatedBy: currentUserId,
    );
  }

  Future<void> addAssignment({
    required String employeeId,
    required String areaId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? shiftTemplateId,
    String? notes,
  }) async {
    final start = DateTime(
        date.year, date.month, date.day, startTime.hour, startTime.minute);
    var end = DateTime(
        date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      end = end.add(const Duration(days: 1));
    }
    final assignment = _newAssignment(
      employeeId: employeeId,
      areaId: areaId,
      date: date,
      start: start,
      end: end,
      shiftTemplateId: shiftTemplateId,
      notes: notes,
    );
    final assignments = [...state.schedule!.assignments, assignment];
    await _mutateAssignments(assignments, assignment.id);
  }

  Future<void> updateAssignment(ScheduleAssignment updated) async {
    final assignments = state.schedule!.assignments
        .map((a) => a.id == updated.id
            ? updated.copyWith(updatedBy: currentUserId)
            : a)
        .toList();
    await _mutateAssignments(assignments, updated.id);
  }

  Future<void> deleteAssignment(String id) async {
    final assignments =
        state.schedule!.assignments.where((a) => a.id != id).toList();
    final conflicts = Map<String, List<ScheduleConflict>>.from(
        state.conflictsByAssignment)
      ..remove(id);
    final overridden = Set<String>.from(state.overriddenAssignmentIds)
      ..remove(id);
    state = state.copyWith(
      schedule: state.schedule!.copyWith(assignments: assignments),
      conflictsByAssignment: conflicts,
      overriddenAssignmentIds: overridden,
      hasUnsavedChanges: true,
      selectedAssignment: null,
    );
    _recomputeConflicts();
  }

  Future<void> duplicateAssignment(String id) async {
    final original =
        state.schedule!.assignments.where((a) => a.id == id).firstOrNull;
    if (original == null) return;
    final copy = original.copyWith(
      id: const Uuid().v4(),
      updatedBy: currentUserId,
    );
    final assignments = [...state.schedule!.assignments, copy];
    await _mutateAssignments(assignments, copy.id);
  }

  Future<void> moveAssignment(String id, DateTime newDate,
      {String? newEmployeeId}) async {
    final original =
        state.schedule!.assignments.where((a) => a.id == id).firstOrNull;
    if (original == null) return;
    final duration = original.duration;
    final start = DateTime(newDate.year, newDate.month, newDate.day,
        original.startDateTime.hour, original.startDateTime.minute);
    final end = start.add(duration);
    final moved = original.copyWith(
      employeeId: newEmployeeId ?? original.employeeId,
      scheduledDate: newDate,
      startDateTime: start,
      endDateTime: end,
      updatedBy: currentUserId,
    );
    final assignments = state.schedule!.assignments
        .map((a) => a.id == id ? moved : a)
        .toList();
    await _mutateAssignments(assignments, id);
  }

  Future<void> splitShift(String id, TimeOfDay splitAt) async {
    final original =
        state.schedule!.assignments.where((a) => a.id == id).firstOrNull;
    if (original == null) return;
    final splitTime = DateTime(
        original.startDateTime.year,
        original.startDateTime.month,
        original.startDateTime.day,
        splitAt.hour,
        splitAt.minute);
    if (splitTime.isBefore(original.startDateTime) ||
        splitTime.isAfter(original.endDateTime)) {
      return;
    }
    final first = original.copyWith(
      id: const Uuid().v4(),
      endDateTime: splitTime,
      updatedBy: currentUserId,
    );
    final second = original.copyWith(
      id: const Uuid().v4(),
      startDateTime: splitTime,
      updatedBy: currentUserId,
    );
    final assignments = state.schedule!.assignments
        .where((a) => a.id != id)
        .toList()
      ..addAll([first, second]);
    await _mutateAssignments(assignments, second.id);
    final overridden = Set<String>.from(state.overriddenAssignmentIds)
      ..remove(id);
    state = state.copyWith(overriddenAssignmentIds: overridden);
  }

  Future<void> copyDay(DateTime from, DateTime to) async {
    if (state.schedule == null) return;
    final fromAssignments = state.schedule!.assignments.where((a) =>
        a.scheduledDate.year == from.year &&
        a.scheduledDate.month == from.month &&
        a.scheduledDate.day == from.day);
    final newAssignments = <ScheduleAssignment>[];
    for (final a in fromAssignments) {
      final duration = a.duration;
      final start = DateTime(to.year, to.month, to.day, a.startDateTime.hour,
          a.startDateTime.minute);
      final end = start.add(duration);
      newAssignments.add(a.copyWith(
        id: const Uuid().v4(),
        scheduledDate: to,
        startDateTime: start,
        endDateTime: end,
        updatedBy: currentUserId,
      ));
    }
    final assignments = [...state.schedule!.assignments, ...newAssignments];
    await _mutateAssignments(assignments, null);
  }

  Future<void> copyPreviousWeek() async {
    final prevStart =
        state.weekStart.subtract(const Duration(days: 7));
    final prevSchedule = await repository.getScheduleByWeek(prevStart);
    if (prevSchedule == null || prevSchedule.assignments.isEmpty) return;
    final newAssignments = <ScheduleAssignment>[];
    for (final a in prevSchedule.assignments) {
      final offset = state.weekStart.difference(prevStart).inDays;
      final newDate = a.scheduledDate.add(Duration(days: offset));
      final newStart = DateTime(newDate.year, newDate.month, newDate.day,
          a.startDateTime.hour, a.startDateTime.minute);
      final duration = a.duration;
      newAssignments.add(a.copyWith(
        id: const Uuid().v4(),
        scheduledDate: newDate,
        startDateTime: newStart,
        endDateTime: newStart.add(duration),
        status: AssignmentStatus.draft,
        updatedBy: currentUserId,
      ));
    }
    final assignments = [...state.schedule!.assignments, ...newAssignments];
    await _mutateAssignments(assignments, null);
  }

  Future<void> bulkAssign({
    required List<String> employeeIds,
    required String areaId,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? shiftTemplateId,
  }) async {
    final start = DateTime(
        date.year, date.month, date.day, startTime.hour, startTime.minute);
    var end = DateTime(
        date.year, date.month, date.day, endTime.hour, endTime.minute);
    if (end.isBefore(start) || end.isAtSameMomentAs(start)) {
      end = end.add(const Duration(days: 1));
    }
    final newOnes = employeeIds
        .map((eid) => _newAssignment(
              employeeId: eid,
              areaId: areaId,
              date: date,
              start: start,
              end: end,
              shiftTemplateId: shiftTemplateId,
            ))
        .toList();
    final assignments = [...state.schedule!.assignments, ...newOnes];
    await _mutateAssignments(assignments, null);
  }

  Future<void> bulkMove(List<String> assignmentIds, DateTime newDate,
      {String? newEmployeeId}) async {
    final assignments = state.schedule!.assignments.map((a) {
      if (!assignmentIds.contains(a.id)) return a;
      final duration = a.duration;
      final start = DateTime(newDate.year, newDate.month, newDate.day,
          a.startDateTime.hour, a.startDateTime.minute);
      return a.copyWith(
        employeeId: newEmployeeId ?? a.employeeId,
        scheduledDate: newDate,
        startDateTime: start,
        endDateTime: start.add(duration),
        updatedBy: currentUserId,
      );
    }).toList();
    await _mutateAssignments(assignments, null);
  }

  void overrideConflict(String assignmentId) {
    final overridden = Set<String>.from(state.overriddenAssignmentIds)
      ..add(assignmentId);
    final assignment = state.schedule!.assignments
        .where((a) => a.id == assignmentId)
        .firstOrNull;
    List<ScheduleAssignment>? newAssignments;
    if (assignment != null) {
      newAssignments = state.schedule!.assignments
          .map((a) => a.id == assignmentId
              ? a.copyWith(
                  status: AssignmentStatus.overridden, updatedBy: currentUserId)
              : a)
          .toList();
    }
    state = state.copyWith(
      overriddenAssignmentIds: overridden,
      schedule: newAssignments != null
          ? state.schedule!.copyWith(assignments: newAssignments)
          : state.schedule,
      hasUnsavedChanges: true,
    );
  }

  void selectAssignment(String? id) {
    final selected = id != null
        ? state.schedule!.assignments.where((a) => a.id == id).firstOrNull
        : null;
    state = state.copyWith(selectedAssignment: selected);
  }

  // ---- Persistence / lifecycle ----

  Future<void> saveDraft() async {
    if (state.schedule == null) return;
    try {
      final draft = state.schedule!.copyWith(status: ScheduleStatus.draft);
      await repository.saveSchedule(draft);
      state = state.copyWith(schedule: draft, hasUnsavedChanges: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  List<ScheduleConflict> validateSchedule() {
    _recomputeConflicts();
    final all = <ScheduleConflict>[];
    for (final c in state.conflictsByAssignment.values) all.addAll(c);
    all.addAll(state.staffingConflicts);
    return all;
  }

  Future<void> publish() async {
    if (state.schedule == null) return;
    try {
      final published = state.schedule!.copyWith(
        status: ScheduleStatus.published,
        publishedAt: DateTime.now(),
        assignments: state.schedule!.assignments
            .map((a) => a.status == AssignmentStatus.overridden
                ? a
                : a.copyWith(status: AssignmentStatus.published))
            .toList(),
      );
      await repository.saveSchedule(published);
      state = state.copyWith(schedule: published, hasUnsavedChanges: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> unpublish() async {
    if (state.schedule == null) return;
    try {
      final draft = state.schedule!.copyWith(
        status: ScheduleStatus.draft,
        publishedAt: null,
      );
      await repository.saveSchedule(draft);
      state = state.copyWith(schedule: draft, hasUnsavedChanges: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> newVersion() async {
    if (state.schedule == null) return;
    try {
      final next = state.schedule!.copyWith(
        version: state.schedule!.version + 1,
        status: ScheduleStatus.draft,
        publishedAt: null,
        assignments:
            state.schedule!.assignments.map((a) => a.copyWith(
              id: const Uuid().v4(),
              status: AssignmentStatus.draft,
              updatedBy: currentUserId,
            )).toList(),
      );
      state = state.copyWith(schedule: next, hasUnsavedChanges: true);
      await repository.saveSchedule(next);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> saveAsTemplate(String name) async {
    if (state.schedule == null) return;
    await repository.saveScheduleTemplate(state.schedule!, name);
  }

  Future<void> applyTemplate(WeeklySchedule template) async {
    if (state.schedule == null) return;
    final offset = state.weekStart
        .difference(DateTimeUtils.getStartOfWeek(template.weekStartDate))
        .inDays;
    final newOnes = template.assignments.map((a) {
      final newDate = a.scheduledDate.add(Duration(days: offset));
      final start = DateTime(newDate.year, newDate.month, newDate.day,
          a.startDateTime.hour, a.startDateTime.minute);
      final duration = a.duration;
      return a.copyWith(
        id: const Uuid().v4(),
        scheduledDate: newDate,
        startDateTime: start,
        endDateTime: start.add(duration),
        status: AssignmentStatus.draft,
        updatedBy: currentUserId,
      );
    }).toList();
    final assignments = [...state.schedule!.assignments, ...newOnes];
    await _mutateAssignments(assignments, null);
  }

  // ---- Smart generation ----

  /// Runs the smart generator for the current week and replaces the in-memory
  /// schedule with the produced DRAFT. Never publishes.
  Future<GenerationResult?> generateSchedule() async {
    if (state.schedule == null) return null;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final templates = await _fetchShiftTemplates();
      // Overridden (admin-locked) assignments are treated as fixed inputs;
      // the generator fills the remaining requirements around them.
      final fixed = state.schedule!.assignments
          .where((a) => a.status == AssignmentStatus.overridden)
          .toList();
      final generator = ScheduleGenerator(
        settings: state.settings ??
            SystemSettings(
              settingsId: 'default',
              maxWeeklyHours: 48,
              minRestPeriodMinutes: 480,
              workingHoursStart: 480,
              workingHoursEnd: 1320,
              allowCustomSchedules: true,
              enableAttendanceTracking: false,
              timezone: 'UTC',
              weekStartDay: 1,
              updatedAt: DateTime.now(),
              updatedBy: currentUserId,
            ),
        employees: state.employees,
        areas: state.areas,
        requirements: state.staffingRequirements,
        shiftTemplates: templates,
        availabilities: state.availabilities,
        leaves: state.leaves,
        fixedAssignments: fixed,
        weekStart: state.weekStart,
        createdBy: currentUserId,
      );
      final result = generator.generate();
      final draft = result.draft.copyWith(
        id: state.schedule!.id,
        version: state.schedule!.version,
      );
      state = state.copyWith(
        isLoading: false,
        schedule: draft,
        hasUnsavedChanges: true,
        selectedAssignment: null,
        overriddenAssignmentIds: {},
      );
      _recomputeConflicts();
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<List<ShiftTemplateEntity>> _fetchShiftTemplates() async {
    final snapshot =
        await firestore.collection('shiftTemplates').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return ShiftTemplateEntity(
        templateId: data['templateId'] as String? ?? doc.id,
        name: data['name'] as String? ?? '',
        startMinute: data['startMinute'] as int? ?? 480,
        durationMinutes: data['durationMinutes'] as int? ?? 420,
        isNightShift: data['isNightShift'] as bool? ?? false,
        colorValue: data['colorValue'] as int? ?? 0xFF2196F3,
        isActive: data['isActive'] as bool? ?? true,
        createdAt: data['createdAt'] != null
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: data['updatedAt'] != null
            ? (data['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
      );
    }).toList();
  }

  /// Applies admin-approved assistant changes to the in-memory DRAFT.
  /// Persistence still goes through saveDraft/publish - never direct writes.
  void adoptProposedAssignments(List<ScheduleAssignment> assignments) {
    if (state.schedule == null) return;
    final updated =
        state.schedule!.copyWith(assignments: List.from(assignments));
    state = state.copyWith(
      schedule: updated,
      hasUnsavedChanges: true,
      selectedAssignment: null,
    );
    _recomputeConflicts();
  }

  void changeWeek(int direction) {
    final newStart =
        state.weekStart.add(Duration(days: 7 * direction));
    loadWeek(newStart);
  }
}
