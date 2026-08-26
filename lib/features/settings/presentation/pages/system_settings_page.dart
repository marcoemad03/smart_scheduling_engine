import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/locale/locale_providers.dart';
import 'package:reception_workforce_scheduler/features/settings/data/system_settings_repository.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';

class SystemSettingsPage extends ConsumerStatefulWidget {
  const SystemSettingsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SystemSettingsPage> createState() =>
      _SystemSettingsPageState();
}

class _SystemSettingsPageState extends ConsumerState<SystemSettingsPage> {
  late TextEditingController _maxHours;
  late TextEditingController _overtimeHours;
  late TextEditingController _restMinutes;
  late TextEditingController _consecutiveDays;
  late TextEditingController _workStart;
  late TextEditingController _workEnd;
  bool _customSchedules = true;
  bool _attendance = false;
  bool _allowOverride = true;
  bool _allowLongShifts = true;
  bool _allowSplitShifts = true;
  String _timezone = 'UTC';
  int _weekStartDay = 1;
  bool _initialized = false;

  static const _timezones = [
    'UTC', 'Europe/London', 'Europe/Paris', 'Africa/Cairo',
    'Asia/Riyadh', 'Asia/Dubai', 'America/New_York', 'Asia/Tokyo',
  ];

  @override
  void initState() {
    super.initState();
    _maxHours = TextEditingController();
    _overtimeHours = TextEditingController();
    _restMinutes = TextEditingController();
    _consecutiveDays = TextEditingController();
    _workStart = TextEditingController();
    _workEnd = TextEditingController();
  }

  @override
  void dispose() {
    _maxHours.dispose();
    _overtimeHours.dispose();
    _restMinutes.dispose();
    _consecutiveDays.dispose();
    _workStart.dispose();
    _workEnd.dispose();
    super.dispose();
  }

  void _loadInto(SystemSettings s) {
    if (_initialized) return;
    _maxHours.text = s.maxWeeklyHours.toStringAsFixed(0);
    _overtimeHours.text = s.maxOvertimeHoursPerWeek.toStringAsFixed(0);
    _restMinutes.text =
        (s.minRestPeriodMinutes / 60).toStringAsFixed(0);
    _consecutiveDays.text = s.maxConsecutiveWorkingDays.toString();
    _workStart.text = _fmt(s.workingHoursStart);
    _workEnd.text = _fmt(s.workingHoursEnd);
    _customSchedules = s.allowCustomSchedules;
    _attendance = s.enableAttendanceTracking;
    _allowOverride = s.allowScheduleOverride;
    _allowLongShifts = s.allowLongShifts;
    _allowSplitShifts = s.allowSplitShifts;
    _timezone = s.timezone;
    _weekStartDay = s.weekStartDay;
    _initialized = true;
  }

  String _fmt(int minutes) {
    final m = ((minutes % 1440) + 1440) % 1440;
    return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  }

  int _parseTime(String text) {
    final parts = text.split(':');
    final h = int.tryParse(parts[0]) ?? 8;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return h * 60 + m;
  }

