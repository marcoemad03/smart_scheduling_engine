import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.swapShift)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.swap_horiz),
        label: Text(l10n.requestSwap),
        onPressed: () async {
          final week = weekAsync.asData?.value;
          if (week == null) return;
          final myShifts = week
              .myAssignments(employeeId)
              .where((a) => a.startDateTime.isAfter(DateTime.now()))
              .toList()
            ..sort((a, b) => a.startDateTime.compareTo(b.startDateTime));
          if (myShifts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(l10n.noUpcomingShiftsSwap)));
            return;
          }
          _showSwapDialog(context, ref, myShifts);
        },
      ),
      body: swapsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.noSwapRequestsYet));
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
                  title: Text(l10n.shiftOn(
                      DateFormat('EEE, MMM d • HH:mm').format(r.preferredDatetime))),
                  subtitle: Text(r.notes.isEmpty
                      ? l10n.requestedOn(DateFormat('MMM d').format(r.createdAt))
                      : r.notes),
                  trailing: _statusChip(context, r.status),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _statusChip(BuildContext context, SwapStatus status) {
    final l10n = AppLocalizations.of(context)!;
    final color = switch (status) {
      SwapStatus.approved => Colors.green,
      SwapStatus.rejected => Colors.red,
      SwapStatus.cancelled => Colors.grey,
      SwapStatus.pending => Colors.orange,
    };
    final label = switch (status) {
      SwapStatus.approved => l10n.statusApproved,
      SwapStatus.rejected => l10n.statusRejected,
      SwapStatus.cancelled => l10n.statusCancelled,
      SwapStatus.pending => l10n.statusPending,
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showSwapDialog(BuildContext context, WidgetRef ref, List myShifts) {
    final l10n = AppLocalizations.of(context)!;
    dynamic selected = myShifts.first;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.requestShiftSwap),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l10n.selectYourShift)),
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
              decoration: InputDecoration(
                  labelText: l10n.reasonColleague),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.swapApprovalNote,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () {
              ref.read(mySwapsViewModelProvider.notifier).submit(
                    assignmentId: selected.id,
                    shiftStart: selected.startDateTime,
                    notes: notesController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: Text(l10n.submit),
          ),
        ],
      ),
    );
  }
}
