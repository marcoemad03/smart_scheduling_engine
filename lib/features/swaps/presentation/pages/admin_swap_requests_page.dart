import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final statusNames = {
      SwapStatus.pending: l10n.statusPending,
      SwapStatus.approved: l10n.statusApproved,
      SwapStatus.rejected: l10n.statusRejected,
      SwapStatus.cancelled: l10n.statusCancelled,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.swapRequestsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.noSwapRequests));
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
                  title: Text(l10n.employeeShiftLabel(
                      r.requestingEmployeeId.substring(0, 8),
                      DateFormat('EEE, MMM d • HH:mm').format(r.preferredDatetime))),
                  subtitle: Text(r.notes.isEmpty ? l10n.noNotes : r.notes),
                  trailing: pending
                      ? Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            tooltip: l10n.approve,
                            onPressed: () {
                              notifier.act(swapId: r.swapId, approve: true);
                              notifications.send(
                                userId: r.requestingEmployeeId,
                                title: l10n.swapApprovedTitle,
                                body: l10n.swapApprovedBody(
                                    DateFormat('MMM d').format(r.preferredDatetime)),
                                type: 'swap_approved',
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            tooltip: l10n.reject,
                            onPressed: () {
                              notifier.act(swapId: r.swapId, approve: false);
                              notifications.send(
                                userId: r.requestingEmployeeId,
                                title: l10n.swapRejectedTitle,
                                body: l10n.swapRejectedBody(
                                    DateFormat('MMM d').format(r.preferredDatetime)),
                                type: 'swap_rejected',
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
