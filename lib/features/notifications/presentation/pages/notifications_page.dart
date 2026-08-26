import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/features/notifications/presentation/providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myNotificationsProvider);
    final repo = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.notificationsTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(AppLocalizations.of(context)!.errorPrefix('$e'))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
                child: Text(AppLocalizations.of(context)!.noNotificationsYet));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final n = list[i];
              return Card(
                color: n.isRead ? null : Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(_iconFor(n.type),
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(n.title,
                      style: TextStyle(
                          fontWeight:
                              n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(
                      '${n.body}\n${DateFormat('MMM d, HH:mm').format(n.createdAt)}'),
                  isThreeLine: true,
                  onTap: () => repo.markRead(n.id),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'schedule_published':
        return Icons.calendar_month;
      case 'leave_approved':
      case 'leave_rejected':
        return Icons.event_busy;
      case 'swap_approved':
      case 'swap_rejected':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }
}
