import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/employees/data/employees_repository.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

/// Admin screen showing one employee's profile, work permissions and
/// schedule statistics.
class EmployeeDetailsPage extends ConsumerStatefulWidget {
  final String employeeId;
  const EmployeeDetailsPage({Key? key, required this.employeeId})
      : super(key: key);

  @override
  ConsumerState<EmployeeDetailsPage> createState() =>
      _EmployeeDetailsPageState();
}

class _EmployeeDetailsPageState extends ConsumerState<EmployeeDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesViewModelProvider);
    final areasAsync = ref.watch(areaListViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeeDetailsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/employees'),
        ),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
        data: (employees) {
          Employee? employee;
          for (final e in employees) {
            if (e.id == widget.employeeId) {
              employee = e;
              break;
            }
          }
          if (employee == null) {
            return Center(child: Text(l10n.noEmployeesFound));
          }
          final areas = areasAsync.asData?.value ?? const [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _profileCard(employee),
              const SizedBox(height: 16),
              _permissionsCard(employee, areas),
              const SizedBox(height: 16),
              _statsCard(employee),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(Employee e) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 28,
              child: Text(e.firstName.isNotEmpty
                  ? e.firstName.substring(0, 1).toUpperCase()
                  : '?'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.fullName,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text('${l10n.colCode}: ${e.employeeCode.isEmpty ? l10n.notSet : e.employeeCode}',
                        style: const TextStyle(color: Colors.grey)),
                  ]),
            ),
            _Chip(
                label: e.isActive ? l10n.active : l10n.inactive,
                color: e.isActive ? Colors.green : Colors.grey),
          ]),
          const Divider(height: 24),
          _row(l10n.email, e.email),
          _row(l10n.phone, e.phone.isEmpty ? l10n.notSet : e.phone),
          _row(l10n.hireDate, DateFormat('MMM d, yyyy').format(e.hireDate)),
          _row(l10n.maxWeeklyHours, '${e.maxWeeklyHours.toStringAsFixed(0)}h'),
          _row(l10n.accountStatusLabel,
              e.hasAccount ? l10n.accountLinked : l10n.accountNotLinked),
          if (e.notes.isNotEmpty) _row(l10n.notes, e.notes),
        ]),
      ),
    );
  }

  Widget _permissionsCard(Employee e, List<ReceptionArea> areas) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.sectionPermissions,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(l10n.permissionsNote,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),
          if (areas.isEmpty)
            Text(l10n.noAreasYet, style: const TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: areas.map((a) {
                final isAllowed = e.isAllowedInArea(a.areaId);
                return Chip(
                  avatar: Icon(
                    isAllowed ? Icons.check_circle : Icons.block,
                    size: 16,
                    color: isAllowed ? Colors.green : Colors.red,
                  ),
                  label: Text(
                      '${a.name} • ${isAllowed ? l10n.allowedLabel : l10n.notAllowedLabel}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isAllowed ? Colors.green : Colors.red)),
                  backgroundColor: (isAllowed ? Colors.green : Colors.red)
                      .withOpacity(0.08),
                );
              }).toList(),
            ),
        ]),
      ),
    );
  }

  Widget _statsCard(Employee e) {
    final l10n = AppLocalizations.of(context)!;
    final statsAsync = ref.watch(employeeScheduleStatsProvider(e.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.sectionStats,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          statsAsync.when(
            loading: () => const Center(
                child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )),
            error: (err, _) => Text(l10n.errorPrefix('$err'),
                style: const TextStyle(color: Colors.red)),
            data: (stats) => Column(children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _stat(l10n.hoursThisWeek,
                      '${stats.hoursThisWeek.toStringAsFixed(1)}h', Colors.blue),
                  _stat(l10n.hoursThisMonth,
                      '${stats.hoursThisMonth.toStringAsFixed(1)}h', Colors.indigo),
                  _stat(l10n.totalShifts, '${stats.totalShifts}', Colors.purple),
                  _stat(l10n.nightShiftsCount, '${stats.nightShifts}',
                      Colors.deepPurple),
                  _stat(l10n.weekendShiftsCount, '${stats.weekendShifts}',
                      Colors.teal),
                  _stat(l10n.colOvertime,
                      '${stats.overtimeHours.toStringAsFixed(1)}h',
                      stats.overtimeHours > 0 ? Colors.orange : Colors.grey),
                ],
              ),
              const Divider(height: 24),
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l10n.upcomingShifts,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              const SizedBox(height: 8),
              if (stats.upcoming.isEmpty)
                Text(l10n.noUpcomingShifts,
                    style: const TextStyle(color: Colors.grey))
              else
                ...stats.upcoming.take(5).map((a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                          '${DateFormat('EEE, MMM d').format(a.scheduledDate)} • ${DateTimeUtils.formatTime(a.startDateTime)} → ${DateTimeUtils.formatTime(a.endDateTime)}'),
                      subtitle: Text(a.areaId),
                    )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 150,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
              child:
                  Text(value, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _stat(String label, String value, Color color) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: color.withOpacity(0.12),
    );
  }
}

