import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import '../domain/entities/schedule_entities.dart';
import '../domain/services/conflict_detector.dart';
import '../domain/services/coverage_calculator.dart';
import 'widgets/schedule_timeline.dart';
import 'widgets/shift_display_helper.dart';

class ScheduleEditorPage extends ConsumerStatefulWidget {
  final DateTime weekStart;
  
  const ScheduleEditorPage({Key? key, required this.weekStart}) : super(key: key);

  @override
  ConsumerState<ScheduleEditorPage> createState() => _ScheduleEditorPageState();
}

class _ScheduleEditorPageState extends ConsumerState<ScheduleEditorPage> {
  final Set<String> _conflictingAssignments = {};
  late ConflictDetector _conflictDetector;
  late CoverageCalculator _coverageCalculator;

  @override
  void initState() {
    super.initState();
    _conflictDetector = ConflictDetector(settings: SystemSettings(
      maxWeeklyHours: 48,
      minRestPeriodMinutes: 480,
      workingHoursStart: 480,
      workingHoursEnd: 1320,
      shiftTemplates: [],
    ));
    _coverageCalculator = CoverageCalculator(settings: _conflictDetector.settings);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule Editor - Week of ${widget.weekStart.toLocal()}'),
        actions: [
          if (_conflictingAssignments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                label: Text(
                  '${_conflictingAssignments.length} conflicts',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSchedule,
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: _showCoverageReport,
          ),
        ],
      ),
      body: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(flex: 3, child: _buildCoveragePanel()),
        Expanded(flex: 5, child: _buildScheduleTimeline()),
        Expanded(flex: 4, child: _buildAssignmentsPanel()),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildCoveragePanel(),
        Expanded(child: _buildScheduleTimeline()),
        SizedBox(
          height: 200,
          child: _buildAssignmentsPanel(),
        ),
      ],
    );
  }

  Widget _buildCoveragePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coverage Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: List.generate(3, (index) {
                final date = widget.weekStart.add(Duration(days: index));
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date.toLocal().toString().split(' ')[0],
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: 0.75,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '75% coverage',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTimeline() {
    return ScheduleTimeline(weekStart: widget.weekStart);
  }

  Widget _buildAssignmentsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) {
                final date = widget.weekStart.add(Duration(days: index));
                return ExpansionTile(
                  title: Text(ShiftDisplayHelper.formatShiftTime(
                    ScheduleAssignment(
                      id: '',
                      employeeId: '',
                      areaId: 'Emergency',
                      startDateTime: date.add(const Duration(hours: 8)),
                      endDateTime: date.add(const Duration(hours: 15)),
                      scheduledDate: date,
                    ),
                  )),
                  subtitle: const Text('Emergency - 7h shift'),
                  trailing: ShiftDisplayHelper.getShiftIcon(ScheduleAssignment(
                    id: '',
                    employeeId: '',
                    areaId: 'Emergency',
                    startDateTime: date.add(const Duration(hours: 8)),
                    endDateTime: date.add(const Duration(hours: 15)),
                    scheduledDate: date,
                  )) != Icons.wb_sunny_outlined
                      ? Icon(ShiftDisplayHelper.getShiftIcon(ScheduleAssignment(
                          id: '',
                          employeeId: '',
                          areaId: 'Emergency',
                          startDateTime: date.add(const Duration(hours: 8)),
                          endDateTime: date.add(const Duration(hours: 15)),
                          scheduledDate: date,
                        )))
                      : null,
                  children: [
                    ListTile(
                      title: const Text('Employee: John Smith'),
                      subtitle: Text('Shift: ${ShiftDisplayHelper.getShiftDurationDisplay(ScheduleAssignment(
                        id: '',
                        employeeId: '',
                        areaId: 'Emergency',
                        startDateTime: date.add(const Duration(hours: 8)),
                        endDateTime: date.add(const Duration(hours: 15)),
                        scheduledDate: date,
                      ))}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editAssignment(null),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _saveSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule saved successfully')),
    );
  }

  void _showCoverageReport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Coverage Report'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: 7,
            itemBuilder: (context, index) {
              final date = widget.weekStart.add(Duration(days: index));
              return ListTile(
                title: Text(date.toLocal().toString().split(' ')[0]),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editAssignment(ScheduleAssignment? assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(assignment == null ? 'New Assignment' : 'Edit Assignment'),
        content: _buildAssignmentForm(assignment),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentForm(ScheduleAssignment? assignment) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Employee',
              border: OutlineInputBorder(),
            ),
            initialValue: assignment?.employeeId ?? '',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Start',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: assignment?.startDateTime.toString() ?? '',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'End',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: assignment?.endDateTime.toString() ?? '',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Area',
              border: OutlineInputBorder(),
            ),
            initialValue: assignment?.areaId ?? '',
          ),
        ],
      ),
    );
  }
}

// ViewModel
class ScheduleEditorViewModel extends StateNotifier<AsyncValue<WeeklySchedule?>> {
  final GetWeeklyScheduleUseCase getWeeklyScheduleUseCase;
  final SaveWeeklyScheduleUseCase saveWeeklyScheduleUseCase;
  final GenerateScheduleUseCase generateScheduleUseCase;

  ScheduleEditorViewModel({
    required this.getWeeklyScheduleUseCase,
    required this.saveWeeklyScheduleUseCase,
    required this.generateScheduleUseCase,
  }) : super(const AsyncValue.loading());

  Future<void> loadSchedule(DateTime weekStart) async {
    state = const AsyncValue.loading();
    try {
      final schedule = await getWeeklyScheduleUseCase(weekStart);
      state = AsyncValue.data(schedule);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> generateSchedule(DateTime weekStart) async {
    state = const AsyncValue.loading();
    try {
      final schedule = await generateScheduleUseCase(weekStart);
      state = AsyncValue.data(schedule);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> saveSchedule(WeeklySchedule schedule) async {
    try {
      await saveWeeklyScheduleUseCase(schedule);
      state = AsyncValue.data(schedule);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

// Placeholder use cases for compilation
abstract class GetWeeklyScheduleUseCase {
  Future<WeeklySchedule?> call(DateTime weekStart);
}

abstract class SaveWeeklyScheduleUseCase {
  Future<void> call(WeeklySchedule schedule);
}

abstract class GenerateScheduleUseCase {
  Future<WeeklySchedule> call(DateTime weekStart);
}