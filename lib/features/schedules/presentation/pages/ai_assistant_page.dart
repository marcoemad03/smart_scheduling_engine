import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/utils/date_time_utils.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/entities/schedule_entities.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/assistant_engine.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/scheduling_assistant_commands.dart';
import 'package:reception_workforce_scheduler/features/schedules/presentation/providers/scheduler_providers.dart';
import 'package:reception_workforce_scheduler/features/settings/domain/entities/system_settings.dart';

class _ChatMessage {
  final bool fromAdmin;
  final String text;
  final AssistantProposal? proposal;

  const _ChatMessage({required this.fromAdmin, required this.text, this.proposal});
}

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final _messages = <_ChatMessage>[];
  final _controller = TextEditingController();

  static const _suggestions = [
    'Make Ahmed off on Tuesday.',
    'Move Mohamed to Clinics on Wednesday.',
    'I need two additional employees from 8 AM to 3 PM on Friday.',
    'Do not assign Mina to night shifts this week.',
    'Generate the best schedule for this week.',
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(fromAdmin: true, text: text));
      _controller.clear();
    });

    final state = ref.read(schedulerViewModelProvider);
    if (state.schedule == null) {
      setState(() => _messages.add(const _ChatMessage(
          fromAdmin: false, text: 'Load a week in the scheduler first.')));
      return;
    }

    final interpreter = const RuleBasedCommandInterpreter();
    final result = interpreter.interpret(
      request: text,
      employees: state.employees,
      areas: state.areas,
      weekStart: state.weekStart,
    );

    if (result.commands.isEmpty) {
      setState(() => _messages.add(_ChatMessage(
          fromAdmin: false,
          text: result.notes.join('\n'))));
      return;
    }

    final engine = AssistantEngine(
      settings: state.settings ?? _defaultSettings(),
      employees: state.employees,
      areas: state.areas,
      requirements: state.staffingRequirements,
      availabilities: state.availabilities,
      leaves: state.leaves,
      baseSchedule: state.schedule!,
      currentUserId:
          ref.read(schedulerViewModelProvider.notifier).currentUserId,
    );

    final proposal = engine.execute(result.commands);
    final buffer = StringBuffer()
      ..writeln('I understood:')
      ..forCommands(result.commands)
      ..writeln();
    for (final e in proposal.explanations) {
      buffer.writeln(e);
    }
    buffer
      ..writeln()
      ..writeln(
          'Validation: ${proposal.isFullyValid ? "no blocking conflicts" : "${proposal.conflicts.where((c) => c.severity == ConflictSeverity.error).length + proposal.staffingConflicts.length} issue(s) found"}'
          ' • Coverage ${proposal.coverage.coveragePercentage.toStringAsFixed(1)}%');
    setState(() => _messages.add(_ChatMessage(
        fromAdmin: false, text: buffer.toString(), proposal: proposal)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Scheduling Assistant')),
      body: Column(children: [
        Expanded(
          child: _messages.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    return Align(
                      alignment: m.fromAdmin
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(maxWidth: 560),
                        decoration: BoxDecoration(
                          color: m.fromAdmin
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.text),
                            if (m.proposal != null) ...[
                              const SizedBox(height: 8),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                FilledButton.icon(
                                  icon: const Icon(Icons.preview, size: 16),
                                  label: const Text('Preview'),
                                  onPressed: () =>
                                      _showPreview(context, m.proposal!),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => _messages
                                      .add(const _ChatMessage(
                                          fromAdmin: false,
                                          text: 'Discarded — no changes applied.'))),
                                  child: const Text('Discard'),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Wrap(
          spacing: 6,
          children: _suggestions
              .map((s) => ActionChip(
                    label: Text(s,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () => _send(s),
                  ))
              .toList(),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                    hintText:
                        'e.g. Make Ahmed off on Tuesday'),
                onSubmitted: _send,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () => _send(_controller.text),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 64),
          const SizedBox(height: 12),
          Text(
            'Ask me to change the schedule.\nEvery change is validated and '
            'applied only after your approval.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _showPreview(
      BuildContext context, AssistantProposal proposal) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(
            proposal.isFullyValid ? Icons.verified : Icons.warning_amber,
            color: proposal.isFullyValid ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Proposed Changes')),
        ]),
        content: SizedBox(
          width: 520,
          height: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Coverage after change'),
                Text(
                  '${proposal.coverage.totalScheduled}/${proposal.coverage.totalRequired} • '
                  '${proposal.coverage.coveragePercentage.toStringAsFixed(1)}% • '
                  '${proposal.isFullyValid ? "VALID" : "NEEDS REVIEW"}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _sectionTitle('Added (${proposal.added.length})'),
                ...proposal.added.map(_assignmentLine),
                _sectionTitle('Removed (${proposal.removed.length})'),
                ...proposal.removed.map(_assignmentLine),
                _sectionTitle('Modified (${proposal.modified.length})'),
                ...proposal.modified.map((pair) => _assignmentLine(pair.$2)),
                const Divider(),
                _sectionTitle('Validation findings'),
                if (proposal.conflicts.isEmpty &&
                    proposal.staffingConflicts.isEmpty)
                  const Text('No conflicts.'),
                ...proposal.conflicts
                    .where((c) => c.severity == ConflictSeverity.error)
                    .map((c) => _bullet(c.message)),
                ...proposal.staffingConflicts.map((c) => _bullet(c.message)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Approve & Apply as Draft'),
            onPressed: () {
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .adoptProposedAssignments(proposal.proposedDraft.assignments);
              Navigator.pop(ctx);
              setState(() => _messages.add(const _ChatMessage(
                  fromAdmin: false,
                  text:
                      'Changes applied to the DRAFT. Review them in the scheduler and save/publish when ready.')));
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(t,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _assignmentLine(ScheduleAssignment a) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          '• ${DateFormat('EEE d/M').format(a.scheduledDate)} '
          '${DateTimeUtils.formatTime(a.startDateTime)}→${DateTimeUtils.formatTime(a.endDateTime)}',
          style: const TextStyle(fontSize: 12),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ]),
      );
}

extension on StringBuffer {
  void forCommands(List<SchedulingCommand> commands) {
    for (final c in commands) {
      writeln('• ${c.description}');
    }
  }
}

SystemSettings _defaultSettings() {
  return SystemSettings(
    settingsId: 'default',
    maxWeeklyHours: 48,
    minRestPeriodMinutes: 480,
    workingHoursStart: 480,
    workingHoursEnd: 1320,
    allowCustomSchedules: true,
    enableAttendanceTracking: false,
    timezone: 'UTC',
    weekStartDay: 1,
    updatedAt: DateTime.now(),
    updatedBy: '',
  );
}
