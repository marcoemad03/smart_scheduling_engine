class TimezoneService {
  static String getDefaultTimezone() => 'UTC';
  static String getCurrentTimezone() => DateTime.now().timeZoneName;
}
