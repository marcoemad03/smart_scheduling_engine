import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  final List<AvailabilityBlock> _availabilityBlocks = [
    AvailabilityBlock(
      id: 'block1',
      dayOfWeek: 1, // Monday
      startMinute: 480, // 08:00
      endMinute: 1320, // 22:00
      isAvailable: true,
      isRecurring: true,
    ),
    AvailabilityBlock(
      id: 'block2',
      dayOfWeek: 3,
      startMinute: 0,
      endMinute: 480,
      isAvailable: false,
      isRecurring: true,
      notes: 'Doctor appointment',
    ),
  ];

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Availability'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_outlined),
            onPressed: _showAvailabilityDialog,
          ),
        ],
      ),
      body: isDesktop 
          ? _buildDesktopView() 
          : _buildMobileView(),
    );
  }

  Widget _buildDesktopView() {
    return Column(
      children: [
        _buildWeeklyGrid(),
        Expanded(child: _buildAvailabilityList()),
      ],
    );
  }

  Widget _buildMobileView() {
    return _buildAvailabilityList();
  }

  Widget _buildWeeklyGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 200,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 7,
        itemBuilder: (context, index) {
          final dayIndex = index + 1;
          final dayBlocks = _availabilityBlocks.where((b) => b.dayOfWeek == dayIndex).toList();
          
          return Card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_days[index], style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
                const SizedBox(height: 4),
                ...dayBlocks.take(2).map((block) => Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: block.isAvailable 
                        ? Colors.green.withOpacity(0.3) 
                        : Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_formatMinutes(block.startMinute)}-${_formatMinutes(block.endMinute)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )),
                if (dayBlocks.length > 2)
                  Text('+${dayBlocks.length - 2} more', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailabilityList() {
    if (_availabilityBlocks.isEmpty) {
      return const Center(child: Text('No availability blocks set'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _availabilityBlocks.length,
      itemBuilder: (context, index) {
        final block = _availabilityBlocks[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: block.isAvailable 
                  ? Colors.green.withOpacity(0.3) 
                  : Colors.red.withOpacity(0.3),
              child: Icon(
                block.isAvailable ? Icons.check : Icons.close,
                color: block.isAvailable ? Colors.green : Colors.red,
              ),
            ),
            title: Text('${_days[block.dayOfWeek - 1]} • ${_formatMinutes(block.startMinute)} - ${_formatMinutes(block.endMinute)}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(block.isRecurring ? 'Recurring' : 'One-time'),
                if (block.notes != null && block.notes!.isNotEmpty)
                  Text(block.notes!),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showAvailabilityDialog(block: block),
            ),
          ),
        );
      },
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final min = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  void _showAvailabilityDialog({AvailabilityBlock? block}) {
    final startController = TextEditingController(
      text: block != null ? _formatMinutes(block.startMinute) : '08:00',
    );
    final endController = TextEditingController(
      text: block != null ? _formatMinutes(block.endMinute) : '22:00',
    );
    final notesController = TextEditingController(text: block?.notes ?? '');
    
    String selectedDay = (block?.dayOfWeek ?? 1).toString();
    bool isAvailable = block?.isAvailable ?? true;
    bool isRecurring = block?.isRecurring ?? true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(block == null ? 'Add Availability' : 'Edit Availability'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedDay,
                  items: _days.asMap().entries.map((e) => 
                    DropdownMenuItem(value: (e.key + 1).toString(), child: Text(e.value))
                  ).toList(),
                  onChanged: (val) => setState(() => selectedDay = val!),
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: startController,
                  decoration: const InputDecoration(
                    labelText: 'Start Time',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.access_time_outlined),
                  ),
                  readOnly: true,
                  onTap: () => _selectTime(context, startController),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: endController,
                  decoration: const InputDecoration(
                    labelText: 'End Time',
                    border: OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.access_time_outlined),
                  ),
                  readOnly: true,
                  onTap: () => _selectTime(context, endController),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Available'),
                  value: isAvailable,
                  onChanged: (val) => setState(() => isAvailable = val),
                ),
                SwitchListTile(
                  title: const Text('Recurring'),
                  value: isRecurring,
                  onChanged: (val) => setState(() => isRecurring = val),
                ),
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final newBlock = AvailabilityBlock(
                id: block?.id ?? UuidGenerator().generate(),
                dayOfWeek: int.parse(selectedDay),
                startMinute: _parseTimeToMinutes(startController.text),
                endMinute: _parseTimeToMinutes(endController.text),
                isAvailable: isAvailable,
                isRecurring: isRecurring,
                notes: notesController.text.trim(),
              );
              
              setState(() {
                if (block == null) {
                  _availabilityBlocks.add(newBlock);
                } else {
                  _availabilityBlocks[_availabilityBlocks.indexOf(block)] = newBlock;
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

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final parts = controller.text.split(':');
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (result != null) {
      setState(() {
        controller.text = '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class AvailabilityBlock {
  final String id;
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final int startMinute;
  final int endMinute;
  final bool isAvailable;
  final bool isRecurring;
  final String? notes;

  AvailabilityBlock({
    required this.id,
    required this.dayOfWeek,
    required this.startMinute,
    required this.endMinute,
    required this.isAvailable,
    required this.isRecurring,
    this.notes,
  });
}

class UuidGenerator {
  String generate() => DateTime.now().millisecondsSinceEpoch.toString();
}

