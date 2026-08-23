export 'package:flutter/material.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:cloud_firestore/cloud_firestore.dart';
export 'package:firebase_auth/firebase_auth.dart';
export 'package:go_router/go_router.dart';
export 'package:uuid/uuid.dart';

// Core exports
export 'core/constants/enums.dart';
export 'core/errors/exceptions.dart';
export 'core/errors/failures.dart';
export 'core/services/firebase_service.dart';
export 'core/services/logger.dart';
export 'core/services/notification_service.dart';
export 'core/services/timezone_service.dart';
export 'core/utils/date_time_utils.dart';
export 'core/utils/validators.dart';

// Feature exports - Authentication
export 'features/authentication/data/datasources/auth_remote_datasource.dart';
export 'features/authentication/data/models/user_model.dart';
export 'features/authentication/data/repositories/auth_repository_impl.dart';
export 'features/authentication/domain/entities/user.dart';
export 'features/authentication/domain/repositories/auth_repository.dart';
export 'features/authentication/domain/usecases/auth_usecases.dart';
export 'features/authentication/presentation/pages/login_page.dart';
export 'features/authentication/presentation/providers.dart';
export 'features/authentication/presentation/viewmodels/auth_viewmodel.dart';

// Feature exports - Areas
export 'features/areas/data/datasources/area_remote_datasource.dart';
export 'features/areas/data/models/area_model.dart';
export 'features/areas/data/repositories/area_repository_impl.dart';
export 'features/areas/domain/entities/reception_area.dart';
export 'features/areas/domain/repositories/area_repository.dart';
export 'features/areas/domain/usecases/get_areas.dart';
export 'features/areas/presentation/pages/area_management_page.dart';
export 'features/areas/presentation/providers.dart';
export 'features/areas/presentation/viewmodels/area_viewmodel.dart';

// Feature exports - Employees
export 'features/employees/data/datasources/employee_remote_datasource.dart';
export 'features/employees/data/models/employee_model.dart';
export 'features/employees/data/repositories/employee_repository_impl.dart';
export 'features/employees/domain/entities/employee.dart';
export 'features/employees/domain/repositories/employee_repository.dart';
export 'features/employees/domain/usecases/get_employees.dart';
export 'features/employees/presentation/pages/employee_list_page.dart';
export 'features/employees/presentation/providers.dart';
export 'features/employees/presentation/viewmodels/employee_viewmodel.dart';

// Feature exports - Shifts
export 'features/shifts/data/datasources/shift_template_remote_datasource.dart';
export 'features/shifts/data/models/shift_template_model.dart';
export 'features/shifts/data/repositories/shift_template_repository_impl.dart';
export 'features/shifts/domain/entities/shift_template.dart';
export 'features/shifts/domain/repositories/shift_template_repository.dart';
export 'features/shifts/domain/usecases/get_shift_templates.dart';
export 'features/shifts/presentation/pages/shift_template_page.dart';
export 'features/shifts/presentation/providers.dart';
export 'features/shifts/presentation/viewmodels/shift_template_viewmodel.dart';

// Feature exports - Staffing
export 'features/staffing/data/datasources/staffing_remote_datasource.dart';
export 'features/staffing/data/models/staffing_requirement_model.dart';
export 'features/staffing/data/repositories/staffing_repository_impl.dart';
export 'features/staffing/domain/entities/staffing_requirement.dart';
export 'features/staffing/domain/repositories/staffing_repository.dart';
export 'features/staffing/domain/usecases/get_staffing_requirements.dart';
export 'features/staffing/presentation/pages/staffing_requirements_page.dart';
export 'features/staffing/presentation/providers.dart';
export 'features/staffing/presentation/viewmodels/staffing_viewmodel.dart';

