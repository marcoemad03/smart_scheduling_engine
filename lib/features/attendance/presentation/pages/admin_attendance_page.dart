import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/core/utils/directional_icons.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${l10n.attendanceTitle} • ${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}'),
        actions: [
          IconButton(
            tooltip: l10n.syncFromSchedule,
            icon: const Icon(Icons.sync),
            onPressed: _syncFromSchedule,
          ),
          IconButton(
              icon: Icon(DirectionalIcons.chevronBackward(context)),
              onPressed: () => _changeWeek(-1)),
          IconButton(
              icon: Icon(DirectionalIcons.chevronForward(context)),
              onPressed: () => _changeWeek(1)),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
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
                      _stat(l10n.statusPresent, '${summary.presentCount}', Colors.green),
                      _stat(l10n.statusLate, '${summary.lateCount}', Colors.orange),
                      _stat(l10n.statusAbsent, '${summary.absentCount}', Colors.red),
                      _stat(l10n.statusEarlyLeave, '${summary.earlyLeaveCount}',
                          Colors.deepOrange),
                      _stat(
                          l10n.colOvertime,
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
                  ? Center(child: Text(l10n.noRecordsWeek))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        columns: [
                          DataColumn(label: Text(l10n.employee)),
                          DataColumn(label: Text(l10n.colDate)),
                          DataColumn(label: Text(l10n.colPlanned)),
                          DataColumn(label: Text(l10n.colActual)),
                          DataColumn(label: Text(l10n.statusLate)),
                          DataColumn(label: Text(l10n.colEarly)),
                          DataColumn(label: Text(l10n.colOvertime)),
                          DataColumn(label: Text(l10n.colStatus)),
                          DataColumn(label: Text(l10n.colActions)),
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
                                  tooltip: l10n.markAbsent,
                                  icon: const Icon(Icons.person_off_outlined,
                                      size: 18, color: Colors.red),
                                  onPressed: () =>
                                      vm.markAbsent(r, l10n.markedAbsentNote),
                                ),
                              IconButton(
                                tooltip: l10n.addNote,
                                icon: const Icon(Icons.note_add_outlined,
                                    size: 18),
                                onPressed: () async {
                                  final c = TextEditingController(text: r.notes);
                                  final note = await showDialog<String>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text(l10n.addNote),
                                      content: TextField(
                                          controller: c,
                                          autofocus: true),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx),
                                            child: Text(l10n.cancel)),
                                        FilledButton(
                                            onPressed: () => Navigator.pop(
                                                ctx, c.text.trim()),
                                            child: Text(l10n.save)),
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
    final l10n = AppLocalizations.of(context)!;
    final (color, label) = switch (r.status) {
      AttendanceStatus.present => (Colors.green, l10n.statusPresent),
      AttendanceStatus.late => (Colors.orange, l10n.statusLate),
      AttendanceStatus.earlyLeave => (Colors.deepOrange, l10n.summaryEarly),
      AttendanceStatus.absent => (Colors.red, l10n.statusAbsent),
      AttendanceStatus.scheduled => (Colors.grey, l10n.statusScheduled),
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