  Future<void> _save() async {
    final settings = SystemSettings(
      settingsId: 'default',
      maxWeeklyHours: double.tryParse(_maxHours.text) ?? 48,
      maxOvertimeHoursPerWeek: double.tryParse(_overtimeHours.text) ?? 0,
      minRestPeriodMinutes:
          ((double.tryParse(_restMinutes.text) ?? 8) * 60).round(),
      workingHoursStart: _parseTime(_workStart.text),
      workingHoursEnd: _parseTime(_workEnd.text),
      allowCustomSchedules: _customSchedules,
      enableAttendanceTracking: _attendance,
      timezone: _timezone,
      weekStartDay: _weekStartDay,
      maxConsecutiveWorkingDays:
          int.tryParse(_consecutiveDays.text) ?? 6,
      allowScheduleOverride: _allowOverride,
      allowLongShifts: _allowLongShifts,
      allowSplitShifts: _allowSplitShifts,
      updatedAt: DateTime.now(),
      updatedBy: '',
    );
    await ref.read(systemSettingsViewModelProvider.notifier).save(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.settingsSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(systemSettingsViewModelProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.schedulingRulesTitle),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.errorPrefix('$e'))),
        data: (s) {
          _loadInto(s);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _languageSection(context),
              _section(context, l10n.sectionHoursLimits, [
                _numberField(_maxHours, l10n.maxWeeklyHoursDefault),
                _numberField(_overtimeHours, l10n.maxOvertimePerWeek),
                _numberField(_restMinutes, l10n.minRestHours),
                _numberField(_consecutiveDays, l10n.maxConsecutiveDays),
              ]),
              _section(context, l10n.sectionPractices, [
                SwitchListTile(
                  title: Text(l10n.allowOverride),
                  subtitle: Text(l10n.allowOverrideDesc),
                  value: _allowOverride,
                  onChanged: (v) => setState(() => _allowOverride = v),
                ),
                SwitchListTile(
                  title: Text(l10n.allowLongShifts),
                  value: _allowLongShifts,
                  onChanged: (v) => setState(() => _allowLongShifts = v),
                ),
                SwitchListTile(
                  title: Text(l10n.allowSplitShifts),
                  value: _allowSplitShifts,
                  onChanged: (v) => setState(() => _allowSplitShifts = v),
                ),
                SwitchListTile(
                  title: Text(l10n.allowCustomSchedules),
                  subtitle: Text(l10n.allowCustomSchedulesDesc),
                  value: _customSchedules,
                  onChanged: (v) => setState(() => _customSchedules = v),
                ),
              ]),
              _section(context, l10n.sectionGeneral, [
                ListTile(
                  title: Text(l10n.workingHoursStart),
                  trailing: SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _workStart,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(hintText: '08:00'),
                      onTap: () => _pickTime(context, _workStart),
                    ),
                  ),
                ),
                ListTile(
                  title: Text(l10n.workingHoursEnd),
                  trailing: SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _workEnd,
                      textAlign: TextAlign.end,
                      decoration: const InputDecoration(hintText: '22:00'),
                      onTap: () => _pickTime(context, _workEnd),
                    ),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _timezones.contains(_timezone) ? _timezone : _timezones.first,
                  decoration: InputDecoration(labelText: l10n.timezone),
                  items: _timezones
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _timezone = v!),
                ),
                DropdownButtonFormField<int>(
                  value: _weekStartDay,
                  decoration:
                      InputDecoration(labelText: l10n.weekStartsOn),
                  items: [
                    DropdownMenuItem(value: 1, child: Text(l10n.monday)),
                    DropdownMenuItem(value: 7, child: Text(l10n.sunday)),
                  ],
                  onChanged: (v) => setState(() => _weekStartDay = v!),
                ),
                SwitchListTile(
                  title: Text(l10n.enableAttendanceTracking),
                  value: _attendance,
                  onChanged: (v) => setState(() => _attendance = v),
                ),
              ]),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  /// Language selector: switches the whole app immediately and persists the
  /// choice locally (survives restarts). Arabic is the default language.
  Widget _languageSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeControllerProvider);
    final controller = ref.read(localeControllerProvider.notifier);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.languageSection,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'ar',
                  label: Text('${'🇪🇬'} ${l10n.arabic}'),
                ),
                ButtonSegment(
                  value: 'en',
                  label: Text('${'🇬🇧'} ${l10n.english}'),
                ),
              ],
              selected: {current.languageCode},
              onSelectionChanged: (selection) =>
                  controller.setLocale(Locale(selection.first)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime(BuildContext context, TextEditingController c) async {
    final initial = TimeOfDay(hour: int.tryParse(c.text.split(':').first) ?? 8,
        minute: int.tryParse(c.text.split(':').length > 1 ? c.text.split(':')[1] : '') ?? 0);
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      c.text =
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  Widget _section(
      BuildContext context, String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: TextInputType.number,
      ),
    );
  }
}
