import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  static GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final authStateAsync = ProviderContainer().read(authStateProvider);
      final loggedIn = authStateAsync.asData?.value != null;
      final loggingIn = state.matchedRoute == 'login';

      if (!loggedIn && !loggingIn) return '/login';

      if (loggedIn) {
        final roleAsync = ProviderContainer().read(userRoleProvider);
        final role = roleAsync.asData?.value;
        
        if (role == UserRole.admin && state.matchedRoute.startsWith('/employee')) {
          return '/admin';
        }
        if (role == UserRole.employee && !state.matchedRoute.startsWith('/employee')) {
          return '/employee';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      // Admin routes
      ShellRoute(
        builder: (context, state, child) => AdminDashboardShell(child: child),
        routes: [
          GoRoute(path: '/admin', name: 'admin', builder: (context, state) => const AdminDashboardPage()),
          GoRoute(path: '/admin/employees', name: 'employees', builder: (context, state) => const EmployeeListPage()),
          GoRoute(path: '/admin/areas', name: 'areas', builder: (context, state) => const AreaManagementPage()),
          GoRoute(path: '/admin/shifts', name: 'shifts', builder: (context, state) => const ShiftTemplatePage()),
          GoRoute(path: '/admin/staffing', name: 'staffing', builder: (context, state) => const StaffingRequirementsPage()),
          GoRoute(path: '/admin/schedules', name: 'schedules', builder: (context, state) => const ScheduleVersionsPage()),
          GoRoute(path: '/admin/leaves', name: 'leaves', builder: (context, state) => const LeaveApprovalPage()),
          GoRoute(path: '/admin/swaps', name: 'swaps', builder: (context, state) => const SwapApprovalPage()),
          GoRoute(path: '/admin/attendance', name: 'attendance', builder: (context, state) => const AttendanceManagementPage()),
          GoRoute(path: '/admin/settings', name: 'settings', builder: (context, state) => const SystemSettingsPage()),
        ],
      ),
      // Employee routes
      ShellRoute(
        builder: (context, state, child) => EmployeeDashboardShell(child: child),
        routes: [
          GoRoute(path: '/employee', name: 'employee', builder: (context, state) => const EmployeeDashboardPage()),
          GoRoute(path: '/employee/schedule', name: 'my_schedule', builder: (context, state) => const MySchedulePage()),
          GoRoute(path: '/employee/availability', name: 'availability', builder: (context, state) => const AvailabilityPage()),
          GoRoute(path: '/employee/leaves', name: 'my_leaves', builder: (context, state) => const LeaveRequestPage()),
          GoRoute(path: '/employee/swaps', name: 'my_swaps', builder: (context, state) => const SwapRequestPage()),
          GoRoute(path: '/employee/attendance', name: 'my_attendance', builder: (context, state) => const AttendancePage()),
        ],
      ),
    ],
  );
}

class AdminDashboardShell extends StatelessWidget {
  final Widget child;

  const AdminDashboardShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _adminSidebar(context),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _adminSidebar(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/admin'},
      {'icon': Icons.people_outline, 'label': 'Employees', 'route': '/admin/employees'},
      {'icon': Icons.room_outlined, 'label': 'Areas', 'route': '/admin/areas'},
      {'icon': Icons.schedule_outlined, 'label': 'Shifts', 'route': '/admin/shifts'},
      {'icon': Icons.badge_outlined, 'label': 'Staffing', 'route': '/admin/staffing'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedules', 'route': '/admin/schedules'},
      {'icon': Icons.event_available_outlined, 'label': 'Leave Requests', 'route': '/admin/leaves'},
      {'icon': Icons.swap_horiz_outlined, 'label': 'Swap Requests', 'route': '/admin/swaps'},
      {'icon': Icons.check_circle_outline, 'label': 'Attendance', 'route': '/admin/attendance'},
      {'icon': Icons.settings_outlined, 'label': 'Settings', 'route': '/admin/settings'},
    ];

    return NavigationRail(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) {
        context.go(items[index]['route'] as String);
      },
      destinations: items.map((item) => NavigationRailDestination(
        icon: Icon(item['icon'] as IconData),
        label: Text(item['label'] as String),
      )).toList(),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final route = GoRouterState.of(context).subloc;
    final items = [
      '/admin', '/admin/employees', '/admin/areas', '/admin/shifts',
      '/admin/staffing', '/admin/schedules', '/admin/leaves',
      '/admin/swaps', '/admin/attendance', '/admin/settings'
    ];
    return items.indexOf(route.split('?').first);
  }
}

