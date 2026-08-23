import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SystemSettings {
  final double maxWeeklyHours;
  final int minRestPeriodMinutes;
  final int workingHoursStart;
  final int workingHoursEnd;
  final bool allowCustomSchedules;
  final bool enableAttendanceTracking;
  final String timezone;
  final int weekStartDay;

  SystemSettings({
    required this.maxWeeklyHours,
    required this.minRestPeriodMinutes,
    required this.workingHoursStart,
    required this.workingHoursEnd,
    required this.allowCustomSchedules,
    required this.enableAttendanceTracking,
    required this.timezone,
    required this.weekStartDay,
  });
}

class SystemSettingsViewModel extends StateNotifier<AsyncValue<SystemSettings>> {
  SystemSettingsViewModel() : super(const AsyncValue.loading()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 500));
    state = AsyncValue.data(SystemSettings(
      maxWeeklyHours: 48,
      minRestPeriodMinutes: 480,
      workingHoursStart: 480, // 08:00
      workingHoursEnd: 1320, // 22:00
      allowCustomSchedules: true,
      enableAttendanceTracking: true,
      timezone: 'Europe/London',
      weekStartDay: 1, // Monday
    ));
  }

  Future<void> saveSettings(SystemSettings settings) async {
    // Save to Firestore
    state = AsyncValue.data(settings);
  }
}

final systemSettingsViewModelProvider =
    StateNotifierProvider<SystemSettingsViewModel, AsyncValue<SystemSettings>>(
  (ref) => SystemSettingsViewModel(),
);

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _maxHoursController;
  late TextEditingController _restPeriodController;
  late TextEditingController _workStartController;
  late TextEditingController _workEndController;
  bool _allowCustomSchedules = true;
  bool _enableAttendance = true;
  String _timezone = 'Europe/London';
  int _weekStartDay = 1;

  final List<String> _timezones = [
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  @override
  void initState() {
    super.initState();
    _maxHoursController = TextEditingController(text: '48');
    _restPeriodController = TextEditingController(text: '480');
    _workStartController = TextEditingController(text: '08:00');
    _workEndController = TextEditingController(text: '22:00');
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(systemSettingsViewModelProvider);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(title: const Text('System Settings')),
      body: settingsAsync.when(
        data: (settings) {
          _maxHoursController.text = settings.maxWeeklyHours.toStringAsFixed(1);
          _restPeriodController.text = settings.minRestPeriodMinutes.toString();
          _workStartController.text = _formatTime(settings.workingHoursStart);
          _workEndController.text = _formatTime(settings.workingHoursEnd);
          _allowCustomSchedules = settings.allowCustomSchedules;
          _enableAttendance = settings.enableAttendanceTracking;
          _timezone = settings.timezone;
          _weekStartDay = settings.weekStartDay;

          return isDesktop 
              ? _buildDesktopLayout(context)
              : _buildMobileLayout(context);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildSettingsForm(context),
        ),
        Expanded(
          flex: 1,
          child: _buildSettingsPreview(context),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return _buildSettingsForm(context);
  }

  Widget _buildSettingsForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionTitle('Working Hours'),
            const SizedBox(height: 16),
            _buildTimeField(_workStartController, 'Start Time'),
            const SizedBox(height: 16),
            _buildTimeField(_workEndController, 'End Time'),
            const SizedBox(height: 32),
            _buildSectionTitle('Scheduling Rules'),
            const SizedBox(height: 16),
            _buildNumberField(_maxHoursController, 'Maximum Weekly Hours'),
            const SizedBox(height: 16),
            _buildNumberField(_restPeriodController, 'Minimum Rest Period (minutes)'),
            const SizedBox(height: 32),
            _buildSectionTitle('Advanced Settings'),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Allow Custom Schedules'),
              subtitle: const Text('Enable custom shift times'),
              value: _allowCustomSchedules,
              onChanged: (val) => setState(() => _allowCustomSchedules = val),
            ),
            SwitchListTile(
              title: const Text('Attendance Tracking'),
              subtitle: const Text('Enable clock in/out'),
              value: _enableAttendance,
              onChanged: (val) => setState(() => _enableAttendance = val),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Timezone',
              value: _timezone,
              items: _timezones,
              onChanged: (val) => setState(() => _timezone = val!),
            ),
            _buildDropdownField(
              label: 'Week Start Day',
              value: _weekStartDay.toString(),
              items: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
                  .asMap()
                  .entries
                  .map((e) => '${e.key}-${e.value}')
                  .toList(),
              onChanged: (val) => setState(() => _weekStartDay = int.parse(val!.split('-')[0])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPreview(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuration Preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          _buildPreviewCard(context, 'Max Weekly Hours', _maxHoursController.text),
          _buildPreviewCard(context, 'Rest Period', _restPeriodController.text),
          _buildPreviewCard(context, 'Working Hours', '${_workStartController.text} - ${_workEndController.text}'),
          _buildPreviewCard(context, 'Custom Schedules', _allowCustomSchedules ? 'Enabled' : 'Disabled'),
          _buildPreviewCard(context, 'Attendance', _enableAttendance ? 'Enabled' : 'Disabled'),
          _buildPreviewCard(context, 'Timezone', _timezone),
          _buildPreviewCard(context, 'Week Start', _weekStartDay == 1 ? 'Monday' : 'Sunday'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        if (double.tryParse(value) == null) return 'Invalid number';
        return null;
      },
    );
  }

  Widget _buildTimeField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.access_time_outlined),
      ),
      readOnly: true,
      onTap: () => _selectTime(context, controller),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required';
        return null;
      },
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, TextEditingController controller) async {
    final parts = controller.text.split(':');
    final initialHour = int.tryParse(parts[0]) ?? 8;
    final initialMinute = int.tryParse(parts[1]) ?? 0;

    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (result != null) {
      setState(() {
        controller.text = '${result.hour.toString().padLeft(2, '0')}:${result.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Widget _buildPreviewCard(BuildContext context, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            )),
          ],
        ),
      ),
    );
  }

  String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  void _saveSettings() {
    if (_formKey.currentState?.validate() ?? false) {
      final settings = SystemSettings(
        maxWeeklyHours: double.parse(_maxHoursController.text),
        minRestPeriodMinutes: int.parse(_restPeriodController.text),
        workingHoursStart: _parseTimeToMinutes(_workStartController.text),
        workingHoursEnd: _parseTimeToMinutes(_workEndController.text),
        allowCustomSchedules: _allowCustomSchedules,
        enableAttendanceTracking: _enableAttendance,
        timezone: _timezone,
        weekStartDay: _weekStartDay,
      );

      ref.read(systemSettingsViewModelProvider.notifier).saveSettings(settings);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  int _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

