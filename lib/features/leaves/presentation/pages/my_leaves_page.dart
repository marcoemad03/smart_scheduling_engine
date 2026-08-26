import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/features/leaves/data/leaves_repository.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';

/// Employee page: submit leave / day-off requests and view request history.
class MyLeavesPage extends ConsumerStatefulWidget {
  const MyLeavesPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MyLeavesPage> createState() => _MyLeavesPageState();
}

class _MyLeavesPageState extends ConsumerState<MyLeavesPage> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myLeavesViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newRequest),
        onPressed: () => _showRequestDialog(context, isDayOff: false),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.event_busy),
            label: Text(l10n.requestDayOff),
            onPressed: () => _showRequestDialog(context, isDayOff: true),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
            data: (list) {
              if (list.isEmpty) {
                return Center(child: Text(l10n.noRequestsYet));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final isDayOff = r.notes.startsWith('[Day off]');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(isDayOff
                          ? Icons.beach_access
                          : Icons.event_busy_outlined),
                      title: Text(_title(r)),
                      subtitle: Text(
                          '${DateFormat('MMM d').format(r.startDateTime)} → ${DateFormat('MMM d').format(r.endDateTime)}'
                          '${r.notes.isEmpty ? '' : '\n${r.notes}'}'),
                      isThreeLine: r.notes.isNotEmpty,
                      trailing: _statusChip(r.status),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  String _title(LeaveRequest r) {
    final l10n = AppLocalizations.of(context)!;
    switch (r.type) {
      case LeaveType.vacation:
        return l10n.vacation;
      case LeaveType.sick:
        return l10n.sickLeave;
      case LeaveType.personal:
        return l10n.personal;
      case LeaveType.other:
        return l10n.leaveTypeOther;
    }
  }

  Widget _statusChip(LeaveStatus status) {
    final l10n = AppLocalizations.of(context)!;
    final color = switch (status) {
      LeaveStatus.approved => Colors.green,
      LeaveStatus.rejected => Colors.red,
      LeaveStatus.cancelled => Colors.grey,
      LeaveStatus.pending => Colors.orange,
    };
    final label = switch (status) {
      LeaveStatus.approved => l10n.statusApproved,
      LeaveStatus.rejected => l10n.statusRejected,
      LeaveStatus.cancelled => l10n.statusCancelled,
      LeaveStatus.pending => l10n.statusPending,
    };
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(label,
          style: TextStyle(color: color, fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }

  void _showRequestDialog(BuildContext context, {required bool isDayOff}) {
    final l10n = AppLocalizations.of(context)!;
    var type = LeaveType.personal;
    DateTime start = DateTime.now();
    DateTime end = DateTime.now();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(isDayOff ? l10n.requestDayOffTitle : l10n.requestLeaveTitle),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (!isDayOff)
                DropdownButtonFormField<LeaveType>(
                  value: type,
                  decoration: InputDecoration(labelText: l10n.type),
                  items: LeaveType.values
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(switch (t) {
                            LeaveType.vacation => l10n.vacation,
                            LeaveType.sick => l10n.sickLeave,
                            LeaveType.personal => l10n.personal,
                            LeaveType.other => l10n.leaveTypeOther,
                          })))
                      .toList(),
                  onChanged: (v) => setDialog(() => type = v!),
                )
              else
                Text(l10n.dayOffNote),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: ctx,
                      initialDate: start,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setDialog(() => start = d);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                      labelText: isDayOff ? l10n.day : l10n.from),
                  child: Text(DateFormat('EEE, MMM d, yyyy').format(start)),
                ),
              ),
              if (!isDayOff) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: end.isBefore(start) ? start : end,
                        firstDate: start,
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setDialog(() => end = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(labelText: l10n.to),
                    child: Text(DateFormat('EEE, MMM d, yyyy').format(end)),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration:
                    InputDecoration(labelText: l10n.notesOptional),
                maxLines: 2,
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () {
                final dayStart = DateTime(
                    start.year, start.month, start.day);
                final dayEnd = DateTime(
                    (isDayOff ? start : end).year,
                    (isDayOff ? start : end).month,
                    (isDayOff ? start : end).day,
                    23,
                    59);
                ref.read(myLeavesViewModelProvider.notifier).submit(
                      type: isDayOff ? LeaveType.personal : type,
                      startDateTime: dayStart,
                      endDateTime: dayEnd,
                      notes: notesController.text.trim(),
                      isDayOff: isDayOff,
                    );
                Navigator.pop(ctx);
              },
              child: Text(l10n.submit),
            ),
          ],
        ),
      ),
    );
  }
}