/// Aggregated schedule statistics for one employee over the current week
/// and month.
class EmployeeScheduleStats {
  final double hoursThisWeek;
  final double hoursThisMonth;
  final int totalShifts;
  final int nightShifts;
  final int weekendShifts;
  final double overtimeHours;
  final List<ScheduleAssignment> upcoming;

  const EmployeeScheduleStats({
    required this.hoursThisWeek,
    required this.hoursThisMonth,
    required this.totalShifts,
    required this.nightShifts,
    required this.weekendShifts,
    required this.overtimeHours,
    required this.upcoming,
  });
}

final employeeScheduleStatsProvider = FutureProvider.family<
    EmployeeScheduleStats, String>((ref, employeeId) async {
  final repository = ref.watch(scheduleRepositoryProvider);
  final now = DateTime.now();
  final weekStart = DateTimeUtils.getStartOfWeek(now);
  final monthStart = DateTime(now.year, now.month, 1);

  // Load the weeks overlapping the current month (up to 6 weeks back).
  final schedules = <WeeklySchedule>[];
  for (var i = 5; i >= 0; i--) {
    final ws = weekStart.subtract(Duration(days: 7 * i));
    final s = await repository.getScheduleByWeek(ws);
    if (s != null) schedules.add(s);
  }

  final assignments = schedules.expand((s) => s.assignments).toList();
  final mine = assignments
      .where((a) => a.employeeId == employeeId)
      .toList()
    ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));

  double hoursIn(DateTime from, DateTime to) {
    var total = 0.0;
    for (final a in mine) {
      if (!a.startDateTime.isBefore(from) && a.startDateTime.isBefore(to)) {
        total += a.duration.inMinutes / 60.0;
      }
    }
    return total;
  }

  final monthEnd = DateTime(now.year, now.month + 1, 1);
  var nightShifts = 0;
  var weekendShifts = 0;
  var overtimeMinutes = 0;
  for (final a in mine) {
    if (a.startDateTime.isBefore(monthStart)) continue;
    if (a.isOvernight ||
        a.startDateTime.hour >= 20 ||
        a.startDateTime.hour < 5) {
      nightShifts++;
    }
    if (a.scheduledDate.weekday == DateTime.friday ||
        a.scheduledDate.weekday == DateTime.saturday) {
      weekendShifts++;
    }
    if (a.duration.inMinutes > 8 * 60) {
      overtimeMinutes += a.duration.inMinutes - 8 * 60;
    }
  }

  return EmployeeScheduleStats(
    hoursThisWeek: hoursIn(weekStart, weekStart.add(const Duration(days: 7))),
    hoursThisMonth: hoursIn(monthStart, monthEnd),
    totalShifts: mine.where((a) => !a.startDateTime.isBefore(monthStart)).length,
    nightShifts: nightShifts,
    weekendShifts: weekendShifts,
    overtimeHours: overtimeMinutes / 60.0,
    upcoming: mine
        .where((a) => a.endDateTime.isAfter(now))
        .toList(),
  );
});
