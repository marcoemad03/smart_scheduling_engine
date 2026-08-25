import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';

/// Structured scheduling commands produced by the AI interpreter.
/// The AI never touches Firestore directly - it only emits these commands,
/// which are executed by the scheduling engine and validated afterwards.
sealed class SchedulingCommand {
  const SchedulingCommand();
  String get description;
}

/// "Make Ahmed off on Tuesday."
class SetDayOffCommand extends SchedulingCommand {
  final String employeeId;
  final String employeeName;
  final DateTime date;
  const SetDayOffCommand({
    required this.employeeId,
    required this.employeeName,
    required this.date,
  });

  @override
  String get description =>
      'Remove all assignments for $employeeName on ${_d(date)}';
}

/// "Move Mohamed from Window to Clinics on Wednesday."
class MoveAssignmentAreaCommand extends SchedulingCommand {
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final String newAreaId;
  final String newAreaName;
  final String? fromAreaId;

  const MoveAssignmentAreaCommand({
    required this.employeeId,
    required this.employeeName,
    required this.date,
    required this.newAreaId,
    required this.newAreaName,
    this.fromAreaId,
  });

  @override
  String get description =>
      '$employeeName on ${_d(date)}: move to $newAreaName'
      '${fromAreaId != null ? " (from $fromAreaId)" : ""}';
}

/// "I need two additional employees from 8 AM to 3 PM on Friday."
class AddCoverageCommand extends SchedulingCommand {
  final DateTime date;
  final int startMinute;
  final int endMinute;
  final String areaId;
  final String areaName;
  final int count;

  const AddCoverageCommand({
    required this.date,
    required this.startMinute,
    required this.endMinute,
    required this.areaId,
    required this.areaName,
    required this.count,
  });

  @override
  String get description =>
      'Add $count employee(s) in $areaName on ${_d(date)} '
      '${_t(startMinute)}→${_t(endMinute)}';
}

/// "Do not assign Mina to night shifts this week."
class RestrictNightShiftsCommand extends SchedulingCommand {
  final String employeeId;
  final String employeeName;

  const RestrictNightShiftsCommand({
    required this.employeeId,
    required this.employeeName,
  });

  @override
  String get description =>
      'Remove night-shift assignments for $employeeName this week';
}

/// "Generate the best schedule for next week."
class GenerateBestScheduleCommand extends SchedulingCommand {
  final DateTime weekStart;

  const GenerateBestScheduleCommand({required this.weekStart});

  @override
  String get description => 'Regenerate the optimal schedule for this week';
}

String _d(DateTime d) =>
    '${_weekday(d.weekday)} ${d.day}/${d.month}';
String _weekday(int w) =>
    ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