class EmployeeDashboardShell extends StatelessWidget {
  final Widget child;

  const EmployeeDashboardShell({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [_employeeSidebar(context), Expanded(child: child)],
        ),
      );
    } else {
      return Scaffold(
        body: child,
        bottomNavigationBar: _employeeBottomNavBar(context),
      );
    }
  }

  Widget _employeeSidebar(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/employee'},
      {'icon': Icons.calendar_today_outlined, 'label': 'My Schedule', 'route': '/employee/schedule'},
      {'icon': Icons.access_time_outlined, 'label': 'Availability', 'route': '/employee/availability'},
      {'icon': Icons.event_available_outlined, 'label': 'Leave Requests', 'route': '/employee/leaves'},
      {'icon': Icons.swap_horiz_outlined, 'label': 'Swap Requests', 'route': '/employee/swaps'},
      {'icon': Icons.check_circle_outline, 'label': 'Attendance', 'route': '/employee/attendance'},
    ];

    return NavigationRail(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) {
        context.go(items[index]['route'] as String);
      },
      destinations: items.map((item) => NavigationRailDestination(
        icon: Icon(item['icon'] as IconData),
        label: Text(item['label'] as String),
      )).toList(),
    );
  }

  int _getSelectedIndex(BuildContext context) {
    final route = GoRouterState.of(context).subloc;
    final items = [
      '/employee', '/employee/schedule', '/employee/availability',
      '/employee/leaves', '/employee/swaps', '/employee/attendance'
    ];
    return items.indexOf(route.split('?').first);
  }

  Widget _employeeBottomNavBar(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/employee'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedule', 'route': '/employee/schedule'},
      {'icon': Icons.event_available_outlined, 'label': 'Leaves', 'route': '/employee/leaves'},
      {'icon': Icons.swap_horiz_outlined, 'label': 'Swaps', 'route': '/employee/swaps'},
    ];

    return NavigationBar(
      selectedIndex: _getSelectedIndex(context),
      onDestinationSelected: (index) {
        context.go(items[index]['route'] as String);
      },
      destinations: items.map((item) => NavigationDestination(
        icon: Icon(item['icon'] as IconData),
        label: item['label'] as String,
      )).toList(),
    );
  }
}

// Page placeholders
class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Admin Dashboard')));
}

class EmployeeListPage extends StatelessWidget {
  const EmployeeListPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Employees')));
}

class AreaManagementPage extends StatelessWidget {
  const AreaManagementPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Areas')));
}

class ShiftTemplatePage extends StatelessWidget {
  const ShiftTemplatePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Shift Templates')));
}

class StaffingRequirementsPage extends StatelessWidget {
  const StaffingRequirementsPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Staffing Requirements')));
}

class ScheduleVersionsPage extends StatelessWidget {
  const ScheduleVersionsPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Schedule Versions')));
}

class LeaveApprovalPage extends StatelessWidget {
  const LeaveApprovalPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Leave Requests')));
}

class SwapApprovalPage extends StatelessWidget {
  const SwapApprovalPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Swap Requests')));
}

class AttendanceManagementPage extends StatelessWidget {
  const AttendanceManagementPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Attendance')));
}

class SystemSettingsPage extends StatelessWidget {
  const SystemSettingsPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')));
}

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Dashboard')));
}

class MySchedulePage extends StatelessWidget {
  const MySchedulePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('My Schedule')));
}

class AvailabilityPage extends StatelessWidget {
  const AvailabilityPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Availability')));
}

class LeaveRequestPage extends StatelessWidget {
  const LeaveRequestPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Leave Requests')));
}

class SwapRequestPage extends StatelessWidget {
  const SwapRequestPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Swap Requests')));
}

class AttendancePage extends StatelessWidget {
  const AttendancePage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Attendance')));
}