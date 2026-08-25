class DateTimeUtils {
  // Calculate week boundaries (Monday to Sunday)
  static DateTime getStartOfWeek(DateTime date) {
    final diff = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - diff);
  }

  static DateTime getEndOfWeek(DateTime date) {
    final diff = 7 - date.weekday;
    return DateTime(date.year, date.month, date.day + diff, 23, 59, 59);
  }

  // Check if datetime is between two dates
  static bool isBetween(DateTime date, DateTime start, DateTime end) {
    return date.isAtSameMomentAs(start) ||
        date.isAfter(start) && date.isBefore(end);
  }

  // Format time without date
  static String formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Generate unique ID
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Days in a week as integers (Mon=1, Sun=7)
  static List<int> daysOfWeek() => [1, 2, 3, 4, 5, 6, 7];

  // Day names localized
  static List<String> dayNames() => ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  // Get day name
  static String getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  // Minutes in a day
  static int minutesInDay = 1440;

  // Convert hour/minute to minutes from midnight
  static int toMinutes(int hour, int minute) => hour * 60 + minute;

  // Convert minutes to hour/minute
  static Map<String, int> fromMinutes(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return {'hours': hours, 'minutes': mins};
  }
}

