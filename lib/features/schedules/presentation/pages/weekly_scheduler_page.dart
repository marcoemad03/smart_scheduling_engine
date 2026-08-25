import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/theme/app_theme.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/conflict_detector.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/assignment_dialog.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/bulk_and_template_dialogs.dart';
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
        title: const Text('Weekly Schedule'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).changeWeek(-1),
          ),
          Text(DateFormat('MMM d').format(state.weekStart) +
              ' - ' +
              DateFormat('MMM d, yyyy').format(state.weekStart
                  .add(const Duration(days: 6)))),
          IconButton(
            icon: const Icon(Icons.chevron_right),
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
              ? Center(child: Text('Error: ${state.error}'))
              : _buildBody(context, state, days, employeeNameMap, areaNameMap),
      persistentFooterButtons: [
        _buildActionBar(context, state),
      ],
      floatingActionButton: state.employees.isEmpty || state.areas.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddDialog(context, state, state.weekStart),
              label: const Text('Add Shift'),
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Chip(
              label: Text('Unsaved changes'),
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
          child: const Text('Employee',
              style: TextStyle(fontWeight: FontWeight.bold)),
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
                      tooltip: 'Copy this day to another',
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
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                  right: BorderSide(color: Colors.grey.shade200),
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
                        const Text('Long shift',
                            style: TextStyle(fontSize: 10, color: Colors.deepPurple)),
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
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              _showEditDialog(context, state, a);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Duplicate'),
            onTap: () {
              Navigator.pop(ctx);
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .duplicateAssignment(a.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.call_split),
            title: const Text('Split Shift'),
            onTap: () {
              Navigator.pop(ctx);
              _showSplitDialog(context, a);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
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

  Widget _buildActionBar(BuildContext context, SchedulerState state) {
    final isPublished =
        state.schedule?.status == ScheduleStatus.published;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.content_copy),
          label: const Text('Copy Prev Week'),
          onPressed: () => ref
              .read(schedulerViewModelProvider.notifier)
              .copyPreviousWeek(),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.content_copy),
          label: const Text('Copy Prev Week'),
          onPressed: () => ref
              .read(schedulerViewModelProvider.notifier)
              .copyPreviousWeek(),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: const Icon(Icons.group_add),
          label: const Text('Bulk Assign'),
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
          icon: const Icon(Icons.check_circle),
          label: const Text('Validate'),
          onPressed: () {
            final conflicts = ref
                .read(schedulerViewModelProvider.notifier)
                .validateSchedule();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(conflicts.isEmpty
                    ? 'No conflicts found'
                    : '${conflicts.length} conflict(s) detected'),
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
            label: const Text('Unpublish'),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).unpublish(),
          )
        else
          FilledButton.icon(
            icon: const Icon(Icons.publish),
            label: const Text('Publish'),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).publish(),
          ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.add_box),
          label: const Text('New Version'),
          onPressed: () =>
              ref.read(schedulerViewModelProvider.notifier).newVersion(),
        ),
        const SizedBox(width: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.bookmark),
          label: const Text('Templates'),
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
    TimeOfDay split = TimeOfDay(
        hour: (a.startDateTime.hour + a.endDateTime.hour) ~/ 2, minute: 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Split Shift'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Split the shift at:'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final t = await showTimePicker(context: ctx, initialTime: split);
                if (t != null) setState(() => split = t);
              },
              child: InputDecorator(
                decoration:
                    const InputDecoration(labelText: 'Split Time'),
                child: Text(split.format(ctx)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .splitShift(a.id, split);
              Navigator.pop(ctx);
            },
            child: const Text('Split'),
          ),
        ],
      ),
    );
  }

  void _showCopyDayDialog(
      BuildContext context, SchedulerState state, DateTime from) {
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime? target = from.add(const Duration(days: 1));
        return AlertDialog(
          title: const Text('Copy Day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Copy all shifts from this day to:'),
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
              child: const Text('Cancel'),
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
              child: const Text('Copy'),
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
    final label = status.name.toUpperCase();
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
