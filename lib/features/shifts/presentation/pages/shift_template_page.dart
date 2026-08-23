import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_scheduler/core/app_exports.dart';

class ShiftTemplate {
  final String templateId;
  final String name;
  final int startMinute;
  final int durationMinutes;
  final bool isNightShift;
  final int colorValue;
  final bool isActive;

  ShiftTemplate({
    required this.templateId,
    required this.name,
    required this.startMinute,
    required this.durationMinutes,
    required this.isNightShift,
    required this.colorValue,
    this.isActive = true,
  });
}

class ShiftTemplatePage extends ConsumerStatefulWidget {
  const ShiftTemplatePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ShiftTemplatePage> createState() => _ShiftTemplatePageState();
}

class _ShiftTemplatePageState extends ConsumerState<ShiftTemplatePage> {
  final List<ShiftTemplate> _templates = [
    ShiftTemplate(
      templateId: 'day',
      name: 'Day Shift',
      startMinute: 480, // 08:00
      durationMinutes: 420, // 7 hours
      isNightShift: false,
      colorValue: Colors.blue.value,
    ),
    ShiftTemplate(
      templateId: 'evening',
      name: 'Evening Shift',
      startMinute: 900, // 15:00
      durationMinutes: 420, // 7 hours
      isNightShift: false,
      colorValue: Colors.orange.value,
    ),
    ShiftTemplate(
      templateId: 'night',
      name: 'Night Shift',
      startMinute: 1320, // 22:00
      durationMinutes: 600, // 10 hours (until 08:00 next day)
      isNightShift: true,
      colorValue: Colors.purple.value,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shift Templates')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTemplateDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(template.colorValue),
                child: Text('${template.startMinute ~/ 60}:${(template.startMinute % 60).toString().padLeft(2, '0')}'),
              ),
              title: Text(template.name),
              subtitle: Text('${ShiftTemplate.toString()} • Duration: ${template.durationMinutes ~/ 60}h'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: template.isActive,
                    onChanged: (value) => _toggleActive(template, value),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showTemplateDialog(template: template),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _toggleActive(ShiftTemplate template, bool value) {
    setState(() {
      final idx = _templates.indexOf(template);
      _templates[idx] = ShiftTemplate(
        templateId: template.templateId,
        name: template.name,
        startMinute: template.startMinute,
        durationMinutes: template.durationMinutes,
        isNightShift: template.isNightShift,
        colorValue: template.colorValue,
        isActive: value,
      );
    });
  }

  void _showTemplateDialog({ShiftTemplate? template}) {
    final nameController = TextEditingController(text: template?.name ?? '');
    final startController = TextEditingController(
      text: template != null 
          ? '${template.startMinute ~/ 60}:${(template.startMinute % 60).toString().padLeft(2, '0')}'
          : '08:00',
    );
    final durationController = TextEditingController(
      text: template != null ? '${template.durationMinutes ~/ 60}' : '7',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(template == null ? 'Add Shift Template' : 'Edit Shift Template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: startController,
              decoration: const InputDecoration(labelText: 'Start Time (HH:MM)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              decoration: const InputDecoration(labelText: 'Duration (hours)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final parts = startController.text.split(':');
              final startMinute = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              final durationMinutes = int.parse(durationController.text) * 60;
              
              final newTemplate = ShiftTemplate(
                templateId: template?.templateId ?? const Uuid().v4(),
                name: nameController.text.trim(),
                startMinute: startMinute,
                durationMinutes: durationMinutes,
                isNightShift: _isNightShift(startMinute, durationMinutes),
                colorValue: template?.colorValue ?? Colors.blue.value,
                isActive: template?.isActive ?? true,
              );
              
              setState(() {
                if (template == null) {
                  _templates.add(newTemplate);
                } else {
                  _templates[_templates.indexOf(template)] = newTemplate;
                }
              });
              
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _isNightShift(int startMinute, int durationMinutes) {
    final endMinute = startMinute + durationMinutes;
    return endMinute > 1440; // crosses midnight
  }
}