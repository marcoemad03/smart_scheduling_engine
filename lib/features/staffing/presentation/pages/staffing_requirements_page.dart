import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
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
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.staffingTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.areas.isEmpty ? null : () => _showRequirementDialog(),
        label: Text(l10n.addRequirement),
        icon: const Icon(Icons.add),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(l10n.errorPrefix(state.error!)))
              : state.requirements.isEmpty
                  ? Center(
                      child: Text(l10n.noRequirements))
                  : isDesktop
                      ? _buildTable(state)
                      : _buildList(state),
    );
  }

  String? _areaName(StaffingState state, String areaId) {
    return state.areas
        .where((a) => a.areaId == areaId)
        .map((a) => a.name)
        .firstOrNull;
  }

  Widget _buildTable(StaffingState state) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.colArea)),
          DataColumn(label: Text(l10n.colDay)),
          DataColumn(label: Text(l10n.colTimeWindow)),
          DataColumn(label: Text(l10n.colRequired)),
          DataColumn(label: Text(l10n.colActions)),
        ],
        rows: state.requirements.map((req) {
          final dayName = localizedDayName(l10n, req.dayOfWeek);
          return DataRow(cells: [
            DataCell(Text(_areaName(state, req.areaId) ?? req.areaId)),
            DataCell(Text(dayName)),
            DataCell(Text(req.windowLabel)),
            DataCell(Text('${req.requiredCount}')),
            DataCell(Row(children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showRequirementDialog(requirement: req),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined),
                tooltip: l10n.duplicate,
                onPressed: () => ref
                    .read(staffingViewModelProvider.notifier)
                    .saveRequirement(req.copyWith(requirementId: const Uuid().v4())),
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

  Widget _buildList(StaffingState state) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.requirements.length,
      itemBuilder: (context, index) {
        final req = state.requirements[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
                '${_areaName(state, req.areaId) ?? req.areaId} - ${localizedDayName(AppLocalizations.of(context)!, req.dayOfWeek)}'),
            subtitle: Text(
                '${req.windowLabel} • ${AppLocalizations.of(context)!.requiredCountLabel('${req.requiredCount}')}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showRequirementDialog(requirement: req),
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

  void _showRequirementDialog({StaffingRequirementEntity? requirement}) {
    final state = ref.read(staffingViewModelProvider);
    final l10n = AppLocalizations.of(context)!;
    String? areaId =
        requirement?.areaId ?? (state.areas.isNotEmpty ? state.areas.first.areaId : null);
    int dayOfWeek = requirement?.dayOfWeek ?? 1;
    int startMinute = requirement?.startMinute ?? DateTimeUtils.toMinutes(8, 0);
    int endMinute = requirement?.endMinute ?? DateTimeUtils.toMinutes(15, 0);
    final countController = TextEditingController(
        text: requirement?.requiredCount.toString() ?? '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                  DropdownButtonFormField<int>(
                    value: dayOfWeek,
                    decoration:
                        InputDecoration(labelText: l10n.dayOfWeek),
                    items: List.generate(7, (i) {
                      final d = i + 1; // Monday=1 .. Sunday=7
                      return DropdownMenuItem(
                          value: d, child: Text(localizedDayName(l10n, d)));
                    }),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v!),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final initial = DateTimeUtils.fromMinutes(startMinute);
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                                hour: initial['hours']!,
                                minute: initial['minutes']!),
                          );
                          if (t != null) {
                            setDialogState(() =>
                                startMinute = DateTimeUtils.toMinutes(t.hour, t.minute));
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              InputDecoration(labelText: l10n.windowStart),
                          child: Text(_formatMinute(startMinute)),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('→'),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final initial = DateTimeUtils.fromMinutes(endMinute);
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: TimeOfDay(
                                hour: initial['hours']!,
                                minute: initial['minutes']!),
                          );
                          if (t != null) {
                            setDialogState(() =>
                                endMinute = DateTimeUtils.toMinutes(t.hour, t.minute));
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              InputDecoration(labelText: l10n.windowEnd),
                          child: Text(_formatMinute(endMinute)),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      l10n.midnightNote,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
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
                if (selectedAreaId == null) return;
                final count = int.tryParse(countController.text);
                if (count == null || count < 0) return;
                ref.read(staffingViewModelProvider.notifier).saveRequirement(
                      StaffingRequirementEntity(
                        requirementId: requirement?.requirementId ?? const Uuid().v4(),
                        areaId: selectedAreaId,
                        dayOfWeek: dayOfWeek,
                        startMinute: startMinute,
                        endMinute: endMinute,
                        requiredCount: count,
                        shiftTemplateId: requirement?.shiftTemplateId,
                        minHoursPerWeek: requirement?.minHoursPerWeek ?? 0,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMinute(int minute) {
    final m = ((minute % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }
}
