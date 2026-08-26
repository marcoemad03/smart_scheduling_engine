import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/features/shifts/data/shift_templates_repository.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/staffing/presentation/providers/staffing_providers.dart';

/// Localized full day name for an ISO weekday (1=Mon..7=Sun).
String localizedDayName(AppLocalizations l10n, int weekday) {
  final days = [
    l10n.dayMon,
    l10n.dayTue,
    l10n.dayWed,
    l10n.dayThu,
    l10n.dayFri,
    l10n.daySat,
    l10n.daySun,
  ];
  return days[weekday - 1];
}

class StaffingRequirementsPage extends ConsumerStatefulWidget {
  const StaffingRequirementsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<StaffingRequirementsPage> createState() =>
      _StaffingRequirementsPageState();
}

class _StaffingRequirementsPageState
    extends ConsumerState<StaffingRequirementsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(staffingViewModelProvider);
    final templatesAsync = ref.watch(shiftTemplatesProvider);
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final l10n = AppLocalizations.of(context)!;
    final templates = templatesAsync.asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffingTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (state.areas.isEmpty || templates.isEmpty)
            ? null
            : () => _showRequirementDialog(templates: templates),
        label: Text(l10n.addRequirement),
        icon: const Icon(Icons.add),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(l10n.errorPrefix(state.error!)))
              : state.requirements.isEmpty
                  ? Center(child: Text(l10n.noRequirements))
                  : isDesktop
                      ? _buildTable(state, templates)
                      : _buildList(state, templates),
    );
  }

  String? _areaName(StaffingState state, String areaId) {
    return state.areas
        .where((a) => a.areaId == areaId)
        .map((a) => a.name)
        .firstOrNull;
  }

  ShiftTemplateEntity? _template(
      List<ShiftTemplateEntity> templates, String templateId) {
    return templates.where((t) => t.templateId == templateId).firstOrNull;
  }

  String _dayLabel(AppLocalizations l10n, int dayOfWeek) =>
      dayOfWeek == 0 ? l10n.everyDay : localizedDayName(l10n, dayOfWeek);

  Widget _buildTable(
      StaffingState state, List<ShiftTemplateEntity> templates) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.colArea)),
          DataColumn(label: Text(l10n.colDay)),
          DataColumn(label: Text(l10n.colShift)),
          DataColumn(label: Text(l10n.colTimeWindow)),
          DataColumn(label: Text(l10n.colRequired)),
          DataColumn(label: Text(l10n.colActions)),
        ],
        rows: state.requirements.map((req) {
          final template = _template(templates, req.shiftTemplateId);
          final window = template == null
              ? l10n.notSet
              : _windowLabel(template);
          return DataRow(cells: [
            DataCell(Text(_areaName(state, req.areaId) ?? req.areaId)),
            DataCell(Text(_dayLabel(l10n, req.dayOfWeek))),
            DataCell(Text(template?.name ?? l10n.notSet)),
            DataCell(Text(window)),
            DataCell(Text('${req.requiredCount}')),
            DataCell(Row(children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _showRequirementDialog(requirement: req, templates: templates),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.duplicate,
                onPressed: () => ref
                    .read(staffingViewModelProvider.notifier)
                    .saveRequirement(
                        req.copyWith(requirementId: const Uuid().v4())),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(req),
              ),
            ])),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildList(
      StaffingState state, List<ShiftTemplateEntity> templates) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.requirements.length,
      itemBuilder: (context, index) {
        final req = state.requirements[index];
        final template = _template(templates, req.shiftTemplateId);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
                '${_areaName(state, req.areaId) ?? req.areaId} • ${_dayLabel(l10n, req.dayOfWeek)}'),
            subtitle: Text(
                '${template?.name ?? l10n.notSet}${template == null ? '' : ' (${_windowLabel(template)})'} • ${l10n.requiredCountLabel('${req.requiredCount}')}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      _showRequirementDialog(requirement: req, templates: templates),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _confirmDelete(req),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Human-readable window for a shift template, e.g. "08:00 → 15:00".
  String _windowLabel(ShiftTemplateEntity t) {
    String f(int m) =>
        '${(((m % 1440) + 1440) % 1440 ~/ 60).toString().padLeft(2, '0')}:${(((m % 1440) + 1440) % 1440 % 60).toString().padLeft(2, '0')}';
    return '${f(t.startMinute)} → ${f(t.startMinute + t.durationMinutes)}';
  }

  void _confirmDelete(StaffingRequirementEntity req) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRequirementTitle),
        content: Text(l10n.deleteRequirementBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(staffingViewModelProvider.notifier)
                  .deleteRequirement(req.requirementId);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showRequirementDialog({
    StaffingRequirementEntity? requirement,
    required List<ShiftTemplateEntity> templates,
  }) {
    final state = ref.read(staffingViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    String? areaId = requirement?.areaId.isNotEmpty == true
        ? requirement!.areaId
        : (state.areas.isNotEmpty ? state.areas.first.areaId : null);

    // 0 = every day.
    int dayOfWeek = requirement?.dayOfWeek ?? 0;
    String? shiftTemplateId = requirement?.shiftTemplateId.isNotEmpty == true
        ? requirement!.shiftTemplateId
        : (templates.isNotEmpty ? templates.first.templateId : null);
    final countController = TextEditingController(
        text: requirement?.requiredCount.toString() ?? '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedTemplate = templates
              .where((t) => t.templateId == shiftTemplateId)
              .firstOrNull;
          return AlertDialog(
            title: Text(requirement == null
                ? l10n.addRequirement
                : l10n.editRequirement),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: areaId,
                      decoration: InputDecoration(labelText: l10n.colArea),
                      items: state.areas
                          .map((a) => DropdownMenuItem(
                              value: a.areaId, child: Text(a.name)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => areaId = v),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: shiftTemplateId,
                      decoration:
                          InputDecoration(labelText: l10n.colShift),
                      items: templates
                          .map((t) => DropdownMenuItem(
                              value: t.templateId,
                              child: Text(
                                  '${t.name} (${_windowLabel(t)})')))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => shiftTemplateId = v),
                    ),
                    const SizedBox(height: 8),
                    if (selectedTemplate != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          '${l10n.colTimeWindow}: ${_windowLabel(selectedTemplate)}'
                          '${selectedTemplate.isNightShift ? ' • ${l10n.overnightShift}' : ''}',
                          style: const TextStyle(fontSize: 12,
                              color: Colors.grey),
                        ),
                      ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: dayOfWeek,
                      decoration:
                          InputDecoration(labelText: l10n.dayOfWeek),
                      items: [
                        DropdownMenuItem(
                            value: 0, child: Text(l10n.everyDay)),
                        ...List.generate(7, (i) {
                          final d = i + 1; // Monday=1 .. Sunday=7
                          return DropdownMenuItem(
                              value: d,
                              child: Text(localizedDayName(l10n, d)));
                        }),
                      ],
                      onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: countController,
                      decoration: InputDecoration(
                          labelText: l10n.requiredEmployees),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () {
                  final selectedAreaId = areaId;
                  final selectedTemplateId = shiftTemplateId;
                  if (selectedAreaId == null ||
                      selectedTemplateId == null ||
                      selectedTemplateId.isEmpty) {
                    return;
                  }
                  final count = int.tryParse(countController.text);
                  if (count == null || count < 0) return;
                  ref.read(staffingViewModelProvider.notifier).saveRequirement(
                        StaffingRequirementEntity(
                          requirementId:
                              requirement?.requirementId ?? const Uuid().v4(),
                          areaId: selectedAreaId,
                          dayOfWeek: dayOfWeek,
                          shiftTemplateId: selectedTemplateId,
                          requiredCount: count,
                          minHoursPerWeek: requirement?.minHoursPerWeek ?? 0,
                        ),
                      );
                  Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
