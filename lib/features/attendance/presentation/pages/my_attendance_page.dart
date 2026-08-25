import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/attendance/data/attendance_repository.dart';
import 'package:reception_workforce_scheduler/features/attendance/domain/entities/attendance_record.dart';

class MyAttendancePage extends ConsumerStatefulWidget {
  const MyAttendancePage({Key? key}) : super(key: key);

  @override
  ConsumerState<MyAttendancePage> createState() => _MyAttendancePageState();
}

class _MyAttendancePageState extends ConsumerState<MyAttendancePage> {
  late DateTime _weekStart;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _weekStart = DateTimeUtils.getStartOfWeek(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _watch());
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _watch() {
    ref.read(myAttendanceProvider.notifier).watch(
          employeeId: FirebaseAuth.instance.currentUser?.uid ?? '',
          from: _weekStart.subtract(const Duration(days: 1)),
          to: _weekStart.add(const Duration(days: 8)),
        );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _changeWeek(int dir) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * dir)));
    _watch();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myAttendanceProvider);
    final vm = ref.read(myAttendanceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'My Attendance • ${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d').format(_weekStart.add(const Duration(days: 6)))}'),
        actions: [
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
          final now = DateTime.now();
          final active = records.firstOrNullWhere((r) =>
              r.actualCheckIn != null &&
              r.actualCheckOut == null &&
              !r.scheduledEnd.isBefore(now));

          return Column(children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: _SummaryRow(summary: summary),
            ),
            if (active != null)
              Card(
                color: Colors.green.withOpacity(0.08),
                margin:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.timer, color: Colors.green),
                  title: Text(
                      'Working since ${DateFormat('HH:mm').format(active.actualCheckIn!)}'
                      '${active.lateMinutes > 0 ? ' (${active.lateMinutes}m late)' : ''}'),
                  subtitle: Text(
                      'Planned end ${DateFormat('HH:mm').format(active.scheduledEnd)}'),
                  trailing: FilledButton(
                    onPressed: () => vm.checkOut(active, DateTime.now()),
                    child: const Text('Check Out'),
                  ),
                ),
              ),
            Expanded(
              child: records.isEmpty
                  ? const Center(
                      child: Text(
                          'No attendance records.\nRecords are generated automatically from published schedules.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: records.length,
                      itemBuilder: (context, i) =>
                          _recordCard(context, records[i], vm),
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _recordCard(
      BuildContext context, AttendanceRecord r, AttendanceViewModel vm) {
    final now = DateTime.now();
    final canCheckIn = r.actualCheckIn == null &&
        r.status != AttendanceStatus.absent &&
        !now.isBefore(r.scheduledStart.subtract(const Duration(hours: 1))) &&
        now.isBefore(r.scheduledEnd);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(DateFormat('EEE, MMM d').format(r.scheduledStart),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            _statusChip(r.status),
            if (r.lateMinutes > 0) ...[
              const SizedBox(width: 4),
              Chip(label: Text('Late ${r.lateMinutes}m')),
            ],
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _plannedActual('Planned',
                '${DateFormat('HH:mm').format(r.scheduledStart)} → ${DateFormat('HH:mm').format(r.scheduledEnd)}'),
            const SizedBox(width: 24),
            _plannedActual(
                'Actual',
                r.actualCheckIn == null
                    ? '--:-- → --:--'
                    : '${DateFormat('HH:mm').format(r.actualCheckIn!)} → ${r.actualCheckOut != null ? DateFormat('HH:mm').format(r.actualCheckOut!) : '…'}'),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            if (r.earlyLeaveMinutes > 0)
              Chip(label: Text('Early leave ${r.earlyLeaveMinutes}m')),
            if (r.overtimeMinutes > 0)
              Chip(label: Text('Overtime +${r.overtimeMinutes}m')),
            if (canCheckIn)
              FilledButton(
                onPressed: () => vm.checkIn(r, DateTime.now()),
                child: const Text('Check In'),
              ),
          ]),
          if (r.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Note: ${r.notes}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
        ]),
      ),
    );
  }

  Widget _plannedActual(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13)),
        ],
      );

  Widget _statusChip(AttendanceStatus status) {
    final (color, label) = switch (status) {
      AttendanceStatus.present => (Colors.green, 'Present'),
      AttendanceStatus.late => (Colors.orange, 'Late'),
      AttendanceStatus.earlyLeave => (Colors.deepOrange, 'Early Leave'),
      AttendanceStatus.absent => (Colors.red, 'Absent'),
      AttendanceStatus.scheduled => (Colors.grey, 'Scheduled'),
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final AttendanceSummary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, Color c) => Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: c)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            stat('Present', '${summary.presentCount}', Colors.green),
            stat('Late', '${summary.lateCount}', Colors.orange),
            stat('Absent', '${summary.absentCount}', Colors.red),
            stat('Early', '${summary.earlyLeaveCount}', Colors.deepOrange),
            stat('Overtime',
                '${summary.totalOvertimeMinutes > 0 ? "+${(summary.totalOvertimeMinutes / 60).toStringAsFixed(1)}h" : "0"}',
                Colors.purple),
          ],
        ),
      ),
    );
  }
}

extension _FirstWhere<T> on Iterable<T> {
  T? firstOrNullWhere(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
