import 'package:flutter/material.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';

class ShiftDisplayHelper {
  static String formatShiftTime(ScheduleAssignment assignment) {
    final startTime = _formatTime(assignment.startDateTime);
    final endTime = _formatTime(assignment.endDateTime);

    if (assignment.isOvernight) {
      return "$startTime → $endTime+";
    }

    return "$startTime → $endTime";
  }

  static String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  static Color getShiftColor(BuildContext context, ScheduleAssignment assignment) {
    if (assignment.isOvernight) {
      return Theme.of(context).colorScheme.tertiary;
    }
    return Theme.of(context).colorScheme.primary;
  }

  static IconData getShiftIcon(ScheduleAssignment assignment) {
    if (assignment.isOvernight) {
      return Icons.nightlight_round;
    }
    return Icons.wb_sunny_outlined;
  }

  static String getShiftDurationDisplay(ScheduleAssignment assignment) {
    final duration = assignment.duration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }
}
