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
  final DateTime createdAt;

  ScheduleAssignmentModel({
    required this.assignmentId,
    required this.employeeId,
    required this.areaId,
    required this.startDateTime,
    required this.endDateTime,
    this.shiftTemplateId,
    required this.scheduledDate,
    required this.createdAt,
  });

  factory ScheduleAssignmentModel.fromJson(Map<String, dynamic> json) {
    return ScheduleAssignmentModel(
      assignmentId: json['assignmentId'] as String,
      employeeId: json['employeeId'] as String,
      areaId: json['areaId'] as String,
      startDateTime: (json['startDateTime'] as Timestamp).toDate(),
      endDateTime: (json['endDateTime'] as Timestamp).toDate(),
      shiftTemplateId: json['shiftTemplateId'] as String?,
      scheduledDate: (json['scheduledDate'] as Timestamp).toDate(),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
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
      'createdAt': Timestamp.fromDate(createdAt),
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
    );
  }
}