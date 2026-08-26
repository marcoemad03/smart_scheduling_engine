import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/employee_shift_status.dart';

/// Maps the domain-layer English status labels to localized strings.
String _localizedTodayLabel(BuildContext context, String label) {
  final l10n = AppLocalizations.of(context)!;
  switch (label) {
    case 'Working now':
      return l10n.workingNow;
    case 'Not started yet':
      return l10n.notStartedYet;
    case 'Finished for today':
      return l10n.finishedForToday;
    case 'Day off':
      return l10n.dayOff;
    case 'No upcoming shifts':
      return l10n.noUpcomingShifts;
    default:
      return label;
  }
}

class TodayShiftCard extends StatelessWidget {
  final EmployeeShiftStatus status;
  final String? areaName;

  const TodayShiftCard({Key? key, required this.status, this.areaName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(l10n.today,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Chip(
                backgroundColor:
                    accent.withOpacity(0.12),
                label: Text(_localizedTodayLabel(context, status.todayLabel),
                    style: TextStyle(
                        color: accent, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 12),
            if (shift != null) ...[
              _row(l10n.currentArea, areaName ?? shift.areaId),
              _row(l10n.startTime, DateTimeUtils.formatTime(shift.startDateTime)),
              _row(l10n.endTime, DateTimeUtils.formatTime(shift.endDateTime)),
              if (status.isWorking) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.timer, size: 18, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.timeRemaining(
                          _remaining(shift.endDateTime.difference(now))),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ),
                ]),
              ],
            ] else
              Text(
                status.nextShift == null
                    ? l10n.noPublishedShiftNow
                    : l10n.notWorkingNow,
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
      final l10n = AppLocalizations.of(context)!;
      return Card(
        child: ListTile(
          leading: const Icon(Icons.event_note_outlined),
          title: Text(l10n.noUpcomingPublishedShifts),
          subtitle: Text(l10n.scheduleWillAppear),
        ),
      );
    }
    final n = next!;
    final dayLabel = DateFormat('EEE, MMM d').format(n.scheduledDate);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.upcoming_outlined, size: 32),
        title: Text(AppLocalizations.of(context)!.nextShiftLabel(
            dayLabel,
            '${DateTimeUtils.formatTime(n.startDateTime)} → ${DateTimeUtils.formatTime(n.endDateTime)}')),
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
