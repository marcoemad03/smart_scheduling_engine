import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/shifts/data/shift_templates_repository.dart';
import 'package:reception_workforce_scheduler/features/shifts/domain/entities/shift_template.dart';

class ShiftTemplatePage extends ConsumerWidget {
  const ShiftTemplatePage({Key? key}) : super(key: key);

  static const _colors = [
    0xFF2196F3, 0xFF4CAF50, 0xFFFF9800, 0xFF9C27B0,
    0xFFF44336, 0xFF00BCD4, 0xFF795548, 0xFF607D8B,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(shiftTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shift Templates')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Shift'),
        onPressed: () => _showDialog(context, ref, null),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const Center(
                child: Text(
                    'No shift templates yet.\nTemplates are shortcuts — schedules always store actual start/end times.',
                    textAlign: TextAlign.center));
          }
          final isDesktop = MediaQuery.of(context).size.width > 768;
          return isDesktop
              ? ListView(padding: const EdgeInsets.all(16), children: [
                  DataTable(columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Start')),
                    DataColumn(label: Text('End')),
                    DataColumn(label: Text('Duration')),
                    DataColumn(label: Text('Overnight')),
                    DataColumn(label: Text('Active')),
                    DataColumn(label: Text('Actions')),
                  ], rows: templates.map((t) {
                    final end = (t.startMinute + t.durationMinutes) % 1440;
                    final overnight = t.startMinute + t.durationMinutes > 1440;
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        CircleAvatar(
                            radius: 8,
                            backgroundColor:
                                Color(t.colorValue)),
                        const SizedBox(width: 8),
                        Text(t.name),
                      ])),
                      DataCell(Text(_fmt(t.startMinute))),
                      DataCell(Text(_fmt(end))),
                      DataCell(Text('${(t.durationMinutes / 60).toStringAsFixed(t.durationMinutes % 60 == 0 ? 0 : 1)}h')),
                      DataCell(Text(overnight ? 'Yes' : 'No')),
                      DataCell(Switch(
                        value: t.isActive,
                        onChanged: (v) => ref
                            .read(shiftTemplatesProvider.notifier)
                            .save(t.copyWith(isActive: v)),
                      )),
                      DataCell(Row(children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _showDialog(context, ref, t),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.red),
                          onPressed: () => _confirmDelete(context, ref, t),
                        ),
                      ])),
                    ]);
                  }).toList())
                ])
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: templates.length,
                  itemBuilder: (context, i) {
                    final t = templates[i];
                    final end = (t.startMinute + t.durationMinutes) % 1440;
                    final overnight = t.startMinute + t.durationMinutes > 1440;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(t.colorValue),
                          child: Icon(
                            overnight
                                ? Icons.nightlight_round
                                : Icons.wb_sunny_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        title: Text(t.name),
                        subtitle: Text(
                            '${_fmt(t.startMinute)} → ${_fmt(end)}${overnight ? ' (+1 day)' : ''} • ${(t.durationMinutes / 60).toStringAsFixed(t.durationMinutes % 60 == 0 ? 0 : 1)}h'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: t.isActive,
                              onChanged: (v) => ref
                                  .read(shiftTemplatesProvider.notifier)
                                  .save(t.copyWith(isActive: v)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _showDialog(context, ref, t),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
        },
      ),
    );
  }

  String _fmt(int minute) {
    final m = ((minute % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      ShiftTemplateEntity t) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete template?'),
        content: Text('"${t.name}" will be removed. Existing schedules are not affected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(shiftTemplatesProvider.notifier).delete(t.templateId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDialog(
      BuildContext context, WidgetRef ref, ShiftTemplateEntity? template) {
    final nameController =
        TextEditingController(text: template?.name ?? '');
    var startMinute = template?.startMinute ?? DateTimeUtils.toMinutes(8, 0);
    var duration = template?.durationMinutes ?? 420;
    var colorValue = template?.colorValue ?? _colors.first;
    var isActive = template?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title:
              Text(template == null ? 'Add Shift Template' : 'Edit Shift Template'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: nameController,
                    decoration:
                        const InputDecoration(labelText: 'Template Name *'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final init = DateTimeUtils.fromMinutes(startMinute);
                          final t = await showTimePicker(
                              context: ctx2,
                              initialTime: TimeOfDay(
                                  hour: init['hours']!,
                                  minute: init['minutes']!));
                          if (t != null) {
                            setDialog(() => startMinute =
                                DateTimeUtils.toMinutes(t.hour, t.minute));
                          }
                        },
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Start Time'),
                          child: Text(_fmt(startMinute)),
                        ),
                      ),
                    ),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('+')),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: duration,
                        decoration: const InputDecoration(
                            labelText: 'Duration (hours)'),
                        items: [4, 6, 7, 8, 10, 12, 16]
                            .map((h) => DropdownMenuItem(
                                value: h * 60, child: Text('${h}h')))
                            .toList(),
                        onChanged: (v) => setDialog(() => duration = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ends at ${_fmt(startMinute + duration)}'
                      '${startMinute + duration >= 1440 ? ' (next day)' : ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  if (startMinute + duration > 1440)
                    const ListTile(
                      dense: true,
                      leading: Icon(Icons.nightlight_round, size: 16),
                      title: Text('Overnight shift',
                          style: TextStyle(fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Color',
                          style: TextStyle(fontSize: 12))),
                  Wrap(
                    spacing: 6,
                    children: _colors.map((c) {
                      return GestureDetector(
                        onTap: () => setDialog(() => colorValue = c),
                        child: CircleAvatar(
                          radius: sel(colorValue, c) ? 14 : 11,
                          backgroundColor: Color(c),
                          child: sel(colorValue, c)
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  SwitchListTile(
                    title: const Text('Active'),
                    value: isActive,
                    onChanged: (v) => setDialog(() => isActive = v),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                ref.read(shiftTemplatesProvider.notifier).save(
                      ShiftTemplateEntity(
                        templateId:
                            template?.templateId ?? DateFormat('yyyyMMddHHmmss').format(DateTime.now()),
                        name: nameController.text.trim(),
                        startMinute: startMinute,
                        durationMinutes: duration,
                        isNightShift: startMinute + duration > 1440 ||
                            startMinute >= 1260,
                        colorValue: colorValue,
                        isActive: isActive,
                        createdAt:
                            template?.createdAt ?? DateTime.now(),
                        updatedAt: DateTime.now(),
                      ),
                    );
                Navigator.pop(ctx2);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  bool sel(int a, int b) => a == b;
}