String _t(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';

class InterpreterResult {
  final List<SchedulingCommand> commands;
  final List<String> notes;

  const InterpreterResult({required this.commands, required this.notes});
}

/// Pluggable interpreter contract. A future LLM-backed adapter can implement
/// this and return the SAME structured commands; nothing else changes.
abstract class CommandInterpreter {
  InterpreterResult interpret({
    required String request,
    required List<Employee> employees,
    required List<ReceptionArea> areas,
    required DateTime weekStart,
  });
}

/// Offline deterministic NLP using keyword/regex rules over known entities.
class RuleBasedCommandInterpreter implements CommandInterpreter {
  const RuleBasedCommandInterpreter();

  static const _weekdays = {
    'monday': 1, 'mon': 1,
    'tuesday': 2, 'tue': 2, 'tues': 2,
    'wednesday': 3, 'wed': 3,
    'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4,
    'friday': 5, 'fri': 5,
    'saturday': 6, 'sat': 6,
    'sunday': 7, 'sun': 7,
  };

  static const _numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
  };

  @override
  InterpreterResult interpret({
    required String request,
    required List<Employee> employees,
    required List<ReceptionArea> areas,
    required DateTime weekStart,
  }) {
    final text = request.toLowerCase();
    final notes = <String>[];
    final commands = <SchedulingCommand>[];

    // ---- Generate ----
    if (text.contains('generate') || text.contains('best schedule')) {
      commands.add(GenerateBestScheduleCommand(
          weekStart: _startOfDay(weekStart)));
      return InterpreterResult(commands: commands, notes: notes);
    }

    // ---- No night shifts for employee ----
    if (_hasNight(text) &&
        (text.contains('not') || text.contains("don't") || text.contains('do not') || text.contains('never'))) {
      final emp = _findEmployee(text, employees);
      if (emp != null) {
        commands.add(RestrictNightShiftsCommand(
            employeeId: emp.id, employeeName: emp.fullName));
        return InterpreterResult(commands: commands, notes: notes);
      }
      notes.add('Could not find that employee.');
    }

    // ---- Day off ----
    if ((text.contains(' off ') ||
            text.startsWith('make ') ||
            text.contains('day off') ||
            text.contains('leave')) &&
        !text.contains('move')) {
      final emp = _findEmployee(text, employees);
      final dayOffset = _findDay(text);
      if (emp != null && dayOffset != null) {
        commands.add(SetDayOffCommand(
          employeeId: emp.id,
          employeeName: emp.fullName,
          date: _startOfDay(weekStart.add(Duration(days: dayOffset))),
        ));
        return InterpreterResult(commands: commands, notes: notes);
      }
      if (emp == null) notes.add('Could not find that employee.');
      if (dayOffset == null) notes.add('Could not understand the day.');
    }

    // ---- Move to area ----
    if (text.contains('move') || text.contains('transfer')) {
      final emp = _findEmployee(text, employees);
      final dayOffset = _findDay(text);
      String? newAreaId;
      String? newAreaName;
      String? fromAreaId;
      final toMatch =
          RegExp(r'to\s+(?:the\s+)?([a-z ]+?)(?:\s+on\b|\s+this\b|$)')
              .firstMatch(text);
      if (toMatch != null) {
        final area = _findArea(toMatch.group(1)!.trim(), areas);
        if (area != null) {
          newAreaId = area.areaId;
          newAreaName = area.name;
        }
      }
      final fromMatch =
          RegExp(r'from\s+(?:the\s+)?([a-z ]+?)\s+to\b').firstMatch(text);
      if (fromMatch != null) {
        final area = _findArea(fromMatch.group(1)!.trim(), areas);
        if (area != null) fromAreaId = area.areaId;
      }
      if (emp != null && newAreaId != null && dayOffset != null) {
        commands.add(MoveAssignmentAreaCommand(
          employeeId: emp.id,
          employeeName: emp.fullName,
          date: _startOfDay(weekStart.add(Duration(days: dayOffset))),
          newAreaId: newAreaId,
          newAreaName: newAreaName!,
          fromAreaId: fromAreaId,
        ));
        return InterpreterResult(commands: commands, notes: notes);
      }
      notes.add('Could not fully understand the move request.');
    }

    // ---- Additional employees / coverage ----
    if (text.contains('additional') ||
        text.contains('extra') ||
        (text.contains('need') && text.contains('from'))) {
      final count = _findCount(text);
      final window = _findTimeWindow(text);
      final dayOffset = _findDay(text);
      final area = _findArea(text, areas) ??
          (areas.isNotEmpty ? areas.first : null);
      if (window != null && dayOffset != null && area != null) {
        commands.add(AddCoverageCommand(
          date: _startOfDay(weekStart.add(Duration(days: dayOffset))),
          startMinute: window.$1,
          endMinute: window.$2,
          areaId: area.areaId,
          areaName: area.name,
          count: count,
        ));
        return InterpreterResult(commands: commands, notes: notes);
      }
      notes.add('Could not understand the coverage request '
          '(need day and time range).');
    }

    if (commands.isEmpty && notes.isEmpty) {
      notes.add(
          'Sorry, I could not interpret that. Try e.g. "Make Ahmed off on '
          'Tuesday", "Move Mohamed to Clinics on Wednesday", "I need two '
          'additional employees from 8 AM to 3 PM on Friday", "Do not assign '
          'Mina to night shifts this week", or "Generate the best schedule".');
    }
    return InterpreterResult(commands: commands, notes: notes);
  }

  Employee? _findEmployee(String text, List<Employee> employees) {
    for (final e in employees) {
      final first = e.firstName.toLowerCase();
      final last = e.lastName.toLowerCase();
      if (first.length >= 3 && text.contains(first)) return e;
      if (last.length >= 3 && text.contains(last)) return e;
    }
    return null;
  }

  ReceptionArea? _findArea(String text, List<ReceptionArea> areas) {
    for (final a in areas) {
      if (a.name.toLowerCase().length >= 3 &&
          text.contains(a.name.toLowerCase())) {
        return a;
      }
    }
    return null;
  }

  int? _findDay(String text) {
    for (final entry in _weekdays.entries) {
      if (text.contains(entry.key)) return entry.value - 1; // 0-based offset
    }
    return null;
  }

  int _findCount(String text) {
    final digit = RegExp(r'(\d+)\s*(?:additional|extra|more|employees|people)')
        .firstMatch(text);
    if (digit != null) return int.tryParse(digit.group(1)!) ?? 1;
    for (final entry in _numberWords.entries) {
      if (text.contains('${entry.key} additional') ||
          text.contains('${entry.key} extra') ||
          text.contains('need ${entry.key}')) {
        return entry.value;
      }
    }
    return 1;
  }

  (int, int)? _findTimeWindow(String text) {
    final match = RegExp(
            r'from\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*to\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?')
        .firstMatch(text);
    if (match == null) return null;
    final start = _toMinutes(match.group(1)!, match.group(2), match.group(3));
    var end = _toMinutes(match.group(4)!, match.group(5), match.group(6));
    if (end <= start) end += 1440; // crosses midnight
    return (start, end);
  }

  int _toMinutes(String hourStr, String? minStr, String? ampm) {
    var hour = int.parse(hourStr) % 24;
    final minute = int.tryParse(minStr ?? '') ?? 0;
    if (ampm != null) {
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
    }
    return hour * 60 + minute;
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
}
