import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/swaps/data/swaps_repository.dart';
import 'package:reception_workforce_scheduler/features/swaps/domain/entities/swap_request.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/employee_schedule_providers.dart';

/// Employee page: request a shift swap for one of MY published shifts and
/// view swap request history.
class MySwapsPage extends ConsumerWidget {
  const MySwapsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(currentEmployeeIdProvider);
    final swapsAsync = ref.watch(mySwapsViewModelProvider);
    final weekAsync =
        ref.watch(myWeekProvider(DateTimeUtils.getStartOfWeek(DateTime.now())));

    return Scaffold(
      appBar: AppBar(title: const Text('Swap Shift')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Request Swap'),
        onPressed: () async {
          final week = weekAsync.asData?.value;
          if (week == null) return;
          final myShifts = week
              .myAssignments(employeeId)
              .where((a) => a.startDateTime.isAfter(DateTime.now()))
              .toList()
            ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (myShifts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('You have no upcoming shifts to swap.')));
            return;
          }
          _showSwapDialog(context, ref, myShifts);
        },
      ),
      body: swapsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No swap requests yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_outlined),
                  title: Text(
                      'Shift on ${DateFormat('EEE, MMM d • HH:mm').format(r.preferredDatetime)}'),
                  subtitle: Text(r.notes.isEmpty
                      ? 'Requested ${DateFormat('MMM d').format(r.createdAt)}'
                      : r.notes),
                  trailing: _statusChip(r.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(SwapStatus status) {
    final color = switch (status) {
      SwapStatus.approved => Colors.green,
      SwapStatus.rejected => Colors.red,
      SwapStatus.cancelled => Colors.grey,
      SwapStatus.pending => Colors.orange,
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(status.name,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showSwapDialog(BuildContext context, WidgetRef ref, List myShifts) {
    dynamic selected = myShifts.first;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Shift Swap'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Select your shift:')),
            StatefulBuilder(
              builder: (ctx2, setDialog) =>
                  DropdownButton<dynamic>(
                value: selected,
                isExpanded: true,
                items: myShifts
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(DateFormat('EEE, MMM d • HH:mm')
                              .format(s.startDateTime)),
                        ))
                    .toList(),
                onChanged: (v) => setDialog(() => selected = v),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                  labelText: 'Reason / preferred colleague (optional)'),
            ),
            const SizedBox(height: 8),
            const Text(
              'The swap takes effect only after admin approval.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              ref.read(mySwapsViewModelProvider.notifier).submit(
                    assignmentId: selected.id,
                    shiftStart: selected.startDateTime,
                    notes: notesController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
