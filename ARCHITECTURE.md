# Reception Workforce Scheduler - Architecture Design Document

## 1. Complete Architecture

### 1.1 Feature-Based Folder Structure

```
lib/
├── app/
│   ├── app.dart                           # MaterialApp configuration
│   ├── routes.dart                        # GoRouter route definitions
│   ├── theme/
│   │   └── app_theme.dart                 # Material 3 theming
│   └── responsiveness/                    # Device detection (future)
│
├── core/
│   ├── constants/
│   │   └── enums.dart                     # App-wide enums
│   ├── utils/
│   │   ├── date_time_utils.dart           # Date/time helpers
│   │   └── validators.dart                # Form validation
│   ├── services/
│   │   ├── firebase_service.dart          # Firebase initialization
│   │   ├── logger.dart                    # Logging utility
│   │   ├── notification_service.dart      # FCM/local notifications
│   │   └── timezone_service.dart          # Timezone handling
│   ├── errors/
│   │   ├── exceptions.dart                # Domain exceptions
│   │   └── failures.dart                  # Error types
│   ├── providers.dart                     # Global Riverpod providers
│   └── theme/
│       ├── app_theme.dart                 # Theme definitions
│       └── responsive.dart                # Responsive layout helpers
│
├── features/
│   ├── authentication/                    # Auth flow
│   │   ├── data/datasources/auth_remote_datasource.dart
│   │   ├── domain/entities/user.dart
│   │   ├── domain/repositories/auth_repository.dart
│   │   └── presentation/
│   │       ├── pages/login_page.dart
│   │       └── viewmodels/auth_viewmodel.dart
│   │
│   ├── dashboard/                         # Main navigation shell
│   │   └── presentation/pages/
│   │       ├── admin_dashboard_page.dart
│   │       └── employee_dashboard_page.dart
│   │
│   ├── employees/                         # Employee management
│   │   ├── data/datasources/employee_remote_datasource.dart
│   │   ├── domain/entities/employee.dart
│   │   └── presentation/pages/employee_list_page.dart
│   │
│   ├── areas/                             # Reception areas management
│   │   ├── data/datasources/area_remote_datasource.dart
│   │   ├── data/repositories_impl/area_repository_impl.dart
│   │   ├── domain/entities/reception_area.dart
│   │   ├── domain/repositories/area_repository.dart
│   │   └── presentation/pages/area_management_page.dart
│   │
│   ├── shifts/                            # Shift templates
│   │   └── presentation/pages/shift_template_page.dart
│   │
│   ├── staffing/                          # Staffing requirements
│   │   └── presentation/pages/staffing_requirements_page.dart
│   │
│   ├── schedules/                         # Weekly schedule management
│   │   ├── domain/services/
│   │   │   ├── conflict_detector.dart     # Conflict detection engine
│   │   │   └── schedule_generator.dart    # Auto-generation engine
│   │   ├── domain/entities/schedule_entities.dart
│   │   ├── data/datasources/schedule_remote_datasource.dart
│   │   └── presentation/widgets/
│   │       ├── schedule_timeline.dart
│   │       └── shift_display_helper.dart
│   │
│   ├── availability/                      # Employee availability
│   │   └── presentation/pages/availability_page.dart
│   │
│   ├── leaves/                            # Leave requests
│   │   └── domain/entities/leave_request.dart
│   │
│   ├── swaps/                             # Shift swap requests
│   │   └── domain/entities/swap_request.dart
│   │
│   ├── attendance/                        # Attendance tracking
│   │   └── domain/entities/attendance_record.dart
│   │
│   ├── notifications/                     # Notifications (future)
│   │
│   └── settings/                          # System settings
│       └── presentation/pages/system_settings_page.dart
│
└── main.dart                              # App entry point
```

### 1.2 Domain Model

**Core Entities:**

