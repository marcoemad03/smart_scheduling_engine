import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/employee_schedule_providers.dart';

/// Read-only weekly view of the employee's OWN published schedule.
/// Employees cannot modify anything here.
class EmployeeWeeklySchedulePage extends ConsumerStatefulWidget {
  const EmployeeWeeklySchedulePage({Key? key}) : super(key: key);

  @override
  ConsumerState<EmployeeWeeklySchedulePage> createState() =>
      _EmployeeWeeklySchedulePageState();
}

class _EmployeeWeeklySchedulePageState
    extends ConsumerState<EmployeeWeeklySchedulePage> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = DateTimeUtils.getStartOfWeek(DateTime.now());
  }

  void _changeWeek(int dir) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * dir)));
  }

  @override
  Widget build(BuildContext context) {
    final employeeId = ref.watch(currentEmployeeIdProvider);
    final weekAsync = ref.watch(myWeekProvider(_weekStart));

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d, yyyy').format(_weekStart.add(const Duration(days: 6)))}'),
        actions: [
          IconButton(
              icon: const Icon(Icons.chevron_left), onPressed: () => _changeWeek(-1)),
          IconButton(
              icon: const Icon(Icons.chevron_right), onPressed: () => _changeWeek(1)),
        ],
      ),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (week) {
          final shifts = week
              .myAssignments(employeeId)
              .where((a) =>
                  !a.startDateTime
                      .isBefore(_weekStart.subtract(const Duration(days: 1))) &&
                  a.startDateTime.isBefore(
                      _weekStart.add(const Duration(days: 7))))
              .toList()
            ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

          if (week.publishedSchedule == null) {
            return const Center(
                child: Text('No published schedule for this week yet.'));
          }
          if (shifts.isEmpty) {
            return const Center(child: Text('No shifts assigned this week.'));
          }

          final isDesktop = MediaQuery.of(context).size.width > 768;
          return isDesktop ? _table(shifts, week.areaNames) : _list(shifts, week.areaNames);
        },
      ),
    );
  }

  String _durationLabel(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Widget _shiftRows(List shifts, Map<String, String> areaNames,
      {required bool asTable}) {
    if (asTable) {
      return DataTable(columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Start')),
        DataColumn(label: Text('End')),
        DataColumn(label: Text('Area')),
        DataColumn(label: Text('Shift')),
        DataColumn(label: Text('Duration')),
        DataColumn(label: Text('Status')),
      ], rows: shifts.map<DataRow>((a) {
        return DataRow(cells: [
          DataCell(Text(DateFormat('EEE, MMM d').format(a.scheduledDate))),
          DataCell(Text(DateTimeUtils.formatTime(a.startDateTime))),
          DataCell(Text(DateTimeUtils.formatTime(a.endDateTime))),
          DataCell(Text(areaNames[a.areaId] ?? a.areaId)),
          DataCell(Text(_shiftName(a))),
          DataCell(Text(_durationLabel(a.duration))),
          DataCell(_statusChip(a.status.name)),
        ]);
      }).toList());
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: shifts.length,
      itemBuilder: (context, i) {
        final a = shifts[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(DateFormat('EEE').format(a.scheduledDate),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('d').format(a.scheduledDate)),
              ],
            ),
            title: Text(
                '${DateTimeUtils.formatTime(a.startDateTime)} → ${DateTimeUtils.formatTime(a.endDateTime)}'),
            subtitle:
                Text('${areaNames[a.areaId] ?? a.areaId} • ${_shiftName(a)} • ${_durationLabel(a.duration)}'),
            trailing: _statusChip(a.status.name),
          ),
        );
      },
    );
  }

  Widget _table(List shifts, Map<String, String> areaNames) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _shiftRows(shifts, areaNames, asTable: true),
    );
  }

  Widget _list(List shifts, Map<String, String> areaNames) =>
      _shiftRows(shifts, areaNames, asTable: false);

  String _shiftName(dynamic a) {
    if (a.isOvernight) return 'Night shift';
    if (a.shiftTemplateId != null && a.shiftTemplateId.isNotEmpty) {
      return a.shiftTemplateId;
    }
    final startMin = a.startDateTime.hour * 60 + a.startDateTime.minute;
    if (startMin < 720) return 'Morning shift';
    if (startMin < 1080) return 'Evening shift';
    return 'Late shift';
  }

  Widget _statusChip(String status) {
    final color = status == 'published'
        ? Colors.green
        : status == 'overridden'
            ? Colors.orange
            : Colors.grey;
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(status,
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
