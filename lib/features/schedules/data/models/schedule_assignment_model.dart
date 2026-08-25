import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

class ScheduleAssignmentModel {
  final String assignmentId;
  final String employeeId;
  final String areaId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? shiftTemplateId;
  final DateTime scheduledDate;
  final AssignmentStatus status;
  final String? notes;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleAssignmentModel({
    required this.assignmentId,
    required this.employeeId,
    required this.areaId,
    required this.startDateTime,
    required this.endDateTime,
    this.shiftTemplateId,
    required this.scheduledDate,
    this.status = AssignmentStatus.draft,
    this.notes,
    required this.createdBy,
    required this.updatedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ScheduleAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ScheduleAssignmentModel(
      assignmentId: json['assignmentId'] as String,
      employeeId: json['employeeId'] as String,
      areaId: json['areaId'] as String,
      startDateTime: (json['startDateTime'] as Timestamp).toDate(),
      endDateTime: (json['endDateTime'] as Timestamp).toDate(),
      shiftTemplateId: json['shiftTemplateId'] as String?,
      scheduledDate: (json['scheduledDate'] as Timestamp).toDate(),
      status: AssignmentStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'draft'),
        orElse: () => AssignmentStatus.draft,
      ),
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignmentId': assignmentId,
      'employeeId': employeeId,
      'areaId': areaId,
      'startDateTime': Timestamp.fromDate(startDateTime),
      'endDateTime': Timestamp.fromDate(endDateTime),
      'shiftTemplateId': shiftTemplateId,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'notes': notes,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ScheduleAssignment toDomain() {
    return ScheduleAssignment(
      id: assignmentId,
      employeeId: employeeId,
      areaId: areaId,
      startDateTime: startDateTime,
      endDateTime: endDateTime,
      shiftTemplateId: shiftTemplateId,
      scheduledDate: scheduledDate,
      status: status,
      notes: notes,
      createdBy: createdBy,
      updatedBy: updatedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ScheduleAssignmentModel.fromDomain(ScheduleAssignment assignment) {
    return ScheduleAssignmentModel(
      assignmentId: assignment.id,
      employeeId: assignment.employeeId,
      areaId: assignment.areaId,
      startDateTime: assignment.startDateTime,
      endDateTime: assignment.endDateTime,
      shiftTemplateId: assignment.shiftTemplateId,
      scheduledDate: assignment.scheduledDate,
      status: assignment.status,
      notes: assignment.notes,
      createdBy: assignment.createdBy,
      updatedBy: assignment.updatedBy,
      createdAt: assignment.createdAt,
      updatedAt: assignment.updatedAt,
    );
  }
}