- **UserDomain**: Auth user with role (admin/employee)
- **Employee**: Extends user with personal details, maxWeeklyHours
- **ReceptionArea**: name, description, orderIndex, isActive
- **ShiftTemplate**: name, startMinute, durationMinutes, isNightShift
- **StaffingRequirement**: areaId, dayOfWeek, requiredCount, shiftTemplateId
- **ScheduleAssignment**: employeeId, areaId, startDateTime, endDateTime
- **WeeklySchedule**: weekStartDate, assignments, version, status
- **AvailabilityBlock**: employeeId, startDateTime, endDateTime, isAvailable
- **LeaveRequest**: employeeId, startDateTime, endDateTime, status
- **SwapRequest**: requestingEmployeeId, targetEmployeeId, assignmentId
- **AttendanceRecord**: assignmentId, employeeId, clockIn, clockOut
- **SystemSettings**: maxWeeklyHours, restPeriodMinutes, workingHours

### 1.3 Repository Pattern Implementation

Each feature follows this structure:
- **Domain Layer**: Entities, Repository interfaces
- **Data Layer**: Repository implementations, Firestore datasources
- **Presentation Layer**: ViewModels (Riverpod StateNotifier), Pages, Widgets

## 2. Firestore Collections and Document Structures

### 2.1 Users Collection (`users`)
```javascript
{
  "uid": "string",
  "email": "string",
  "role": "admin|employee",
  "displayName": "string",
  "createdAt": "timestamp",
  "lastLoginAt": "timestamp",
  "isActive": "boolean"
}
```

