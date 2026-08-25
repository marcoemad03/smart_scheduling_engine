import 'package:flutter/material.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No leave requests.'));
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
                  title: Text('Employee ${r.employeeId.substring(0, 8)}… • '
                      '${DateFormat('MMM d').format(r.startDateTime)} → ${DateFormat('MMM d').format(r.endDateTime)}'),
                  subtitle: Text('${r.type.name} • ${r.notes.isEmpty ? 'no notes' : r.notes}'),
                  trailing: pending
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () {
                              notifier.act(requestId: r.requestId, approve: true);
                              notifications.send(
                                userId: r.employeeId,
                                title: 'Leave approved',
                                body:
                                    'Your ${r.type.name} request starting ${DateFormat('MMM d').format(r.startDateTime)} was approved.',
                                type: 'leave_approved',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () {
                              notifier.act(requestId: r.requestId, approve: false);
                              notifications.send(
                                userId: r.employeeId,
                                title: 'Leave rejected',
                                body:
                                    'Your ${r.type.name} request starting ${DateFormat('MMM d').format(r.startDateTime)} was rejected.',
                                type: 'leave_rejected',
                              );
                            },
                          ),
                        ])
                      : Chip(label: Text(r.status.name)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
