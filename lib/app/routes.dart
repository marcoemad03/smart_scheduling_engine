import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import '../features/schedules/presentation/pages/ai_assistant_page.dart';
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
  static final _authNotifier = AuthRoleNotifier();
  static String? _lastPath;

  static final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: _authNotifier,
    redirect: (context, state) {
      final loggedIn = FirebaseAuth.instance.currentUser != null;
      final path = state.uri.path;
      final role = _authNotifier.role;

      if (!loggedIn) {
        return path == '/login' ? null : '/login';
      }
      if (path == '/login') {
        return role == 'employee' ? '/employee' : '/admin';
      }
      // Role-based access: employees can never enter /admin routes.
      if (role == 'employee' && path.startsWith('/admin')) {
        return '/employee';
      }
      // Until the role is loaded, keep the user where they are only if the
      // route matches their eventual role; otherwise park them safely.
      if (role == null && path.startsWith('/admin')) {
        return _lastPath ?? '/login';
      }
      _lastPath = path;
      return null;
    },
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
          GoRoute(path: '/admin/assistant', name: 'assistant', builder: (context, state) => const AiAssistantPage()),
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

/// Tracks the signed-in user's role so the router can guard routes.
class AuthRoleNotifier extends ChangeNotifier {
  String? role;
  bool _disposed = false;
  StreamSubscription? _sub;

  AuthRoleNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (_disposed) return;
      role = null;
      if (user != null) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          role = doc.data()?['role'] as String?;
        } catch (_) {
          role = 'employee'; // fail closed: least privilege
        }
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

class AdminDashboardShell extends ConsumerWidget {
  final Widget child;
  const AdminDashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Map<String, dynamic>> items = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard', 'route': '/admin'},
      {'icon': Icons.people_outline, 'label': 'Employees', 'route': '/admin/employees'},
      {'icon': Icons.room_outlined, 'label': 'Areas', 'route': '/admin/areas'},
      {'icon': Icons.schedule_outlined, 'label': 'Shifts', 'route': '/admin/shifts'},
      {'icon': Icons.badge_outlined, 'label': 'Staffing', 'route': '/admin/staffing'},
      {'icon': Icons.calendar_today_outlined, 'label': 'Schedules', 'route': '/admin/schedules'},
      {'icon': Icons.smart_toy_outlined, 'label': 'AI Assistant', 'route': '/admin/assistant'},
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
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _LogoutButton(ref: ref),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class EmployeeDashboardShell extends ConsumerWidget {
  final Widget child;
  const EmployeeDashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _LogoutButton(ref: ref),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  final WidgetRef ref;
  const _LogoutButton({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Logout')),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          await ref.read(authViewModelProvider.notifier).signOut();
        }
      },
    );
  }
}
