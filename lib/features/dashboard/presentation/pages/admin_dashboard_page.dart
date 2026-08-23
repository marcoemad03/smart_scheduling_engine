import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            const SizedBox(height: 32),
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