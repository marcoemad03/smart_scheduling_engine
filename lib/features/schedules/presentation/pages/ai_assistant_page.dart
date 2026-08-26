import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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

  List<String> _suggestions(AppLocalizations l10n) => [
        l10n.suggestion1,
        l10n.suggestion2,
        l10n.suggestion3,
        l10n.suggestion4,
        l10n.suggestion5,
      ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(fromAdmin: true, text: text));
      _controller.clear();
    });

    final state = ref.read(schedulerViewModelProvider);
    if (state.schedule == null) {
      setState(() => _messages.add(_ChatMessage(
          fromAdmin: false,
          text: AppLocalizations.of(context)!.loadWeekFirst)));
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

    final l10n = AppLocalizations.of(context)!;
    final proposal = engine.execute(result.commands);
    final issueCount = proposal.conflicts
            .where((c) => c.severity == ConflictSeverity.error)
            .length +
        proposal.staffingConflicts.length;
    final buffer = StringBuffer()
      ..writeln(l10n.iUnderstood)
      ..forCommands(result.commands)
      ..writeln();
    for (final e in proposal.explanations) {
      buffer.writeln(e);
    }
    buffer
      ..writeln()
      ..writeln(
          '${l10n.validationLabel}: ${proposal.isFullyValid ? l10n.noBlockingConflicts : l10n.issuesFound('$issueCount')}'
          ' • ${l10n.coveragePercent(proposal.coverage.coveragePercentage.toStringAsFixed(1))}');
    setState(() => _messages.add(_ChatMessage(
        fromAdmin: false, text: buffer.toString(), proposal: proposal)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiAssistantTitle)),
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
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
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
                                  label: Text(l10n.preview),
                                  onPressed: () =>
                                      _showPreview(context, m.proposal!),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => _messages
                                      .add(_ChatMessage(
                                          fromAdmin: false,
                                          text: l10n.discardedMsg))),
                                  child: Text(l10n.discard),
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
          children: _suggestions(l10n)
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
                decoration: InputDecoration(
                    hintText: l10n.assistantHint),
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
            AppLocalizations.of(context)!.assistantEmptyState,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Future<void> _showPreview(
      BuildContext context, AssistantProposal proposal) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(
            proposal.isFullyValid ? Icons.verified : Icons.warning_amber,
            color: proposal.isFullyValid ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.proposedChanges)),
        ]),
        content: SizedBox(
          width: 520,
          height: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(l10n.coverageAfterChange),
                Text(
                  '${proposal.coverage.totalScheduled}/${proposal.coverage.totalRequired} • '
                  '${proposal.coverage.coveragePercentage.toStringAsFixed(1)}% • '
                  '${proposal.isFullyValid ? l10n.valid : l10n.needsReview}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(),
                _sectionTitle(l10n.addedCount('${proposal.added.length}')),
                ...proposal.added.map(_assignmentLine),
                _sectionTitle(l10n.removedCount('${proposal.removed.length}')),
                ...proposal.removed.map(_assignmentLine),
                _sectionTitle(l10n.modifiedCount('${proposal.modified.length}')),
                ...proposal.modified.map((pair) => _assignmentLine(pair.$2)),
                const Divider(),
                _sectionTitle(l10n.validationFindings),
                if (proposal.conflicts.isEmpty &&
                    proposal.staffingConflicts.isEmpty)
                  Text(l10n.noConflicts),
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
              child: Text(l10n.cancel)),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(l10n.approveApplyDraft),
            onPressed: () {
              ref
                  .read(schedulerViewModelProvider.notifier)
                  .adoptProposedAssignments(proposal.proposedDraft.assignments);
              Navigator.pop(ctx);
              setState(() => _messages.add(_ChatMessage(
                  fromAdmin: false,
                  text: l10n.appliedToDraft)));
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