### 2.2 Employees Collection (`employees`)
```javascript
{
  "employeeId": "string",
  "firstName": "string",
  "lastName": "string",
  "email": "string",
  "phone": "string",
  "hireDate": "timestamp",
  "maxWeeklyHours": "number",
  "preferredAreas": ["areaId1", "areaId2"],
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 2.3 Areas Collection (`areas`)
```javascript
{
  "areaId": "string",
  "name": "string",
  "description": "string",
  "orderIndex": "number",
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 2.4 Shift Templates Collection (`shiftTemplates`)
```javascript
{
  "templateId": "string",
  "name": "string",
  "startMinute": "number",       // 0-1439 (08:00 = 480)
  "durationMinutes": "number",
  "isNightShift": "boolean",
  "colorValue": "number",        // hex color
  "isActive": "boolean",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 2.5 Staffing Requirements Collection (`staffingRequirements`)
```javascript
{
  "requirementId": "string",
  "areaId": "string",
  "dayOfWeek": "number",         // 0=Monday, 6=Sunday
  "requiredCount": "number",
  "shiftTemplateId": "string?",   // optional for custom shifts
  "minHoursPerWeek": "number",
  "createdAt": "timestamp"
}
```

### 2.6 Weekly Schedules Collection (`weeklySchedules`)
```javascript
{
  "scheduleId": "string",
  "weekStartDate": "timestamp",
  "weekEndDate": "timestamp",
  "version": "number",
  "status": "draft|published|archived",
  "createdBy": "uid",
  "publishedAt": "timestamp",
  "createdAt": "timestamp",
  "assignments": [
    {
      "assignmentId": "string",
      "employeeId": "string",
      "areaId": "string",
      "startDateTime": "timestamp",
      "endDateTime": "timestamp",
      "scheduledDate": "timestamp",
      "createdAt": "timestamp"
    }
  ]
}
```

### 2.7 Availability Collection (`availability`)
```javascript
{
  "availabilityId": "string",
  "employeeId": "string",
  "startDateTime": "timestamp",
  "endDateTime": "timestamp",
  "isAvailable": "boolean",
  "isRecurring": "boolean",
  "recurrenceDays": [0, 1, 2, 3, 4], // if recurring
  "createdAt": "timestamp"
}
```

### 2.8 Leave Requests Collection (`leaveRequests`)
```javascript
{
  "requestId": "string",
  "employeeId": "string",
  "type": "vacation|sick|personal|other",
  "startDateTime": "timestamp",
  "endDateTime": "timestamp",
  "status": "pending|approved|rejected|cancelled",
  "notes": "string",
  "adminNotes": "string",
  "createdAt": "timestamp",
  "approvedBy": "uid",
  "approvedAt": "timestamp"
}
```

### 2.9 Swap Requests Collection (`swapRequests`)
```javascript
{
  "swapId": "string",
  "requestingEmployeeId": "string",
  "targetEmployeeId": "string",
  "assignmentId": "string",
  "preferredDatetime": "timestamp",
  "status": "pending|approved|rejected|cancelled",
  "notes": "string",
  "adminAction": {
    "notes": "string",
    "actedBy": "uid",
    "actedAt": "timestamp"
  },
  "createdAt": "timestamp"
}
```

### 2.10 Attendance Collection (`attendance`)
```javascript
{
  "recordId": "string",
  "assignmentId": "string",
  "employeeId": "string",
  "date": "timestamp",
  "clockInTime": "timestamp",
  "clockOutTime": "timestamp",
  "status": "present|absent|late|on_time",
  "notes": "string",
  "createdAt": "timestamp"
}
```

### 2.11 System Settings Collection (`systemSettings`)
```javascript
{
  "settingsId": "default",
  "maxWeeklyHours": "number",          // e.g., 48
  "minRestPeriodMinutes": "number",     // e.g., 480 (8 hours)
  "workingHoursStart": "number",        // minute of day, e.g., 480 (08:00)
  "workingHoursEnd": "number",          // minute of day, e.g., 1320 (22:00)
  "allowCustomSchedules": "boolean",
  "enableAttendanceTracking": "boolean",
  "timezone": "string",                 // e.g., "Europe/London"
  "weekStartDay": "number",             // 0=Monday, 1=Sunday
  "updatedAt": "timestamp",
  "updatedBy": "uid"
}
```

### 2.12 Notifications Collection (`notifications`)
```javascript
{
  "notificationId": "string",
  "userId": "string",               // recipient
  "type": "schedule_published|swap_approved|leave_approved|attendance_reminder",
  "title": "string",
  "body": "string",
  "data": {
    "assignmentId": "string",
    "scheduleId": "string",
    "action": "view_schedule"
  },
  "isRead": "boolean",
  "createdAt": "timestamp",
  "priority": "high|normal|low"
}
```

## 3. Security Rules Strategy

```firestore.rules
rules_version = '2';
service cloud.firestore {
  match service.firestore {
    match /databases/{database}/documents {
      function isAdmin() {
        return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      }
      
      function isEmployee() {
        return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'employee';
      }
      
      // Users - access own profile only
      match /users/{userId} {
        allow read, update: if userId == request.auth.uid || isAdmin();
        allow create: if request.auth != null;
      }
      
      // Employees - admin CRUD, employee read
      match /employees/{employeeId} {
        allow read: if employeeId == request.auth.uid || isAdmin();
        allow create, update, delete: if isAdmin();
      }
      
      // Areas - admin CRUD, employee read
      match /areas/{areaId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
      
      // Shift templates - admin CRUD, employee read
      match /shiftTemplates/{templateId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
      
      // Staffing requirements - admin CRUD, employee read
      match /staffingRequirements/{requirementId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
      
      // Weekly schedules - admin full, employee own shifts
      match /weeklySchedules/{scheduleId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
      
      // Availability - employee own, admin all
      match /availability/{availabilityId} {
        allow read, create: if isEmployee() || isAdmin();
        allow update, delete: if 
          (resource.data.employeeId == request.auth.uid && isEmployee()) ||
          isAdmin();
      }
      
      // Leave requests - employee own requests, admin manage all
      match /leaveRequests/{requestId} {
        allow read: if resource.data.employeeId == request.auth.uid || isAdmin();
        allow create: if isEmployee() || isAdmin();
        allow update, delete: if isAdmin() || 
          (resource.data.employeeId == request.auth.uid && isEmployee());
      }
      
      // Swap requests
      match /swapRequests/{swapId} {
        allow read: if resource.data.requestingEmployeeId == request.auth.uid ||
                      resource.data.targetEmployeeId == request.auth.uid ||
                      isAdmin();
        allow create: if isEmployee() || isAdmin();
        allow update: if isAdmin();
      }
      
      // Attendance
      match /attendance/{recordId} {
        allow read: if resource.data.employeeId == request.auth.uid || isAdmin();
        allow create, update, delete: if isAdmin();
      }
      
      // System settings - admin only
      match /systemSettings/{settingsId} {
        allow read: if true;
        allow create, update, delete: if isAdmin();
      }
      
      // Notifications
      match /notifications/{notificationId} {
        allow read, update: if resource.data.userId == request.auth.uid || isAdmin();
        allow create, delete: if isAdmin();
      }
    }
  }
}
```

## 4. Main Application Screens

### Admin Screens
- Admin Dashboard
- Employee Management (list, add, edit, deactivate)
- Area Management (list, add, edit, reorder, activate)
- Shift Templates (list, add, edit, deactivate)
- Staffing Requirements (configure by area & day)
- Schedule Editor (drag-drop, conflict detection, coverage visualization)
- Schedule Versions
- Leave Request Approval
- Swap Request Approval
- Attendance Management
- System Settings

### Employee Screens
- Employee Dashboard
- My Schedule (weekly view with timeline)
- Availability Management
- Leave Request Submission
- Swap Request Submission
- Attendance (clock in/out)
- Notification Center

## 5. Navigation Structure

Navigation uses GoRouter with ShellRoute for role-based navigation:

**Admin Navigation:**
```
/admin (dashboard)
/admin/employees
/admin/areas
/admin/shifts
/admin/staffing
/admin/schedules
/admin/leaves
/admin/swaps
/admin/attendance
/admin/settings
```

**Employee Navigation:**
```
/employee (dashboard)
/employee/schedule
/employee/availability
/employee/leaves
/employee/swaps
```

Left-hand NavigationRail for desktop, BottomNavigationBar planned for mobile.

## 6. State Management Strategy

Uses **Riverpod 2** with `StateNotifierProvider` for all state management:

### Architecture Pattern
Each feature implements:
1. **UseCases** - Business logic encapsulation
2. **Repositories** - Abstract data layer interfaces
3. **ViewModels** - State management with StateNotifier
4. **Providers** - Dependency injection

### Example ViewModel Pattern:
```dart
class ScheduleEditorViewModel extends StateNotifier<AsyncValue<WeeklySchedule?>> {
  final GetWeeklyScheduleUseCase getWeeklySchedule;
  final SaveWeeklyScheduleUseCase saveWeeklySchedule;
  final GenerateScheduleUseCase generateSchedule;
  
  Future<void> loadSchedule(DateTime weekStart) async {
    state = const AsyncValue.loading();
    try {
      final schedule = await getWeeklySchedule(weekStart);
      state = AsyncValue.data(schedule);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
```

## 7. Scheduling Domain Model

### 7.1 Core Entities

```dart
class ScheduleAssignment {
  final String id;
  final String employeeId;
  final String areaId;
  final DateTime startDateTime;    // Actual datetime, not just shift name
  final DateTime endDateTime;      // Actual datetime
  final String? shiftTemplateId;   // Optional reference
  final DateTime scheduledDate;
  
  Duration get duration => endDateTime.difference(startDateTime);
  bool get isOvernight => endDateTime.day != startDateTime.day;
  bool overlapsWith(ScheduleAssignment other) { ... }
}

class WeeklySchedule {
  final List<ScheduleAssignment> assignments;
  
  List<ScheduleAssignment> getAssignmentsForEmployee(String employeeId) { ... }
  double getWeeklyHoursForEmployee(String employeeId) { ... }
}
```

### 7.2 Schedule Generation Engine

```dart
class ScheduleGenerator {
  final SystemSettings settings;
  final List<Employee> employees;
  final List<ReceptionArea> areas;
  final List<StaffingRequirement> requirements;
  final List<AvailabilityBlock> availabilities;
  final List<LeaveRequest> leaves;
  
  Future<WeeklySchedule> generateWeekSchedule(DateTime weekStart) {
    for each day:
      for each requirement (area + shift):
        find available employees
        create assignments
        check constraints
  }
}
```

## 8. Conflict Detection Model

### 8.1 Conflict Types
- **employeeTimeOverlap** (error): Same employee scheduled twice
- **areaTimeOverlap** (error): Same area assigned twice
- **insufficientRest** (warning): Gap < minRestPeriodMinutes
- **maxHoursExceeded** (error): Weekly hours exceed limit
- **availabilityConflict** (error): Scheduled during unavailable time
- **leaveConflict** (error): Scheduled during approved leave

### 8.2 Conflict Detector

```dart
class ConflictDetector {
  List<ScheduleConflict> detectAllConflicts(
    ScheduleAssignment newAssignment,
    List<ScheduleAssignment> existingAssignments,
    List<AvailabilityBlock> availabilities,
    List<LeaveRequest> leaves,
  ) { ... }
}

class ScheduleConflict {
  final ConflictType type;
  final ConflictSeverity severity; // warning | error
  final String message;
  ...
}
```

## 9. Coverage Calculation Model

```dart
class CoverageCalculator {
  CoverageResult calculateDayCoverage(
    DateTime date,
    List<ScheduleAssignment> assignments,
    List<StaffingRequirement> requirements,
    List<ReceptionArea> areas,
  ) {
    // Calculate assignments per area vs required count
    // Find gaps between shifts
    // Calculate overall coverage percentage
  }
}

class CoverageResult {
  final DateTime date;
  final List<AreaCoverage> areaCoverages;
  final List<ShiftGap> gaps;
  final double overallCoveragePercentage;
}

class AreaCoverage {
  final String areaId;
  final int requiredCount;
  final int assignedCount;
  final double coveragePercentage;
  final List<ShiftGap> gaps;
}
```

## 10. Overnight Shifts Support

### 10.1 Time Calculation

Shifts store actual DateTime values:
- `startDateTime` - actual start (e.g., 22:00 on Monday)
- `endDateTime` - actual end (e.g., 08:00 on Tuesday)

```dart
bool get isOvernight => 
  endDateTime.isAfter(DateTime(endDateTime.year, endDateTime.month, endDateTime.day));

// Time calculations use actual DateTime differences
Duration get duration => endDateTime.difference(startDateTime);
```

### 10.2 Display Logic

```dart
class ShiftDisplayHelper {
  static String formatShiftTime(ScheduleAssignment assignment) {
    final start = DateFormat.Hm().format(assignment.startDateTime);
    final end = DateFormat.Hm().format(assignment.endDateTime);
    
    if (assignment.isOvernight) {
      final nextDay = assignment.endDateTime.add(const Duration(days: 1));
      return "$start → $end+ (${nextDay.day}/${nextDay.month})";
    }
    return "$start → $end";
  }
  
  // Split overnight shift for timeline display
  static List<TimeSegment> splitOvernightShift(ScheduleAssignment assignment) {
    final midnight = DateTime(endDate.year, endDate.month, endDate.day);
    return [
      TimeSegment(start: assignment.startDateTime, end: midnight),
      TimeSegment(start: midnight, end: assignment.endDateTime),
    ];
  }
}
```

### 10.3 Conflict Detection for Overnight Shifts

```dart
// Standard overlap check handles overnight shifts correctly
// since we're comparing actual DateTime values
bool overlapsWith(ScheduleAssignment other) {
  return startDateTime.isBefore(other.endDateTime) && 
         other.startDateTime.isBefore(endDateTime);
}
```

## 11. Future Extensibility

The architecture is designed so future features can be added without rewriting the scheduling engine:

### Extension Points:
1. **New Shift Types** - Add via ShiftTemplate collection
2. **New Constraints** - Extend ConflictDetector with new types
3. **New Notification Types** - Add to notifications collection
4. **New Roles** - Extend UserRole enum
5. **New Entities** - Follow existing feature folder structure
6. **Integration APIs** - Add new datasources in core/services/

### Flexibility Guarantees:
- All configurable values in `systemSettings` collection
- Shift duration stored as actual DateTime, not template references
- Staffing requirements configurable per area per day
- Employee constraints (max hours, availability) stored as data
- Rest periods and working hours fully configurable