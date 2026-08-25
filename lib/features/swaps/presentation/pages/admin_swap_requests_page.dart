import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/features/notifications/presentation/providers/notification_providers.dart';
import 'package:reception_workforce_scheduler/features/swaps/data/swaps_repository.dart';
import 'package:reception_workforce_scheduler/features/swaps/domain/entities/swap_request.dart';

class AdminSwapRequestsPage extends ConsumerWidget {
  const AdminSwapRequestsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminSwapsViewModelProvider);
    final notifier = ref.read(adminSwapsViewModelProvider.notifier);
    final notifications = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Swap Requests')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No swap requests.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              final pending = r.status == SwapStatus.pending;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz_outlined),
                  title: Text(
                      'Employee ${r.requestingEmployeeId.substring(0, 8)}… • shift ${DateFormat('EEE, MMM d • HH:mm').format(r.preferredDatetime)}'),
                  subtitle: Text(r.notes.isEmpty
                      ? 'No notes'
                      : r.notes),
                  trailing: pending
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: 'Approve',
                            onPressed: () {
                              notifier.act(swapId: r.swapId, approve: true);
                              notifications.send(
                                userId: r.requestingEmployeeId,
                                title: 'Swap approved',
                                body:
                                    'Your shift swap for ${DateFormat('MMM d').format(r.preferredDatetime)} was approved.',
                                type: 'swap_approved',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: 'Reject',
                            onPressed: () {
                              notifier.act(swapId: r.swapId, approve: false);
                              notifications.send(
                                userId: r.requestingEmployeeId,
                                title: 'Swap rejected',
                                body:
                                    'Your shift swap for ${DateFormat('MMM d').format(r.preferredDatetime)} was rejected.',
                                type: 'swap_rejected',
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
