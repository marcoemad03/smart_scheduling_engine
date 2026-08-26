import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/theme/app_theme.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/core/utils/directional_icons.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/assignment_dialog.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/bulk_and_template_dialogs.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/generation_report_dialog.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/viewmodels/scheduler_view_model.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/widgets/conflict_panel.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/widgets/shift_display_helper.dart';

class WeeklySchedulerPage extends ConsumerStatefulWidget {
  const WeeklySchedulerPage({Key? key}) : super(key: key);

  @override
  ConsumerState<WeeklySchedulerPage> createState() => _WeeklySchedulerPageState();
}

class _WeeklySchedulerPageState extends ConsumerState<WeeklySchedulerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(schedulerViewModelProvider);
      ref
          .read(schedulerViewModelProvider.notifier)
          .loadWeek(state.weekStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulerViewModelProvider);
    final days = _weekDays(state.weekStart);
    final employeeNameMap = {
      for (final e in state.employees) e.id: e.fullName
    };
    final areaNameMap = {
      for (final a in state.areas) a.areaId: a.name
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.weeklyScheduleTitle),
        actions: [
          IconButton(
            icon: Icon(DirectionalIcons.chevronBackward(context)),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).changeWeek(-1),
          ),
          Text(DateFormat('MMM d').format(state.weekStart) +
              ' - ' +
              DateFormat('MMM d, yyyy').format(state.weekStart
                  .add(const Duration(days: 6)))),
          IconButton(
            icon: Icon(DirectionalIcons.chevronForward(context)),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).changeWeek(1),
          ),
          const SizedBox(width: 16),
          _StatusBadge(status: state.schedule?.status ?? ScheduleStatus.draft),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Text(AppLocalizations.of(context)!
                      .errorPrefix(state.error!)))
              : _buildBody(context, state, days, employeeNameMap, areaNameMap),
      persistentFooterButtons: [
        _buildActionBar(context, state),
      ],
      floatingActionButton: state.employees.isEmpty || state.areas.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, state, state.weekStart),
              label: Text(AppLocalizations.of(context)!.addShift),
              icon: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SchedulerState state,
    List<DateTime> days,
    Map<String, String> employeeNames,
    Map<String, String> areaNames,
  ) {
    final allConflicts = <ScheduleConflict>[];
    for (final c in state.conflictsByAssignment.values) allConflicts.addAll(c);
    allConflicts.addAll(state.staffingConflicts);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ConflictPanel(
            conflicts: allConflicts,
            employeeNames: employeeNames,
            areaNames: areaNames,
          ),
        ),
        if (state.hasUnsavedChanges)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Chip(
              label: Text(AppLocalizations.of(context)!.unsavedChanges),
              backgroundColor: Colors.amber,
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 150.0 + days.length * 200.0,
              child: Column(
                children: [
                  _buildDayHeaders(context, state, days),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.employees.length,
                      itemBuilder: (context, index) {
                        final emp = state.employees[index];
                        return _buildEmployeeRow(context, state, emp, days);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders(
      BuildContext context, SchedulerState state, List<DateTime> days) {
    return Row(
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(8),
          child: Text(AppLocalizations.of(context)!.employee,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        ...days.map((day) => SizedBox(
              width: 200,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    Text(DateFormat('EEE').format(day),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(DateFormat('MMM d').format(day),
                        style: const TextStyle(fontSize: 11)),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      tooltip: AppLocalizations.of(context)!.copyDayTooltip,
                      onPressed: () => _showCopyDayDialog(context, state, day),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildEmployeeRow(BuildContext context, SchedulerState state,
      dynamic emp, List<DateTime> days) {
    return Row(
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${state.schedule?.getWeeklyHoursForEmployee(emp.id).toStringAsFixed(1) ?? "0.0"} h',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        ...days.map((day) {
          final cellAssignments = state.schedule!.assignments.where((a) =>
              a.employeeId == emp.id &&
              a.scheduledDate.year == day.year &&
              a.scheduledDate.month == day.month &&
              a.scheduledDate.day == day.day);
          return DragTarget<ScheduleAssignment>(
            onWillAccept: (data) => data != null,
            onAccept: (data) {
              ref.read(schedulerViewModelProvider.notifier).moveAssignment(
                    data.id,
                    day,
                    newEmployeeId: emp.id,
                  );
            },
            builder: (context, candidate, rejected) => Container(
              width: 200,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  bottom: BorderSide(color: Colors.grey.shade300),
                  end: BorderSide(color: Colors.grey.shade200),
                ),
                color: candidate.isNotEmpty
                    ? Colors.blue.withOpacity(0.1)
                    : null,
              ),
              child: Column(
                children: cellAssignments
                    .map((a) => _buildAssignmentCard(context, state, a))
                    .toList(),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAssignmentCard(
      BuildContext context, SchedulerState state, ScheduleAssignment a) {
    final conflicts = state.conflictsByAssignment[a.id] ?? [];
    final hasError = conflicts.any((c) =>
        c.severity == ConflictSeverity.error &&
        !state.overriddenAssignmentIds.contains(a.id));
    final hasWarning = conflicts.isNotEmpty && !hasError;
    final areaName =
        state.areas.where((ar) => ar.areaId == a.areaId).firstOrNull?.name ?? a.areaId;
    final color = hasError
        ? Colors.red
        : hasWarning
            ? Colors.orange
            : a.isOvernight
                ? AppTheme.light.colorScheme.tertiary
                : AppTheme.light.colorScheme.primary;

    return Draggable<ScheduleAssignment>(
      data: a,
      feedback: Material(
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${ShiftDisplayHelper.formatShiftTime(a)}\n$areaName',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 2),
        color: color.withOpacity(0.15),
        child: InkWell(
          onTap: () => _showAssignmentMenu(context, state, a),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(areaName,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: color)),
                      Text(
                        ShiftDisplayHelper.formatShiftTime(a),
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (a.isLongShift)
                        Text(AppLocalizations.of(context)!.longShift,
                            style: const TextStyle(fontSize: 10, color: Colors.deepPurple)),
                    ],
                  ),
                ),
                if (conflicts.isNotEmpty)
                  Icon(
                    hasError ? Icons.error : Icons.warning,
                    size: 14,
                    color: hasError ? Colors.red : Colors.orange,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignmentMenu(
      BuildContext context, SchedulerState state, ScheduleAssignment a) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l10n.edit),
            onTap: () {
              Navigator.pop(ctx);
              _showEditDialog(context, state, a);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(l10n.duplicate),
            onTap: () {
              Navigator.pop(ctx);
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .duplicateAssignment(a.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_split),
            title: Text(l10n.splitShift),
            onTap: () {
              Navigator.pop(ctx);
              _showSplitDialog(context, a);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .deleteAssignment(a.id);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _generate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result =
        await ref.read(schedulerViewModelProvider.notifier).generateSchedule();
    if (!mounted || result == null) return;
    final state = ref.read(schedulerViewModelProvider);
    await showDialog(
      context: this.context,
      builder: (_) => GenerationReportDialog(
        result: result,
        employeeNames: {for (final e in state.employees) e.id: e.fullName},
        areaNames: {for (final a in state.areas) a.areaId: a.name},
      ),
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.isFullyValid
            ? AppLocalizations.of(context)!.draftGeneratedValid
            : AppLocalizations.of(context)!.draftGeneratedReview),
        backgroundColor: result.isFullyValid ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(SnackBar(
        content: Text(
            e.toString().contains('CONCURRENT_MODIFICATION')
                ? l10n.concurrentModification
                : l10n.operationFailed(e.toString())),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildActionBar(BuildContext context, SchedulerState state) {
    final l10n = AppLocalizations.of(context)!;
    final isPublished =
        state.schedule?.status == ScheduleStatus.published;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.auto_fix_high),
          label: Text(l10n.generate),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.deepPurple,
          ),
          onPressed: () => _generate(context),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.content_copy),
          label: Text(l10n.copyPrevWeek),
          onPressed: () => ref
              .read(schedulerViewModelProvider.notifier)
              .copyPreviousWeek(),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.group_add),
          label: Text(l10n.bulkAssign),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => BulkAssignDialog(
              date: state.weekStart,
              employees: state.employees,
              areas: state.areas,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.save),
          label: Text(l10n.saveDraft),
          onPressed: () => _guard(context, () async {
            await ref.read(schedulerViewModelProvider.notifier).saveDraft();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.draftSaved)));
            }
          }),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.check_circle),
          label: Text(l10n.validate),
          onPressed: () {
            final conflicts = ref
                .read(schedulerViewModelProvider.notifier)
                .validateSchedule();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(conflicts.isEmpty
                    ? l10n.noConflictsFound
                    : l10n.conflictCount('${conflicts.length}')),
                backgroundColor:
                    conflicts.isEmpty ? Colors.green : Colors.orange,
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        if (isPublished)
          FilledButton.tonalIcon(
            icon: const Icon(Icons.unpublished),
            label: Text(l10n.unpublish),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).unpublish,
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.publish),
            label: Text(l10n.publish),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).publish,
          ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add_box),
          label: Text(l10n.newVersion),
          onPressed: () =>
              ref.read(schedulerViewModelProvider.notifier).newVersion,
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.bookmark),
          label: Text(l10n.templates),
          onPressed: () => showDialog(
            context: context,
            builder: (_) => TemplateDialog(
              employees: state.employees,
              areas: state.areas,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddDialog(
      BuildContext context, SchedulerState state, DateTime date) {
    showDialog(
      context: context,
      builder: (_) => AssignmentDialog(
        initialDate: date,
        employees: state.employees,
        areas: state.areas,
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, SchedulerState state, ScheduleAssignment a) {
    showDialog(
      context: context,
      builder: (_) => AssignmentDialog(
        assignment: a,
        initialDate: a.scheduledDate,
        employees: state.employees,
        areas: state.areas,
      ),
    );
  }

  void _showSplitDialog(BuildContext context, ScheduleAssignment a) {
    final l10n = AppLocalizations.of(context)!;
    TimeOfDay split = TimeOfDay(
        hour: (a.startDateTime.hour + a.endDateTime.hour) ~/ 2, minute: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.splitShift),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.splitTheShiftAt),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: split);
                if (t != null) setState(() => split = t);
              },
              child: InputDecorator(
                decoration: InputDecoration(labelText: l10n.splitTime),
                child: Text(split.format(ctx)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .splitShift(a.id, split);
              Navigator.pop(ctx);
            },
            child: Text(l10n.split),
          ),
        ],
      ),
    );
  }

  void _showCopyDayDialog(
      BuildContext context, SchedulerState state, DateTime from) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime? target = from.add(const Duration(days: 1));
        return AlertDialog(
          title: Text(l10n.copyDay),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.copyAllShiftsFrom),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (ctx2, setState) => DropdownButton<DateTime>(
                  value: target,
                  items: _weekDays(state.weekStart)
                      .where((d) => !_sameDay(d, from))
                      .map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(DateFormat('EEE MMM d').format(d)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => target = v),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (target != null) {
                  ref
                      .read(schedulerViewModelProvider.notifier)
                      .copyDay(from, target!);
                }
                Navigator.pop(ctx);
              },
              child: Text(l10n.copy),
            ),
          ],
        );
      },
    );
  }

  List<DateTime> _weekDays(DateTime start) {
    final ws = DateTimeUtils.getStartOfWeek(start);
    return List.generate(7, (i) => ws.add(Duration(days: i)));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _StatusBadge extends StatelessWidget {
  final ScheduleStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      ScheduleStatus.published => AppLocalizations.of(context)!.statusPublished,
      ScheduleStatus.archived => AppLocalizations.of(context)!.statusArchived,
      ScheduleStatus.draft => AppLocalizations.of(context)!.statusDraft,
    };
    final color = status == ScheduleStatus.published
        ? Colors.green
        : status == ScheduleStatus.archived
            ? Colors.grey
            : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}
