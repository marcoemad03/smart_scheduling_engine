class AvailabilityBlock {
  final String availabilityId;
  final String employeeId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final bool isAvailable;
  final bool isRecurring;
  final List<int> recurrenceDays;
  final DateTime createdAt;

  AvailabilityBlock({
    required this.availabilityId,
    required this.employeeId,
    required this.startDateTime,
    required this.endDateTime,
    required this.isAvailable,
    required this.isRecurring,
    required this.recurrenceDays,
    required this.createdAt,
  });
}

