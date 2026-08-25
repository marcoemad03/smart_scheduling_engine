import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../features/dashboard/presentation/pages/employee_dashboard_page.dart';
import '../features/areas/presentation/pages/area_management_page.dart';
import '../features/staffing/presentation/pages/staffing_requirements_page.dart';
import '../features/settings/presentation/pages/system_settings_page.dart';
import '../features/availability/presentation/pages/availability_page.dart';
import '../features/schedules/presentation/pages/weekly_scheduler_page.dart';
import '../features/schedules/presentation/pages/employee_weekly_schedule_page.dart';
import '../features/shifts/presentation/pages/shift_template_page.dart';
import '../features/leaves/presentation/pages/my_leaves_page.dart';
import '../features/leaves/presentation/pages/admin_leave_requests_page.dart';
import '../features/swaps/presentation/pages/my_swaps_page.dart';
import '../features/swaps/presentation/pages/admin_swap_requests_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/attendance/presentation/pages/my_attendance_page.dart';
import '../features/attendance/presentation/pages/admin_attendance_page.dart';

class AppRoutes {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdminDashboardShell(child: child),
        routes: [
          GoRoute(path: '/admin', name: 'admin', builder: (context, state) => const AdminDashboardPage()),
          GoRoute(path: '/admin/employees', name: 'employees', builder: (context, state) => const Scaffold(body: Center(child: Text('Employees')))),
          GoRoute(path: '/admin/areas', name: 'areas', builder: (context, state) => const AreaManagementPage()),
          GoRoute(path: '/admin/shifts', name: 'shifts', builder: (context, state) => const ShiftTemplatePage()),
          GoRoute(path: '/admin/staffing', name: 'staffing', builder: (context, state) => const StaffingRequirementsPage()),
          GoRoute(path: '/admin/schedules', name: 'schedules', builder: (context, state) => const WeeklySchedulerPage()),
          GoRoute(path: '/admin/leaves', name: 'leaves', builder: (context, state) => const AdminLeaveRequestsPage()),
          GoRoute(path: '/admin/swaps', name: 'swaps', builder: (context, state) => const AdminSwapRequestsPage()),
          GoRoute(path: '/admin/attendance', name: 'attendance', builder: (context, state) => const AdminAttendancePage()),
          GoRoute(path: '/admin/settings', name: 'settings', builder: (context, state) => const SystemSettingsPage()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => EmployeeDashboardShell(child: child),
        routes: [
          GoRoute(path: '/employee', name: 'employee', builder: (context, state) => const EmployeeDashboardPage()),
          GoRoute(path: '/employee/schedule', name: 'my_schedule', builder: (context, state) => const EmployeeWeeklySchedulePage()),
          GoRoute(path: '/employee/availability', name: 'availability', builder: (context, state) => const AvailabilityPage()),
          GoRoute(path: '/employee/leaves', name: 'my_leaves', builder: (context, state) => const MyLeavesPage()),
          GoRoute(path: '/employee/swaps', name: 'my_swaps', builder: (context, state) => const MySwapsPage()),
          GoRoute(path: '/employee/attendance', name: 'my_attendance', builder: (context, state) => const MyAttendancePage()),
          GoRoute(path: '/employee/notifications', name: 'notifications', builder: (context, state) => const NotificationsPage()),
        ],
      ),
    ],
  );
}

class AdminDashboardShell extends StatelessWidget {
  final Widget child;
  const AdminDashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/admin'},
      {'icon': Icons.people_outline, 'label': 'Employees', 'route': '/admin/employees'},
      {'icon': Icons.room_outlined, 'label': 'Areas', 'route': '/admin/areas'},
      {'icon': Icons.schedule_outlined, 'label': 'Shifts', 'route': '/admin/shifts'},
      {'icon': Icons.badge_outlined, 'label': 'Staffing', 'route': '/admin/staffing'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedules', 'route': '/admin/schedules'},
      {'icon': Icons.event_available_outlined, 'label': 'Leaves', 'route': '/admin/leaves'},
      {'icon': Icons.swap_horiz_outlined, 'label': 'Swaps', 'route': '/admin/swaps'},
      {'icon': Icons.check_circle_outline, 'label': 'Attendance', 'route': '/admin/attendance'},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/admin/settings'},
    ];

    int selectedIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if ((items[i]['route'] as String) == GoRouterState.of(context).uri.toString()) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => context.go(items[index]['route'] as String),
            destinations: items.map((item) => NavigationRailDestination(
              icon: Icon(item['icon'] as IconData),
              label: Text(item['label'] as String),
            )).toList(),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class EmployeeDashboardShell extends StatelessWidget {
  final Widget child;
  const EmployeeDashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/employee'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedule', 'route': '/employee/schedule'},
      {'icon': Icons.access_time_outlined, 'label': 'Availability', 'route': '/employee/availability'},
      {'icon': Icons.event_available_outlined, 'label': 'Leaves', 'route': '/employee/leaves'},
      {'icon': Icons.swap_horiz_outlined, 'label': 'Swaps', 'route': '/employee/swaps'},
      {'icon': Icons.fact_check_outlined, 'label': 'Attendance', 'route': '/employee/attendance'},
    ];

    int selectedIndex = 0;
    for (int i = 0; i < items.length; i++) {
      if ((items[i]['route'] as String) == GoRouterState.of(context).uri.toString()) {
        selectedIndex = i;
        break;
      }
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => context.go(items[index]['route'] as String),
            destinations: items.map((item) => NavigationRailDestination(
              icon: Icon(item['icon'] as IconData),
              label: Text(item['label'] as String),
            )).toList(),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}