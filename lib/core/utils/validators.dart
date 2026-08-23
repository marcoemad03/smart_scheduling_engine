class Validators {
  static bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  static bool isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-\s]{7,15}$').hasMatch(phone);
  }

  static bool isNotEmpty(String value) {
    return value.trim().isNotEmpty;
  }

  static bool isValidMinuteOfDay(int minute) {
    return minute >= 0 && minute < 1440;
  }

  static bool isValidDuration(int minutes) {
    return minutes > 0 && minutes <= 1440;
  }

  static List<String> validateAssignment({
    required String employeeId,
    required String areaId,
    required DateTime start,
    required DateTime end,
    required int maxHoursPerDay,
  }) {
    final errors = <String>[];

    if (employeeId.isEmpty) errors.add('Employee ID required');
    if (areaId.isEmpty) errors.add('Area ID required');
    if (start.isAfter(end)) errors.add('Start time must be before end time');

    final duration = end.difference(start).inHours;
    if (duration > maxHoursPerDay) {
      errors.add('Shift exceeds maximum daily hours');
    }

    return errors;
  }
}