import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/core/utils/directional_icons.dart';
import 'package:reception_workforce_scheduler/features/employees/domain/entities/employee.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/schedule_generator.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/dialogs/generation_report_dialog.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/viewmodels/scheduler_view_model.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';

/// One "Area + Shift" slot on one day of the week. Times always come from
/// the linked shift template - never entered manually.
class _Slot {
  final String areaId;
  final String templateId;
  final ShiftTemplateEntity template;
  final DateTime day;
  int required = 0;
  final List<ScheduleAssignment> assignments = [];

  _Slot({
    required this.areaId,
    required this.templateId,
    required this.template,
    required this.day,
  });

  DateTime get start =>
      DateTime(day.year, day.month, day.day, template.startMinute ~/ 60,
          template.startMinute % 60);
  DateTime get end => start.add(Duration(minutes: template.durationMinutes));

  bool matches(ScheduleAssignment a) {
    if (a.areaId != areaId) return false;
    if (!_sameDay(a.scheduledDate, day)) return false;
    if (a.shiftTemplateId == templateId) return true;
    // Manual assignments without a template count when they overlap the
    // template window by at least 30 minutes.
    final overlapStart =
        a.startDateTime.isAfter(start) ? a.startDateTime : start;
    final overlapEnd = a.endDateTime.isBefore(end) ? a.endDateTime : end;
    return overlapEnd.difference(overlapStart).inMinutes >= 30;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Admin-only Smart Schedule Builder: a visual grid of Area × Shift slots
/// per day with drag-and-drop assignment, live coverage, suggestions and
/// one-tap Auto Fill. Shift times always come from shift templates.
class ScheduleBuilderPage extends ConsumerWidget {
  const ScheduleBuilderPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(schedulerViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    final slots = _buildSlots(state);
    final weeklyHours = <String, double>{
      for (final e in state.employees)
        e.id: state.schedule?.getWeeklyHoursForEmployee(e.id) ?? 0,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.builderTitle),
        actions: [
          IconButton(
            icon: Icon(DirectionalIcons.chevronBackward(context)),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).changeWeek(-1),
          ),
          Center(
            child: Text(
              '${DateFormat('MMM d').format(state.weekStart)} - '
              '${DateFormat('MMM d').format(state.weekStart.add(const Duration(days: 6)))}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(DirectionalIcons.chevronForward(context)),
            onPressed: () =>
                ref.read(schedulerViewModelProvider.notifier).changeWeek(1),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (action) =>
                _onMenu(context, ref, action, state, slots),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'autofill', child: Text(l10n.autoFill)),
              PopupMenuItem(
                  value: 'copyprev', child: Text(l10n.copyPrevWeek)),
              PopupMenuItem(
                  value: 'savetpl', child: Text(l10n.saveTemplate)),
              PopupMenuItem(
                  value: 'applytpl', child: Text(l10n.applyTemplate)),
              PopupMenuItem(value: 'save', child: Text(l10n.saveDraft)),
              PopupMenuItem(value: 'publish', child: Text(l10n.publish)),
              PopupMenuItem(value: 'unpublish', child: Text(l10n.unpublish)),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(l10n.errorPrefix(state.error!)))
              : state.schedule == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, ref, state, slots, weeklyHours),
      persistentFooterButtons: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: Text(l10n.autoFill),
            style: FilledButton.styleFrom(backgroundColor: Colors.deepPurple),
            onPressed: () => _autoFill(context, ref),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: Text(l10n.saveDraft),
            onPressed: () => _saveDraft(context, ref),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.publish),
            label: Text(
                state.schedule?.status == ScheduleStatus.published
                    ? l10n.unpublish
                    : l10n.publish),
            onPressed: () {
              final notifier = ref.read(schedulerViewModelProvider.notifier);
              if (state.schedule?.status == ScheduleStatus.published) {
                notifier.unpublish();
              } else {
                notifier.publish();
              }
            },
          ),
        ]),
      ],
    );
  }

  // ------------------------------------------------------------- slots

  /// Builds the Area × Shift slots for the visible week from the staffing
  /// requirements (the single source for what must be covered).
  List<_Slot> _buildSlots(SchedulerState state) {
    final templates = {
      for (final t in state.shiftTemplates) t.templateId: t
    };
    final resolved =
        resolveRequirements(state.staffingRequirements, state.shiftTemplates);
    final weekStart = DateTimeUtils.getStartOfWeek(state.weekStart);
    final slots = <_Slot>[];
    for (var d = 0; d < 7; d++) {
      final day = weekStart.add(Duration(days: d));
      for (final r in resolved) {
        if (r.dayOfWeek != 0 && r.dayOfWeek != day.weekday) continue;
        final template = templates[r.shiftTemplateId];
        if (template == null) continue;
        final slot = _Slot(
          areaId: r.areaId,
          templateId: r.shiftTemplateId,
          template: template,
          day: day,
        );
        slot.required += r.requiredCount;
        slot.assignments.addAll(
          state.schedule?.assignments.where(slot.matches) ?? const [],
        );
        slots.add(slot);
      }
    }
    // Stable order: area, then shift start time, then day.
    slots.sort((a, b) {
      final byArea = a.areaId.compareTo(b.areaId);
      if (byArea != 0) return byArea;
      final byStart = a.template.startMinute.compareTo(b.template.startMinute);
      if (byStart != 0) return byStart;
      return a.day.compareTo(b.day);
    });
    return slots;
  }

  // ------------------------------------------------------------- body

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    SchedulerState state,
    List<_Slot> slots,
    Map<String, double> weeklyHours,
  ) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _employeePool(context, ref, state, weeklyHours),
          const VerticalDivider(width: 1),
          Expanded(child: _grid(context, ref, state, slots)),
        ],
      );
    }
    return Column(children: [
      _employeePool(context, ref, state, weeklyHours, compact: true),
      const Divider(height: 1),
      Expanded(child: _grid(context, ref, state, slots)),
    ]);
  }

  // ------------------------------------------------------- employee pool

  Widget _employeePool(
    BuildContext context,
    WidgetRef ref,
    SchedulerState state,
    Map<String, double> weeklyHours, {
    bool compact = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final settings = state.settings ?? _defaultSettings();
    final pool = state.employees.toList()
      ..sort((a, b) => (weeklyHours[b.id] ?? 0)
          .compareTo(weeklyHours[a.id] ?? 0));

    return Container(
      width: compact ? double.infinity : 280,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Text(l10n.employeePool,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: pool.length,
              itemBuilder: (context, i) {
                final e = pool[i];
                final hours = weeklyHours[e.id] ?? 0;
                final limit = e.maxWeeklyHours > 0
                    ? e.maxWeeklyHours
                    : settings.maxWeeklyHours;
                final overloaded = hours > limit + 0.01;
                final nearLimit = !overloaded && hours >= limit * 0.85;
                return Draggable<String>(
                  data: e.id,
                  feedback: _poolCard(
                      context, e, hours, limit, overloaded, nearLimit, true),
                  child: _poolCard(
                      context, e, hours, limit, overloaded, nearLimit, false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _poolCard(BuildContext context, Employee e, double hours,
      double limit, bool overloaded, bool nearLimit, bool dragging) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      color: dragging ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                      '${hours.toStringAsFixed(1)}h / ${limit.toStringAsFixed(0)}h',
                      style: TextStyle(
                          fontSize: 11,
                          color: overloaded
                              ? Colors.red
                              : nearLimit
                                  ? Colors.orange
                                  : Colors.grey)),
                ]),
          ),
          if (overloaded)
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 18),
        ]),
      ),
    );
  }

  // ------------------------------------------------------------- grid

  Widget _grid(
      BuildContext context, WidgetRef ref, SchedulerState state,
      List<_Slot> slots) {
    final weekStart = DateTimeUtils.getStartOfWeek(state.weekStart);
    final areaNames = {for (final a in state.areas) a.areaId: a.name};

    // Group slots into rows of (area, template).
    final rowKeys = <String>[];
    final byKey = <String, List<_Slot>>{};
    for (final s in slots) {
      final key = '${s.areaId}|${s.templateId}';
      byKey.putIfAbsent(key, () => []).add(s);
      if (!rowKeys.contains(key)) rowKeys.add(key);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header row.
            Row(children: [
              const SizedBox(width: 190),
              for (var d = 0; d < 7; d++)
                SizedBox(
                  width: 230,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(children: [
                      Text(DateFormat('EEE').format(weekStart.add(Duration(days: d))),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            DateFormat('MMM d').format(
                                weekStart.add(Duration(days: d))),
                            style: const TextStyle(fontSize: 11)),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy, size: 14),
                          tooltip: AppLocalizations.of(context)!.copyDay,
                          onPressed: () => ref
                              .read(schedulerViewModelProvider.notifier)
                              .copyDay(
                                weekStart.add(Duration(days: d)),
                                weekStart
                                    .add(Duration(days: (d + 1) % 7)),
                              ),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ]),
            // One row per Area+Shift slot type.
            for (final key in rowKeys)
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 190,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              areaNames[byKey[key]!.first.areaId] ??
                                  byKey[key]!.first.areaId,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          Text(
                              '${byKey[key]!.first.template.name} '
                              '${_windowLabel(byKey[key]!.first.template)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                        ]),
                  ),
                ),
                for (var d = 0; d < 7; d++)
                  _slotCell(
                    context,
                    ref,
                    state,
                    byKey[key]!.firstWhere(
                      (s) => _sameDay(
                          s.day, weekStart.add(Duration(days: d))),
                      orElse: () => byKey[key]!.first,
                      ),
                    exists: byKey[key]!
                        .any((s) => _sameDay(
                            s.day, weekStart.add(Duration(days: d)))),
                  ),
              ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _windowLabel(ShiftTemplateEntity t) {
    String f(int m) =>
        '${(((m % 1440) + 1440) % 1440 ~/ 60).toString().padLeft(2, '0')}:${(((m % 1440) + 1440) % 1440 % 60).toString().padLeft(2, '0')}';
    return '${f(t.startMinute)} → ${f(t.startMinute + t.durationMinutes)}';
  }

  // ------------------------------------------------------------ slot cell

  Widget _slotCell(
    BuildContext context,
    WidgetRef ref,
    SchedulerState state,
    _Slot slot, {
    required bool exists,
  }) {
    if (!exists) {
      return const SizedBox(
          width: 230, height: 74, child: SizedBox.shrink());
    }
    final l10n = AppLocalizations.of(context)!;
    final assigned = slot.assignments.length;
    final hasConflict = slot.assignments.any((a) =>
        (state.conflictsByAssignment[a.id] ?? const []).isNotEmpty);
    final color = hasConflict
        ? Colors.deepOrange
        : assigned < slot.required
            ? Colors.red
            : assigned > slot.required
                ? Colors.amber.shade700
                : Colors.green;

    return DragTarget<String>(
      onWillAccept: (data) => data != null,
      onAccept: (employeeId) =>
          _assignEmployee(context, ref, state, slot, employeeId),
      builder: (context, candidate, _) => DragTarget<ScheduleAssignment>(
        onWillAccept: (data) =>
            data != null &&
            (data.areaId != slot.areaId ||
                data.shiftTemplateId != slot.templateId ||
                !_sameDay(data.scheduledDate, slot.day)),
        onAccept: (assignment) => _moveAssignment(context, ref, slot, assignment),
        builder: (context, candidateAssignments, _) => Container(
          width: 230,
          height: 74,
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(candidate.isNotEmpty ? 0.22 : 0.08),
            border: Border.all(color: color, width: candidate.isNotEmpty ? 2 : 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_statusIcon(hasConflict, assigned, slot.required),
                    size: 13, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.requiredAssignedLabel(
                        '${slot.required}', '$assigned'),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                InkWell(
                  onTap: () => _showSuggestions(context, ref, state, slot),
                  child: Icon(Icons.auto_awesome,
                      size: 14, color: Colors.deepPurple.shade300),
                ),
              ]),
              Expanded(
                child: Wrap(
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    for (final a in slot.assignments)
                      _assignmentChip(context, ref, state, a, hasConflict),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(bool conflict, int assigned, int required) {
    if (conflict) return Icons.warning_amber_rounded;
    if (assigned < required) return Icons.error_outline;
    if (assigned > required) return Icons.trending_up;
    return Icons.check_circle_outline;
  }

  Widget _assignmentChip(BuildContext context, WidgetRef ref,
      SchedulerState state, ScheduleAssignment a, bool hasConflict) {
    final employee = state.employees.where((e) => e.id == a.employeeId).firstOrNull;
    final conflicts = state.conflictsByAssignment[a.id] ?? const [];
    return Draggable<ScheduleAssignment>(
      data: a,
      feedback: Chip(
        label: Text(employee?.fullName ?? a.employeeId.substring(0, 8)),
      ),
      child: InkWell(
        onTap: () => _assignmentMenu(context, ref, a),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hasConflict ? Colors.deepOrange.withOpacity(0.15) : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: hasConflict ? Colors.deepOrange : Colors.grey),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (conflicts.isNotEmpty) ...[
              const Icon(Icons.warning_amber_rounded,
                  size: 11, color: Colors.deepOrange),
              const SizedBox(width: 2),
            ],
            Text(
              employee?.fullName.split(' ').first ?? a.employeeId.substring(0, 6),
              style: const TextStyle(fontSize: 11),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------- actions

  void _assignEmployee(BuildContext context, WidgetRef ref, SchedulerState state,
      _Slot slot, String employeeId) {
    final employee = state.employees.where((e) => e.id == employeeId).firstOrNull;
    if (employee == null) return;
    if (!employee.isAllowedInArea(slot.areaId)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)!
            .areaNotAllowedWarning(
                slot.areaId)),
        backgroundColor: Colors.orange,
      ));
    }
    ref.read(schedulerViewModelProvider.notifier).addAssignment(
          employeeId: employeeId,
          areaId: slot.areaId,
          date: slot.day,
          startTime: TimeOfDay.fromDateTime(slot.start),
          endTime: TimeOfDay.fromDateTime(slot.end),
          shiftTemplateId: slot.templateId,
        );
  }

  void _moveAssignment(
      BuildContext context, WidgetRef ref, _Slot slot, ScheduleAssignment a) {
    ref.read(schedulerViewModelProvider.notifier).updateAssignment(
          a.copyWith(
            areaId: slot.areaId,
            shiftTemplateId: slot.templateId,
            scheduledDate:
                DateTime(slot.day.year, slot.day.month, slot.day.day),
            startDateTime: slot.start,
            endDateTime: slot.end,
            updatedBy:
                ref.read(schedulerViewModelProvider.notifier).currentUserId,
          ),
        );
  }

  void _assignmentMenu(
      BuildContext context, WidgetRef ref, ScheduleAssignment a) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.copy),
          title: Text(l10n.duplicate),
          onTap: () {
            Navigator.pop(ctx);
            ref.read(schedulerViewModelProvider.notifier).duplicateAssignment(a.id);
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: Colors.red),
          title: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          onTap: () {
            Navigator.pop(ctx);
            ref.read(schedulerViewModelProvider.notifier).deleteAssignment(a.id);
          },
        ),
      ]),
    );
  }

  // ------------------------------------------------------- suggestions

  void _showSuggestions(BuildContext context, WidgetRef ref,
      SchedulerState state, _Slot slot) {
    final l10n = AppLocalizations.of(context)!;
    final generator = ScheduleGenerator(
      settings: state.settings ?? _defaultSettings(),
      employees: state.employees,
      areas: state.areas,
      requirements: state.staffingRequirements,
      shiftTemplates: state.shiftTemplates,
      availabilities: state.availabilities,
      leaves: state.leaves,
      fixedAssignments: state.schedule?.assignments ?? const [],
      weekStart: state.weekStart,
      createdBy: ref.read(schedulerViewModelProvider.notifier).currentUserId,
    );

    final candidates = <(Employee, double)>[];
    for (final e in state.employees) {
      final score = generator.scoreCandidateForWindow(
          e, slot.start, slot.end, slot.areaId,
          state.schedule?.assignments ?? const []);
      if (score != null) candidates.add((e, score));
    }
    candidates.sort((a, b) => a.$2.compareTo(b.$2));

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SizedBox(
        height: 380,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l10n.suggestEmployees,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: candidates.isEmpty
                ? Center(child: Text(l10n.noSuggestions))
                : ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, i) {
                      final (e, score) = candidates[i];
                      final allowed = e.isAllowedInArea(slot.areaId);
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          allowed ? Icons.check_circle : Icons.warning_amber,
                          color: allowed ? Colors.green : Colors.orange,
                          size: 20,
                        ),
                        title: Text(e.fullName, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                            '${(generator.scoreCandidateForWindow(e, slot.start, slot.end, slot.areaId, state.schedule?.assignments ?? const []) ?? 0).toStringAsFixed(2)} • ${e.preferredAreas.isEmpty ? l10n.allAreas : ''}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _assignEmployee(context, ref, state, slot, e.id);
                          },
                          child: Text(l10n.add),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  // ------------------------------------------------------- menu actions

  void _onMenu(BuildContext context, WidgetRef ref, String action,
      SchedulerState state, List<_Slot> slots) {
    switch (action) {
      case 'autofill':
        _autoFill(context, ref);
        break;
      case 'copyprev':
        ref.read(schedulerViewModelProvider.notifier).copyPreviousWeek();
        break;
      case 'savetpl':
        _saveTemplate(context, ref);
        break;
      case 'applytpl':
        _applyTemplate(context, ref);
        break;
      case 'save':
        _saveDraft(context, ref);
        break;
      case 'publish':
        ref.read(schedulerViewModelProvider.notifier).publish();
        break;
      case 'unpublish':
        ref.read(schedulerViewModelProvider.notifier).unpublish();
        break;
    }
  }

  Future<void> _autoFill(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(schedulerViewModelProvider);
    final result =
        await ref.read(schedulerViewModelProvider.notifier).generateSchedule();
    if (result == null) return;
    if (!context.mounted) return;
    final areaNames = {for (final a in state.areas) a.areaId: a.name};
    final employeeNames = {
      for (final e in state.employees) e.id: e.fullName
    };
    await showDialog(
      context: context,
      builder: (_) => GenerationReportDialog(
        result: result,
        areaNames: areaNames,
        employeeNames: employeeNames,
      ),
    );
    messenger.showSnackBar(SnackBar(
        content: Text(l10n.autoFillDone), backgroundColor: Colors.purple));
  }

  Future<void> _saveDraft(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(schedulerViewModelProvider.notifier).saveDraft();
    messenger.showSnackBar(SnackBar(content: Text(l10n.draftSaved)));
  }

  Future<void> _saveTemplate(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.saveTemplate),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: l10n.templateName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: Text(l10n.save)),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(schedulerViewModelProvider.notifier).saveAsTemplate(name);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.templateSaved)));
      }
    }
  }

  Future<void> _applyTemplate(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final repository = ref.read(scheduleRepositoryProvider);
    final templates = await repository.getScheduleTemplates();
    if (!context.mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noSavedTemplates)));
      return;
    }
    final selected = await showDialog<WeeklySchedule>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.chooseTemplate),
        children: templates
            .map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t),
                  child: Text(
                      '${DateFormat('MMM d, yyyy').format(t.weekStartDate)} • ${t.assignments.length}'),
                ))
            .toList(),
      ),
    );
    if (selected != null) {
      await ref.read(schedulerViewModelProvider.notifier).applyTemplate(selected);
    }
  }

  SystemSettings _defaultSettings() {
    return SystemSettings(
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
  }
}
