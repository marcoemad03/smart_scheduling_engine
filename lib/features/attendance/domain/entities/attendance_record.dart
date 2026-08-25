/// ATTENDANCE = ACTUAL WORK. A schedule is PLANNED WORK.
/// This record preserves both sides independently:
/// - scheduledStart/scheduledEnd are copied from the published assignment
///   at creation time and NEVER change when attendance changes.
/// - actualCheckIn/actualCheckOut capture reality.
class AttendanceRecord {
  final String recordId;
  final String employeeId;
  final String assignmentId;

  // Planned (immutable snapshot of the schedule).
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  // Actual.
  final DateTime? actualCheckIn;
  final DateTime? actualCheckOut;

  // Derived deltas (minutes).
  final int lateMinutes;
  final int earlyLeaveMinutes;
  final int overtimeMinutes;

  final AttendanceStatus status;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Grace period in minutes before lateness/overtime is counted.
  static const graceMinutes = 5;

  AttendanceRecord({
    required this.recordId,
    required this.employeeId,
    required this.assignmentId,
    required this.scheduledStart,
    required this.scheduledEnd,
    this.actualCheckIn,
    this.actualCheckOut,
    this.lateMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.overtimeMinutes = 0,
    this.status = AttendanceStatus.scheduled,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Duration get scheduledDuration => scheduledEnd.difference(scheduledStart);

  Duration? get actualDuration => actualCheckIn != null && actualCheckOut != null
      ? actualCheckOut!.difference(actualCheckIn!)
      : null;

  /// Creates a planned-only record from a published assignment.
  /// The schedule itself is never touched or modified.
  factory AttendanceRecord.planned({
    required String assignmentId,
    required String employeeId,
    required DateTime scheduledStart,
    required DateTime scheduledEnd,
  }) {
    return AttendanceRecord(
      recordId: 'att-$assignmentId',
      employeeId: employeeId,
      assignmentId: assignmentId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      status: AttendanceStatus.scheduled,
      notes: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  AttendanceRecord withCheckIn(DateTime now) {
    final late = now.difference(scheduledStart).inMinutes;
    return _copyWith(
      actualCheckIn: now,
      lateMinutes: late > graceMinutes ? late : 0,
      status: late > graceMinutes ? AttendanceStatus.late : AttendanceStatus.present,
    );
  }

  AttendanceRecord withCheckOut(DateTime now) {
    if (actualCheckIn == null) return this;
    final early = scheduledEnd.difference(now).inMinutes;
    final over = now.difference(scheduledEnd).inMinutes;
    var status = lateMinutes > 0 ? AttendanceStatus.late : AttendanceStatus.present;
    if (status == AttendanceStatus.present && early > graceMinutes) {
      status = AttendanceStatus.earlyLeave;
    }
    return _copyWith(
      actualCheckOut: now,
      earlyLeaveMinutes: early > graceMinutes ? early : 0,
      overtimeMinutes: over > graceMinutes ? over : 0,
      status: status,
    );
  }

  AttendanceRecord markAbsent([String note = '']) => _copyWith(
        status: AttendanceStatus.absent,
        notes: note.isEmpty ? notes : note,
      );

  AttendanceRecord withNotes(String newNotes) =>
      _copyWith(notes: newNotes);

  AttendanceRecord _copyWith({
    DateTime? actualCheckIn,
    DateTime? actualCheckOut,
    int? lateMinutes,
    int? earlyLeaveMinutes,
    int? overtimeMinutes,
    AttendanceStatus? status,
    String? notes,
  }) {
    return AttendanceRecord(
      recordId: recordId,
      employeeId: employeeId,
      assignmentId: assignmentId,
      scheduledStart: scheduledStart,
      scheduledEnd: scheduledEnd,
      actualCheckIn: actualCheckIn ?? this.actualCheckIn,
      actualCheckOut: actualCheckOut ?? this.actualCheckOut,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      earlyLeaveMinutes: earlyLeaveMinutes ?? this.earlyLeaveMinutes,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// One status per record; Early Leave / Overtime are additionally expressed
/// through their minute counters so a shift can be both late AND overtime.
enum AttendanceStatus { scheduled, present, late, earlyLeave, absent }

/// Aggregated metrics over a set of records.
class AttendanceSummary {
  final int total;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int earlyLeaveCount;
  final int overtimeCount;
  final int totalOvertimeMinutes;
  final int totalLateMinutes;

  const AttendanceSummary({
    required this.total,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.earlyLeaveCount,
    required this.overtimeCount,
    required this.totalOvertimeMinutes,
    required this.totalLateMinutes,
  });

  factory AttendanceSummary.of(List<AttendanceRecord> records) {
    var present = 0,
        late = 0,
        absent = 0,
        early = 0,
        ot = 0,
        otMins = 0,
        lateMins = 0;
    for (final r in records) {
      if (r.status == AttendanceStatus.absent) {
        absent++;
        continue;
      }
      if (r.actualCheckIn == null) continue; // scheduled, not attended yet
      // Mutually exclusive primary buckets: late wins over early leave.
      if (r.lateMinutes > 0) {
        late++;
      } else if (r.earlyLeaveMinutes > 0) {
        early++;
      } else {
        present++;
      }
      if (r.overtimeMinutes > 0) {
        ot++;
        otMins += r.overtimeMinutes;
      }
      lateMins += r.lateMinutes;
    }
    return AttendanceSummary(
      total: records.length,
      presentCount: present,
      lateCount: late,
      absentCount: absent,
      earlyLeaveCount: early,
      overtimeCount: ot,
      totalOvertimeMinutes: otMins,
      totalLateMinutes: lateMins,
    );
  }
}