// Feature exports - Schedules
export 'features/schedules/data/datasources/schedule_remote_datasource.dart';
export 'features/schedules/data/models/schedule_assignment_model.dart';
export 'features/schedules/data/models/weekly_schedule_model.dart';
export 'features/schedules/data/repositories/schedule_repository_impl.dart';
export 'features/schedules/domain/entities/schedule_entities.dart';
export 'features/schedules/domain/repositories/schedule_repository.dart';
export 'features/schedules/domain/usecases/generate_schedule.dart';
export 'features/schedules/domain/usecases/get_weekly_schedule.dart';
export 'features/schedules/domain/usecases/save_weekly_schedule.dart';
export 'features/schedules/domain/usecases/detect_conflicts.dart';
export 'features/schedules/domain/usecases/calculate_coverage.dart';
export 'features/schedules/presentation/pages/schedule_editor_page.dart';
export 'features/schedules/presentation/pages/schedule_view_page.dart';
export 'features/schedules/presentation/widgets/schedule_timeline.dart';
export 'features/schedules/presentation/widgets/shift_display_helper.dart';
export 'features/schedules/presentation/providers.dart';
export 'features/schedules/presentation/viewmodels/schedule_editor_viewmodel.dart';
export 'features/schedules/presentation/viewmodels/schedule_view_viewmodel.dart';

// Feature exports - Availability
export 'features/availability/data/datasources/availability_remote_datasource.dart';
export 'features/availability/data/models/availability_block_model.dart';
export 'features/availability/data/repositories/availability_repository_impl.dart';
export 'features/availability/domain/entities/availability_block.dart';
export 'features/availability/domain/repositories/availability_repository.dart';
export 'features/availability/domain/usecases/get_availability.dart';
export 'features/availability/presentation/pages/availability_page.dart';
export 'features/availability/presentation/providers.dart';
export 'features/availability/presentation/viewmodels/availability_viewmodel.dart';

// Feature exports - Leaves
export 'features/leaves/data/datasources/leave_request_remote_datasource.dart';
export 'features/leaves/data/models/leave_request_model.dart';
export 'features/leaves/data/repositories/leave_request_repository_impl.dart';
export 'features/leaves/domain/entities/leave_request.dart';
export 'features/leaves/domain/repositories/leave_request_repository.dart';
export 'features/leaves/domain/usecases/get_leave_requests.dart';
export 'features/leaves/presentation/pages/leave_request_page.dart';
export 'features/leaves/presentation/pages/leave_approval_page.dart';
export 'features/leaves/presentation/providers.dart';
export 'features/leaves/presentation/viewmodels/leave_request_viewmodel.dart';

// Feature exports - Swaps
export 'features/swaps/data/datasources/swap_request_remote_datasource.dart';
export 'features/swaps/data/models/swap_request_model.dart';
export 'features/swaps/data/repositories/swap_request_repository_impl.dart';
export 'features/swaps/domain/entities/swap_request.dart';
export 'features/swaps/domain/repositories/swap_request_repository.dart';
export 'features/swaps/domain/usecases/get_swap_requests.dart';
export 'features/swaps/presentation/pages/swap_request_page.dart';
export 'features/swaps/presentation/pages/swap_approval_page.dart';
export 'features/swaps/presentation/providers.dart';
export 'features/swaps/presentation/viewmodels/swap_request_viewmodel.dart';

// Feature exports - Attendance
export 'features/attendance/data/datasources/attendance_remote_datasource.dart';
export 'features/attendance/data/models/attendance_record_model.dart';
export 'features/attendance/data/repositories/attendance_repository_impl.dart';
export 'features/attendance/domain/entities/attendance_record.dart';
export 'features/attendance/domain/repositories/attendance_repository.dart';
export 'features/attendance/domain/usecases/get_attendance.dart';
export 'features/attendance/presentation/pages/attendance_page.dart';
export 'features/attendance/presentation/pages/attendance_management_page.dart';
export 'features/attendance/presentation/providers.dart';
export 'features/attendance/presentation/viewmodels/attendance_viewmodel.dart';

// Feature exports - Settings
export 'features/settings/data/datasources/settings_remote_datasource.dart';
export 'features/settings/data/models/system_settings_model.dart';
export 'features/settings/data/repositories/settings_repository_impl.dart';
export 'features/settings/domain/entities/system_settings.dart';
export 'features/settings/domain/repositories/settings_repository.dart';
export 'features/settings/domain/usecases/get_settings.dart';
export 'features/settings/presentation/pages/system_settings_page.dart';
export 'features/settings/presentation/providers.dart';
export 'features/settings/presentation/viewmodels/system_settings_viewmodel.dart';

// App-level exports
export 'app/app.dart';
export 'app/routes.dart';