import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/employee_shift_status.dart';

class TodayShiftCard extends StatelessWidget {
  final EmployeeShiftStatus status;
  final String? areaName;

  const TodayShiftCard({Key? key, required this.status, this.areaName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final shift = status.currentShift;
    final now = DateTime.now();
    final accent = status.isWorking ? Colors.green : Colors.blueGrey;

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.today, color: accent),
              const SizedBox(width: 8),
              const Text('Today',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Chip(
                backgroundColor:
                    accent.withOpacity(0.12),
                label: Text(status.todayLabel,
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            if (shift != null) ...[
              _row('Current area', areaName ?? shift.areaId),
              _row('Start time', DateTimeUtils.formatTime(shift.startDateTime)),
              _row('End time', DateTimeUtils.formatTime(shift.endDateTime)),
              if (status.isWorking) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.timer, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'Time remaining: ${_remaining(shift.endDateTime.difference(now))}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ]),
              ],
            ] else
              Text(
                status.nextShift == null
                    ? 'No published shift right now.'
                    : 'Not working at this moment.',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  String _remaining(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class NextShiftCard extends StatelessWidget {
  final ScheduleAssignment? next;
  final Map<String, String> areaNames;

  const NextShiftCard({Key? key, required this.next, required this.areaNames})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (next == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.event_note_outlined),
          title: Text('No upcoming published shifts'),
          subtitle:
              Text('Your schedule will appear here once admin publishes it.'),
        ),
      );
    }
    final n = next!;
    final dayLabel = DateFormat('EEE, MMM d').format(n.scheduledDate);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.upcoming_outlined, size: 32),
        title: Text(
            'Next: $dayLabel • ${DateTimeUtils.formatTime(n.startDateTime)} → ${DateTimeUtils.formatTime(n.endDateTime)}'),
        subtitle: Text(areaNames[n.areaId] ?? n.areaId),
      ),
    );
  }
}

/// Ticker widget that rebuilds its child every second (for live countdowns).
class SecondTicker extends StatefulWidget {
  final WidgetBuilder builder;
  const SecondTicker({Key? key, required this.builder}) : super(key: key);

  @override
  State<SecondTicker> createState() => _SecondTickerState();
}

class _SecondTickerState extends State<SecondTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
