import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/features/leaves/data/leaves_repository.dart';
import 'package:reception_workforce_scheduler/features/leaves/domain/entities/leave_request.dart';
import 'package:reception_workforce_scheduler/features/notifications/presentation/providers/notification_providers.dart';

class AdminLeaveRequestsPage extends ConsumerWidget {
  const AdminLeaveRequestsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminLeavesViewModelProvider);
    final notifier = ref.read(adminLeavesViewModelProvider.notifier);
    final notifications = ref.watch(notificationRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final typeNames = {
      LeaveType.vacation: l10n.vacation,
      LeaveType.sick: l10n.sickLeave,
      LeaveType.personal: l10n.personal,
      LeaveType.other: l10n.leaveTypeOther,
    };
    final statusNames = {
      LeaveStatus.pending: l10n.statusPending,
      LeaveStatus.approved: l10n.statusApproved,
      LeaveStatus.rejected: l10n.statusRejected,
      LeaveStatus.cancelled: l10n.statusCancelled,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaveRequestsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.noLeaveRequests));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              final pending = r.status == LeaveStatus.pending;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text('${l10n.employeeIdLabel(r.employeeId.substring(0, 8))} • '
                      '${DateFormat('MMM d').format(r.startDateTime)} → ${DateFormat('MMM d').format(r.endDateTime)}'),
                  subtitle: Text('${typeNames[r.type] ?? r.type.name} • ${r.notes.isEmpty ? l10n.noNotes : r.notes}'),
                  trailing: pending
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: l10n.approve,
                            onPressed: () {
                              notifier.act(requestId: r.requestId, approve: true);
                              notifications.send(
                                userId: r.employeeId,
                                title: l10n.leaveApprovedTitle,
                                body: l10n.leaveApprovedBody(
                                    typeNames[r.type] ?? r.type.name,
                                    DateFormat('MMM d').format(r.startDateTime)),
                                type: 'leave_approved',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.red),
                            tooltip: l10n.reject,
                            onPressed: () {
                              notifier.act(requestId: r.requestId, approve: false);
                              notifications.send(
                                userId: r.employeeId,
                                title: l10n.leaveRejectedTitle,
                                body: l10n.leaveRejectedBody(
                                    typeNames[r.type] ?? r.type.name,
                                    DateFormat('MMM d').format(r.startDateTime)),
                                type: 'leave_rejected',
                              );
                            },
                          ),
                        ])
                      : Chip(label: Text(statusNames[r.status] ?? r.status.name)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
