import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';

class AreaManagementPage extends ConsumerWidget {
  const AreaManagementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(areaListViewModelProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Areas Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAreaDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: areasAsync.when(
        data: (areas) => areas.isEmpty
            ? _emptyState(context)
            : _buildAreaList(context, ref, areas),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.room_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No areas defined yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Add your first reception area', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildAreaList(BuildContext context, WidgetRef ref, List<ReceptionArea> areas) {
    return ListView.builder(
      itemCount: areas.length,
      itemBuilder: (context, index) {
        final area = areas[index];
        return Dismissible(
          key: Key(area.areaId),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => _confirmDelete(context, ref, area),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: area.isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(area.name.substring(0, 1)),
            ),
            title: Text(area.name),
            subtitle: Text(area.description.isEmpty ? 'No description' : area.description),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: area.isActive,
                  onChanged: (value) => _toggleActive(ref, area, value),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showAreaDialog(context, ref, area),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleActive(WidgetRef ref, ReceptionArea area, bool value) {
    final updated = ReceptionArea(
      areaId: area.areaId,
      name: area.name,
      description: area.description,
      orderIndex: area.orderIndex,
      isActive: value,
    );
    ref.read(areaActionsProvider).updateArea(updated);
  }

  void _showAreaDialog(BuildContext context, WidgetRef ref, ReceptionArea? area) {
    final nameController = TextEditingController(text: area?.name ?? '');
    final descController = TextEditingController(text: area?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(area == null ? 'Add Area' : 'Edit Area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newArea = ReceptionArea(
                areaId: area?.areaId ?? const Uuid().v4(),
                name: nameController.text.trim(),
                description: descController.text.trim(),
                orderIndex: area?.orderIndex ?? 0,
                isActive: area?.isActive ?? true,
              );

              if (nameController.text.trim().isNotEmpty) {
                if (area == null) {
                  ref.read(areaActionsProvider).createArea(newArea);
                } else {
                  ref.read(areaActionsProvider).updateArea(newArea);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ReceptionArea area) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Area'),
        content: Text('Are you sure you want to delete "${area.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(areaActionsProvider).deleteArea(area.areaId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}