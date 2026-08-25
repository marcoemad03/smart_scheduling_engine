import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'schedule_assignment_model.dart';

class WeeklyScheduleModel {
  final String scheduleId;
  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final int version;
  final ScheduleStatus status;
  final String createdBy;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final List<ScheduleAssignmentModel> assignments;

  WeeklyScheduleModel({
    required this.scheduleId,
    required this.weekStartDate,
    required this.weekEndDate,
    required this.version,
    required this.status,
    required this.createdBy,
    this.publishedAt,
    DateTime? createdAt,
    required this.assignments,
  }) : createdAt = createdAt ?? DateTime.now();

  factory WeeklyScheduleModel.fromJson(Map<String, dynamic> json) {
    return WeeklyScheduleModel(
      scheduleId: json['scheduleId'] as String,
      weekStartDate: (json['weekStartDate'] as Timestamp).toDate(),
      weekEndDate: (json['weekEndDate'] as Timestamp).toDate(),
      version: json['version'] as int? ?? 1,
      status: ScheduleStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'draft'),
        orElse: () => ScheduleStatus.draft,
      ),
      createdBy: json['createdBy'] as String? ?? '',
      publishedAt: json['publishedAt'] != null
          ? (json['publishedAt'] as Timestamp).toDate()
          : null,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignments: (json['assignments'] as List?)
              ?.map((a) =>
                  ScheduleAssignmentModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduleId': scheduleId,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'weekEndDate': Timestamp.fromDate(weekEndDate),
      'version': version,
      'status': status.name,
      'createdBy': createdBy,
      'publishedAt':
          publishedAt != null ? Timestamp.fromDate(publishedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'assignments': assignments.map((a) => a.toJson()).toList(),
    };
  }

  WeeklySchedule toDomain() {
    return WeeklySchedule(
      id: scheduleId,
      weekStartDate: weekStartDate,
      weekEndDate: weekEndDate,
      version: version,
      status: status,
      createdBy: createdBy,
      publishedAt: publishedAt,
      createdAt: createdAt,
      assignments: assignments.map((a) => a.toDomain()).toList(),
    );
  }

  factory WeeklyScheduleModel.fromDomain(WeeklySchedule schedule) {
    return WeeklyScheduleModel(
      scheduleId: schedule.id,
      weekStartDate: schedule.weekStartDate,
      weekEndDate: schedule.weekEndDate,
      version: schedule.version,
      status: schedule.status,
      createdBy: schedule.createdBy,
      publishedAt: schedule.publishedAt,
      createdAt: schedule.createdAt,
      assignments: schedule.assignments
          .map((a) => ScheduleAssignmentModel.fromDomain(a))
          .toList(),
    );
  }
}
