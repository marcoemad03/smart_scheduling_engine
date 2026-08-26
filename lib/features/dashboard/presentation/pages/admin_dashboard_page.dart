import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/attendance/data/attendance_repository.dart';
import 'package:reception_workforce_scheduler/features/attendance/domain/entities/attendance_record.dart';
import 'package:reception_workforce_scheduler/features/leaves/data/leaves_repository.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/swaps/data/swaps_repository.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/workload_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/viewmodels/scheduler_view_model.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardPage> createState() =>
      _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(schedulerViewModelProvider.notifier);
      if (ref.read(schedulerViewModelProvider).weekCoverage == null) {
        vm.loadWeek(DateTimeUtils.getStartOfWeek(DateTime.now()));
      }
      ref.read(adminAttendanceProvider.notifier).watch(
            employeeId: '',
            from: DateTimeUtils.getStartOfWeek(DateTime.now())
                .subtract(const Duration(days: 1)),
            to: DateTimeUtils.getStartOfWeek(DateTime.now())
                .add(const Duration(days: 8)),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulerViewModelProvider);
    final attendanceAsync = ref.watch(adminAttendanceProvider);
    final leaves = ref.watch(adminLeavesViewModelProvider).asData?.value ?? [];
    final swaps = ref.watch(adminSwapsViewModelProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.adminDashboardTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              _sectionTitle(context, AppLocalizations.of(context)!.keyMetrics),
              const SizedBox(height: 12),
              _kpis(context, state, attendanceAsync, leaves, swaps),
              const SizedBox(height: 24),
              _todaysCoverageSection(context, state),
              const SizedBox(height: 24),
              _weeklyWorkloadSection(context, state),
              const SizedBox(height: 24),
            ],
            _sectionTitle(context, AppLocalizations.of(context)!.quickActions),
            const SizedBox(height: 12),
            _quickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- KPI cards

  Widget _kpis(
    BuildContext context,
    SchedulerState state,
    AsyncValue<List<AttendanceRecord>> attendance,
    List leaves,
    List swaps,
  ) {
    final today = DateTime.now();
    final todayResult = const CoverageCalculator().calculateForDay(
      day: today,
      assignments: state.schedule?.assignments ?? const [],
      requirements: state.staffingRequirements,
    );

    var understaffedAreas = <String>{};
    var overstaffedAreas = <String>{};
    for (final i in todayResult.intervals) {
      if (i.status == CoverageStatus.understaffed) understaffedAreas.add(i.areaId);
      if (i.status == CoverageStatus.overstaffed) overstaffedAreas.add(i.areaId);
    }

    final errorConflicts = state.conflictsByAssignment.values
        .expand((c) => c)
        .where((c) => c.severity == ConflictSeverity.error)
        .length;

    final summary = AttendanceSummary.of(attendance.asData?.value ?? []);

    final workloads = const WorkloadCalculator().compute(
      weekStart: state.weekStart,
      assignments: state.schedule?.assignments ?? const [],
      employees: state.employees,
      settings: state.settings ??
          _defaultSettings(),
    );
    final totalHours =
        workloads.fold<double>(0, (s, w) => s + w.totalHours);
    final totalOvertime =
        workloads.fold<double>(0, (s, w) => s + w.overtimeHours);

    final pendingRequests =
        leaves.where((r) => r.status.name == 'pending').length +
            swaps.where((r) => r.status.name == 'pending').length;

    final activeEmployees =
        state.employees.where((e) => e.isActive).length;
    final l10n = AppLocalizations.of(context)!;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = width > 1100
          ? (width - 60) / 4
          : width > 700
              ? (width - 40) / 3
              : (width - 16) / 2;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _kpi(l10n.activeEmployees, '$activeEmployees', Icons.people_outline,
              Colors.blue, cardWidth),
          _kpi(l10n.scheduledToday, '${todayResult.totalScheduled}',
              Icons.event_available, Colors.indigo, cardWidth),
          _kpi(l10n.requiredToday, '${todayResult.totalRequired}',
              Icons.flag_outlined, Colors.teal, cardWidth),
          _kpi(
              l10n.coverage,
              '${todayResult.coveragePercentage.toStringAsFixed(1)}%',
              Icons.donut_large,
              statusColorOf(todayResult.status),
              cardWidth),
          _kpi(l10n.understaffedAreas, '${understaffedAreas.length}',
              Icons.trending_down, Colors.red, cardWidth),
          _kpi(l10n.overstaffedAreas, '${overstaffedAreas.length}',
              Icons.trending_up, Colors.orange, cardWidth),
          _kpi(l10n.scheduleConflicts, '$errorConflicts', Icons.warning_amber,
              errorConflicts > 0 ? Colors.red : Colors.green, cardWidth),
          _kpi(l10n.pendingRequests, '$pendingRequests', Icons.pending_outlined,
              pendingRequests > 0 ? Colors.amber.shade800 : Colors.grey, cardWidth),
          _kpi(l10n.totalWeeklyHours, '${totalHours.toStringAsFixed(1)}h',
              Icons.schedule, Colors.purple, cardWidth),
          _kpi(l10n.overtime, '${totalOvertime.toStringAsFixed(1)}h',
              Icons.trending_flat, totalOvertime > 0 ? Colors.deepOrange : Colors.grey, cardWidth),
          _kpi(l10n.lateToday, '${summary.lateCount}', Icons.access_time,
              summary.lateCount > 0 ? Colors.orange : Colors.grey, cardWidth),
          _kpi(l10n.absences, '${summary.absentCount}', Icons.person_off_outlined,
              summary.absentCount > 0 ? Colors.red : Colors.grey, cardWidth),
        ],
      );
    });
  }

  Widget _kpi(String label, String value, IconData icon, Color color,
      double width) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ------------------------------------------------- Today's coverage table

  Widget _todaysCoverageSection(BuildContext context, SchedulerState state) {
    final todayResult = const CoverageCalculator().calculateForDay(
      day: DateTime.now(),
      assignments: state.schedule?.assignments ?? const [],
      requirements: state.staffingRequirements,
    );
    final areaNames = {for (final a in state.areas) a.areaId: a.name};
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.today, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  l10n.todaysCoverage(
                      DateFormat('EEEE, MMM d').format(DateTime.now())),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 12),
          if (!todayResult.hasRequirements)
            Text(l10n.noRequirementsToday,
                style: const TextStyle(color: Colors.grey))
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.2),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
                3: FlexColumnWidth(2),
              },
              border: TableBorder.symmetric(
                  inside: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              children: [
                TableRow(children: [
                  _th(l10n.colArea),
                  _th(l10n.colRequired),
                  _th(l10n.colScheduled),
                  _th(l10n.colStatus),
                ]),
                ...todayResult.intervals.map((i) => TableRow(children: [
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                              '${areaNames[i.areaId] ?? i.areaId} • ${_hm(i.startMinute)}→${_hm(i.endMinute)}')),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text('${i.requiredCount}')),
                      Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text('${i.scheduledCount}')),
                      Padding(padding: const EdgeInsets.all(6), child: _statusChip(i.status)),
                    ])),
              ],
            ),
        ]),
      ),
    );
  }

  String _hm(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  static Widget _th(String text) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      );

  Widget _statusChip(CoverageStatus status) {
    final color = statusColorOf(status);
    final label = switch (status) {
      CoverageStatus.fullyCovered => AppLocalizations.of(context)!.statusCovered,
      CoverageStatus.overstaffed =>
        AppLocalizations.of(context)!.statusOverstaffed,
      CoverageStatus.understaffed =>
        AppLocalizations.of(context)!.statusUnderstaffed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(_statusIcon(status), size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color)),
      ]),
    );
  }

  IconData _statusIcon(CoverageStatus s) => switch (s) {
        CoverageStatus.fullyCovered => Icons.check_circle,
        CoverageStatus.overstaffed => Icons.arrow_circle_up,
        CoverageStatus.understaffed => Icons.error,
      };

  Color statusColorOf(CoverageStatus s) => switch (s) {
        CoverageStatus.fullyCovered => Colors.green,
        CoverageStatus.overstaffed => Colors.orange,
        CoverageStatus.understaffed => Colors.red,
      };

  // ----------------------------------------------- Weekly workload section

  Widget _weeklyWorkloadSection(BuildContext context, SchedulerState state) {
    final calculator = const WorkloadCalculator();
    final workloads = calculator.compute(
      weekStart: state.weekStart,
      assignments: state.schedule?.assignments ?? const [],
      employees: state.employees,
      settings: state.settings ?? _defaultSettings(),
    )..sort((a, b) => b.totalHours.compareTo(a.totalHours));
    final avg = calculator.averageHours(workloads);
    final employeeNames = {for (final e in state.employees) e.id: e.fullName};
    final l10n = AppLocalizations.of(context)!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.bar_chart, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  l10n.weeklyWorkload(DateFormat('MMM d').format(state.weekStart)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Spacer(),
            Text(l10n.teamAverage(avg.toStringAsFixed(1)),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 6),
          Text(
            l10n.redRowsNote,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (workloads.isEmpty)
            Text(l10n.noScheduleDataWeek,
                style: const TextStyle(color: Colors.grey))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 34,
                columns: [
                  DataColumn(label: Text(l10n.employee)),
                  DataColumn(label: Text(l10n.colHours), numeric: true),
                  DataColumn(label: Text(l10n.colDays), numeric: true),
                  DataColumn(label: Text(l10n.colNights), numeric: true),
                  DataColumn(label: Text(l10n.colWeekend), numeric: true),
                  DataColumn(label: Text(l10n.colLong), numeric: true),
                  DataColumn(label: Text(l10n.colOvertime), numeric: true),
                ],
                rows: workloads.map((w) {
                  final flagged =
                      calculator.isSignificantlyOverworked(w, avg) ||
                          w.overtimeHours > 0;
                  return DataRow(
                    color: flagged
                        ? WidgetStateProperty.all(Colors.red.withOpacity(0.07))
                        : null,
                    cells: [
                      DataCell(Row(children: [
                        if (flagged)
                          const Icon(Icons.priority_high,
                              size: 13, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(employeeNames[w.employeeId] ?? w.employeeId),
                      ])),
                      DataCell(Text(w.totalHours.toStringAsFixed(1))),
                      DataCell(Text('${w.daysWorked}')),
                      DataCell(Text('${w.nightShifts}')),
                      DataCell(Text('${w.weekendShifts}')),
                      DataCell(Text('${w.longShifts}')),
                      DataCell(Text(
                        w.overtimeHours > 0
                            ? '+${w.overtimeHours.toStringAsFixed(1)}h'
                            : '-',
                        style: TextStyle(
                            color: w.overtimeHours > 0
                                ? Colors.deepOrange
                                : null,
                            fontWeight: w.overtimeHours > 0
                                ? FontWeight.bold
                                : null),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- shared

  Widget _sectionTitle(BuildContext context, String title) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.bold));

  Widget _quickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final actions = [
      (Icons.calendar_today_outlined, l10n.navSchedules, '/admin/schedules'),
      (Icons.smart_toy_outlined, l10n.navAiAssistant, '/admin/assistant'),
      (Icons.people_outline, l10n.navEmployees, '/admin/employees'),
      (Icons.room_outlined, l10n.navAreas, '/admin/areas'),
      (Icons.badge_outlined, l10n.navStaffing, '/admin/staffing'),
      (Icons.fact_check_outlined, l10n.navAttendance, '/admin/attendance'),
      (Icons.settings_outlined, l10n.navSettings, '/admin/settings'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: actions
          .map((a) => ActionChip(
                avatar: Icon(a.$1, size: 18),
                label: Text(a.$2),
                onPressed: () => context.go(a.$3),
              ))
          .toList(),
    );
  }
}

SystemSettings _defaultSettings() => SystemSettings(
      settingsId: 'default',
      maxWeeklyHours: 48,
      minRestPeriodMinutes: 480,
      workingHoursStart: 480,
      workingHoursEnd: 1320,
      allowCustomSchedules: true,
      enableAttendanceTracking: false,
      timezone: 'UTC',
      weekStartDay: 1,
      updatedAt: DateTime.now(),
      updatedBy: '',
    );

