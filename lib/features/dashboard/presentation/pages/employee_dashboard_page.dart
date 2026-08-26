import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/dashboard/presentation/widgets/today_shift_card.dart';
import 'package:reception_workforce_scheduler/features/notifications/presentation/providers/notification_providers.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/employee_shift_status.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/employee_schedule_providers.dart';

class EmployeeDashboardPage extends ConsumerWidget {
  const EmployeeDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(currentEmployeeIdProvider);
    final weekAsync =
        ref.watch(myWeekProvider(DateTimeUtils.getStartOfWeek(DateTime.now())));
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myDashboardTitle),
        actions: [
          Stack(alignment: Alignment.center, children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => context.go('/employee/notifications'),
            ),
            if (unread > 0)
              PositionedDirectional(
                top: 8,
                end: 8,
                child: Badge(label: Text('$unread')),
              ),
          ]),
        ],
      ),
      body: weekAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text(AppLocalizations.of(context)!.errorPrefix('$e'))),
        data: (week) {
          final l10n = AppLocalizations.of(context)!;
          final myShifts = week.myAssignments(employeeId);
          final status = EmployeeShiftStatus.compute(
            now: DateTime.now(),
            assignments: myShifts,
          );
          final nothingPublished = week.publishedSchedule == null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.welcomeBack,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                if (nothingPublished) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        const Icon(Icons.info_outline),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.noPublishedWeek)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SecondTicker(
                  builder: (context) {
                    final live = EmployeeShiftStatus.compute(
                      now: DateTime.now(),
                      assignments: myShifts,
                    );
                    return TodayShiftCard(
                      status: live,
                      areaName: live.currentShift != null
                          ? week.areaNames[live.currentShift!.areaId]
                          : null,
                    );
                  },
                ),
                const SizedBox(height: 16),
                NextShiftCard(next: status.nextShift, areaNames: week.areaNames),
                const SizedBox(height: 24),
                Text(l10n.quickActions,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _quickActions(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isDesktop ? 1.6 : 1.5,
      children: [
        _actionCard(context, Icons.calendar_today_outlined, l10n.mySchedule,
            '/employee/schedule'),
        _actionCard(context, Icons.access_time_outlined, l10n.setAvailability,
            '/employee/availability'),
        _actionCard(context, Icons.event_busy_outlined, l10n.leaveDayOff,
            '/employee/leaves'),
        _actionCard(
            context, Icons.swap_horiz_outlined, l10n.swapShift, '/employee/swaps'),
        _actionCard(context, Icons.fact_check_outlined, l10n.myAttendance,
            '/employee/attendance'),
      ],
    );
  }

  Widget _actionCard(
      BuildContext context, IconData icon, String label, String route) {
    return Card(
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(label,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
