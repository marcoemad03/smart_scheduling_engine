import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = ref.read(schedulerViewModelProvider.notifier);
      if (ref.read(schedulerViewModelProvider).weekCoverage == null) {
        vm.loadWeek(DateTimeUtils.getStartOfWeek(DateTime.now()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(schedulerViewModelProvider);
    final coverage = state.weekCoverage;

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, Administrator',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your reception workforce',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            _buildCoverageOverview(context, state.isLoading, coverage),
            const SizedBox(height: 32),
            Text(
              'Quick Actions',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildQuickActionCard(context, Icons.people_outline, 'Employees', '/admin/employees'),
                _buildQuickActionCard(context, Icons.room_outlined, 'Areas', '/admin/areas'),
                _buildQuickActionCard(context, Icons.schedule_outlined, 'Shifts', '/admin/shifts'),
                _buildQuickActionCard(context, Icons.badge_outlined, 'Staffing', '/admin/staffing'),
                _buildQuickActionCard(context, Icons.calendar_today_outlined, 'Schedules', '/admin/schedules'),
                _buildQuickActionCard(context, Icons.event_available_outlined, 'Leave Requests', '/admin/leaves'),
                _buildQuickActionCard(context, Icons.swap_horiz_outlined, 'Swap Requests', '/admin/swaps'),
                _buildQuickActionCard(context, Icons.check_circle_outline, 'Attendance', '/admin/attendance'),
                _buildQuickActionCard(context, Icons.settings_outlined, 'Settings', '/admin/settings'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverageOverview(
      BuildContext context, bool isLoading, WeekCoverageResult? coverage) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights),
                const SizedBox(width: 8),
                Text('This Week\'s Coverage',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading || coverage == null)
              const Center(child: CircularProgressIndicator())
            else ...[
              _WeeklySummaryCard(coverage: coverage),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    coverage.days.map((d) => _DayCoverageCard(day: d)).toList(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                _legendDot(Colors.green),
                const Text(' Fully covered   '),
                _legendDot(Colors.orange),
                const Text(' Overstaffed   '),
                _legendDot(Colors.red),
                const Text(' Understaffed'),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildQuickActionCard(BuildContext context, IconData icon, String label, String route) {
    return SizedBox(
      width: 200,
      child: Card(
        child: InkWell(
          onTap: () => context.go(route),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color statusColor(CoverageStatus status) {
  switch (status) {
    case CoverageStatus.fullyCovered:
      return Colors.green;
    case CoverageStatus.overstaffed:
      return Colors.orange;
    case CoverageStatus.understaffed:
      return Colors.red;
  }
}

String statusLabel(CoverageStatus status) {
  switch (status) {
    case CoverageStatus.fullyCovered:
      return 'FULLY COVERED';
    case CoverageStatus.overstaffed:
      return 'OVERSTAFFED';
    case CoverageStatus.understaffed:
      return 'UNDERSTAFFED';
  }
}

class _WeeklySummaryCard extends StatelessWidget {
  final WeekCoverageResult coverage;
  const _WeeklySummaryCard({required this.coverage});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(coverage.status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Wrap(
        spacing: 32,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Required'),
            Text('${coverage.totalRequired}',
                style: Theme.of(context).textTheme.headlineSmall),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Scheduled'),
            Text('${coverage.totalScheduled}',
                style: Theme.of(context).textTheme.headlineSmall),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Missing'),
            Text('${coverage.totalMissing}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.red)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Extra'),
            Text('${coverage.totalExtra}',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: Colors.orange)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Coverage'),
            Text('${coverage.coveragePercentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.headlineSmall),
          ]),
          Chip(
            backgroundColor: color,
            label: Text(statusLabel(coverage.status),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DayCoverageCard extends StatelessWidget {
  final DayCoverageResult day;
  const _DayCoverageCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(day.status);
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEE').format(day.date),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(DateFormat('MMM d').format(day.date),
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: day.coveragePercentage / 100,
              backgroundColor: Colors.grey.shade300,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              '${day.totalScheduled}/${day.totalRequired} • ${day.coveragePercentage.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11),
            ),
            if (day.hasRequirements)
              Text(
                statusLabel(day.status),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color),
              )
            else
              const Text('No requirements',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
