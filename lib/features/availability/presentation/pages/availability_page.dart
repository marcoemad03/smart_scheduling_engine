import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/availability/domain/entities/availability_block.dart';

class AvailabilityPage extends ConsumerStatefulWidget {
  const AvailabilityPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AvailabilityPage> createState() => _AvailabilityPageState();
}

class _AvailabilityPageState extends ConsumerState<AvailabilityPage> {
  Stream<List<AvailabilityBlock>>? _myBlocks;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _myBlocks = ref
        .read(firebaseFirestoreProvider)
        .collection('availability')
        .where('employeeId', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => _fromDoc(d.id, d.data())).toList());
  }

  AvailabilityBlock _fromDoc(String id, Map<String, dynamic> d) {
    return AvailabilityBlock(
      availabilityId: d['availabilityId'] as String? ?? id,
      employeeId: d['employeeId'] as String? ?? '',
      startDateTime: (d['startDateTime'] as Timestamp).toDate(),
      endDateTime: (d['endDateTime'] as Timestamp).toDate(),
      isAvailable: d['isAvailable'] as bool? ?? true,
      isRecurring: d['isRecurring'] as bool? ?? false,
      recurrenceDays:
          (d['recurrenceDays'] as List?)?.cast<int>() ?? const [],
      createdAt: DateTime.now(),
    );
  }

  Future<void> _submit({
    required bool isAvailable,
    required DateTime start,
    required DateTime end,
    bool recurring = false,
    List<int> recurrenceDays = const [],
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await ref.read(firebaseFirestoreProvider).collection('availability').add({
      'availabilityId': const Uuid().v4(),
      'employeeId': uid,
      'startDateTime': Timestamp.fromDate(start),
      'endDateTime': Timestamp.fromDate(end),
      'isAvailable': isAvailable,
      'isRecurring': recurring,
      'recurrenceDays': recurrenceDays,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> _delete(String id) async {
    await ref
        .read(firebaseFirestoreProvider)
        .collection('availability')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Availability')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => _showDialog(context, defaultAvailable: true),
      ),
      body: StreamBuilder<List<AvailabilityBlock>>(
        stream: _myBlocks,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocks = snapshot.data!
            ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (blocks.isEmpty) {
            return const Center(
                child:
                    Text('No availability entries. Add when you are unavailable or available.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: blocks.length,
            itemBuilder: (context, i) {
              final b = blocks[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(
                    b.isAvailable ? Icons.check_circle : Icons.block,
                    color: b.isAvailable ? Colors.green : Colors.red,
                  ),
                  title: Text(
                      '${DateFormat('EEE, MMM d • HH:mm').format(b.startDateTime)} → ${DateFormat('HH:mm').format(b.endDateTime)}'),
                  subtitle: Text(b.isAvailable
                      ? 'Available'
                      : 'Unavailable${b.isRecurring ? ' (recurring)' : ''}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(b.availabilityId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDialog(BuildContext context, {required bool defaultAvailable}) {
    var isAvailable = defaultAvailable;
    var recurring = false;
    var start = DateTime.now();
    var end = DateTime.now().add(const Duration(hours: 4));
    final days = <int>{};

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialog) => AlertDialog(
          title: const Text('Set Availability'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Available')),
                    ButtonSegment(value: false, label: Text('Unavailable')),
                  ],
                  selected: {isAvailable},
                  onSelectionChanged: (s) =>
                      setDialog(() => isAvailable = s.first),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx2,
                        initialDate: start,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d != null) {
                      setDialog(() => start =
                          DateTime(d.year, d.month, d.day, start.hour, start.minute));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('EEE, MMM d, yyyy').format(start)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx2,
                          initialTime:
                              TimeOfDay.fromDateTime(start));
                      if (t != null) {
                        setDialog(() => start = DateTime(start.year,
                            start.month, start.day, t.hour, t.minute));
                      }
                    },
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'From'),
                      child: Text(DateFormat('HH:mm').format(start)),
                    ),
                  )),
                  const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8), child: Text('→')),
                  Expanded(
                      child: InkWell(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx2,
                          initialTime:
                              TimeOfDay.fromDateTime(end));
                      if (t != null) {
                        setDialog(() => end = DateTime(start.year,
                            start.month, start.day, t.hour, t.minute));
                        if (!end.isAfter(start)) {
                          end = end.add(const Duration(days: 1));
                        }
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'To'),
                      child: Text(DateFormat('HH:mm').format(end)),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: recurring,
                  title: const Text('Repeat weekly on:',
                      style: TextStyle(fontSize: 13)),
                  onChanged: (v) => setDialog(() => recurring = v ?? false),
                ),
                if (recurring)
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final label =
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i];
                      return FilterChip(
                        label: Text(label, style: const TextStyle(fontSize: 11)),
                        selected: days.contains(day),
                        onSelected: (sel) => setDialog(() {
                          sel ? days.add(day) : days.remove(day);
                        }),
                      );
                    }),
                  ),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx2),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                _submit(
                  isAvailable: isAvailable,
                  start: start,
                  end: end.isAfter(start)
                      ? end
                      : end.add(const Duration(days: 1)),
                  recurring: recurring,
                  recurrenceDays: days.toList()..sort(),
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
}
