import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/attendance/data/attendance_repository.dart';
import 'package:reception_workforce_scheduler/features/attendance/domain/entities/attendance_record.dart';

class AdminAttendancePage extends ConsumerStatefulWidget {
  const AdminAttendancePage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminAttendancePage> createState() =>
      _AdminAttendancePageState();
}

class _AdminAttendancePageState extends ConsumerState<AdminAttendancePage> {
  late DateTime _weekStart;
  Map<String, String> employeeNames = {};

  @override
  void initState() {
    super.initState();
    _weekStart = DateTimeUtils.getStartOfWeek(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watch();
      _loadEmployees();
      _syncFromSchedule();
    });
  }

  void _watch() {
    ref.read(adminAttendanceProvider.notifier).watch(
          employeeId: '',
          from: _weekStart.subtract(const Duration(days: 1)),
          to: _weekStart.add(const Duration(days: 8)),
        );
  }

  void _changeWeek(int dir) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * dir)));
    _watch();
    _syncFromSchedule();
  }

  Future<void> _loadEmployees() async {
    final snapshot =
        await ref.read(firebaseFirestoreProvider).collection('employees').get();
    if (!mounted) return;
    setState(() {
      employeeNames = {
        for (final doc in snapshot.docs)
          doc.data()['employeeId'] as String? ?? doc.id:
              '${doc.data()['firstName'] ?? ''} ${doc.data()['lastName'] ?? ''}'.trim(),
      };
    });
  }

  /// Reads the PUBLISHED schedule and creates planned attendance records for
  /// assignments without one. The schedule is never modified.
  Future<void> _syncFromSchedule() async {
    final firestore = ref.read(firebaseFirestoreProvider);
    final from = Timestamp.fromDate(_weekStart);
    final to = Timestamp.fromDate(_weekStart.add(const Duration(days: 7)));
    final schedules = await firestore
        .collection('weeklySchedules')
        .where('status', isEqualTo: 'published')
        .get();

    final assignments = <Map<String, dynamic>>[];
    for (final doc in schedules.docs) {
      final data = doc.data();
      final list = data['assignments'] as List? ?? [];
      for (final a in list.cast<Map<String, dynamic>>()) {
        final start = (a['startDateTime'] as Timestamp).toDate();
        if (start.isBefore(from.toDate()) || !start.isBefore(to.toDate())) {
          continue;
        }
        assignments.add({
          'assignmentId': a['assignmentId'] as String,
          'employeeId': a['employeeId'] as String,
          'startDateTime': start,
          'endDateTime': (a['endDateTime'] as Timestamp).toDate(),
        });
      }
    }
    if (!mounted) return;
    await ref.read(adminAttendanceProvider.notifier).syncFromSchedule(
          publishedAssignments: assignments,
          from: _weekStart.subtract(const Duration(days: 1)),
          to: _weekStart.add(const Duration(days: 8)),
        );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adminAttendanceProvider);
    final vm = ref.read(adminAttendanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Attendance • ${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}'),
        actions: [
          IconButton(
            tooltip: 'Sync from published schedule',
            icon: const Icon(Icons.sync),
            onPressed: _syncFromSchedule,
          ),
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeWeek(-1)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeWeek(1)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (records) {
          final summary = AttendanceSummary.of(records);
          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('Present', '${summary.presentCount}', Colors.green),
                      _stat('Late', '${summary.lateCount}', Colors.orange),
                      _stat('Absent', '${summary.absentCount}', Colors.red),
                      _stat('Early Leave', '${summary.earlyLeaveCount}',
                          Colors.deepOrange),
                      _stat(
                          'Overtime',
                          summary.totalOvertimeMinutes > 0
                              ? '+${(summary.totalOvertimeMinutes / 60).toStringAsFixed(1)}h'
                              : '0',
                          Colors.purple),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? const Center(child: Text('No attendance records this week.'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Employee')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Planned')),
                          DataColumn(label: Text('Actual')),
                          DataColumn(label: Text('Late')),
                          DataColumn(label: Text('Early')),
                          DataColumn(label: Text('Overtime')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: records.map((r) {
                          return DataRow(cells: [
                            DataCell(Text(employeeNames[r.employeeId] ??
                                r.employeeId.substring(0, 8))),
                            DataCell(Text(DateFormat('EEE, MMM d')
                                .format(r.scheduledStart))),
                            DataCell(Text(
                                '${DateFormat('HH:mm').format(r.scheduledStart)} → ${DateFormat('HH:mm').format(r.scheduledEnd)}')),
                            DataCell(Text(r.actualCheckIn == null
                                ? '-'
                                : '${DateFormat('HH:mm').format(r.actualCheckIn!)} → ${r.actualCheckOut != null ? DateFormat('HH:mm').format(r.actualCheckOut!) : '…'}')),
                            DataCell(Text('${r.lateMinutes}m')),
                            DataCell(Text('${r.earlyLeaveMinutes}m')),
                            DataCell(Text('+${r.overtimeMinutes}m')),
                            DataCell(_chip(context, r)),
                            DataCell(Row(children: [
                              if (r.status != AttendanceStatus.absent &&
                                  r.actualCheckIn == null)
                                IconButton(
                                  tooltip: 'Mark absent',
                                  icon: const Icon(Icons.person_off_outlined,
                                      size: 18, color: Colors.red),
                                  onPressed: () =>
                                      vm.markAbsent(r, 'Marked absent by admin'),
                                ),
                              IconButton(
                                tooltip: 'Add note',
                                icon: const Icon(Icons.note_add_outlined,
                                    size: 18),
                                onPressed: () async {
                                  final c = TextEditingController(text: r.notes);
                                  final note = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Add Note'),
                                      content: TextField(
                                          controller: c,
                                          autofocus: true),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx),
                                            child: const Text('Cancel')),
                                        FilledButton(
                                            onPressed: () => Navigator.pop(
                                                ctx, c.text.trim()),
                                            child: const Text('Save')),
                                      ],
                                    ),
                                  );
                                  if (note != null && note.isNotEmpty) {
                                    vm.addNote(r, note);
                                  }
                                },
                              ),
                            ])),
                          ]);
                        }).toList(),
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(children: [
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ]);

  Widget _chip(BuildContext context, AttendanceRecord r) {
    final (color, label) = switch (r.status) {
      AttendanceStatus.present => (Colors.green, 'Present'),
      AttendanceStatus.late => (Colors.orange, 'Late'),
      AttendanceStatus.earlyLeave => (Colors.deepOrange, 'Early'),
      AttendanceStatus.absent => (Colors.red, 'Absent'),
      AttendanceStatus.scheduled => (Colors.grey, 'Scheduled'),
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
