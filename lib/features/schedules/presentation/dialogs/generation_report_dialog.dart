import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/coverage_calculator.dart';
import 'package:reception_workforce_scheduler/features/schedules/domain/services/schedule_generator.dart';

/// Shows the engine-confirmed outcome of a generation run. Never claims
/// validity unless [GenerationResult.isFullyValid] (engine-verified) is true.
class GenerationReportDialog extends StatelessWidget {
  final GenerationResult result;
  final Map<String, String> employeeNames;
  final Map<String, String> areaNames;

  const GenerationReportDialog({
    Key? key,
    required this.result,
    required this.employeeNames,
    required this.areaNames,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coverage = result.coverageReport;
    final statusColor = result.isFullyValid
        ? Colors.green
        : result.hasErrors
            ? Colors.red
            : Colors.orange;

    return AlertDialog(
      title: Row(children: [
        Icon(
            result.isFullyValid
                ? Icons.verified
                : Icons.report_problem,
            color: statusColor),
        const SizedBox(width: 8),
        Expanded(child: Text(l10n.draftGeneratedTitle)),
      ]),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard(context, coverage, statusColor),
              const SizedBox(height: 16),
              if (!result.isFullyValid) ...[
                Text(l10n.couldNotSatisfy,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (result.unfilled.isEmpty &&
                    !result.hasErrors &&
                    result.staffingConflicts.isEmpty)
                  Text(l10n.noBlockingIssues)
                else ...[
                  for (final u in result.unfilled)
                    _bullet(
                        '${_area(u.areaId)} ${u.windowLabel} ${u.dateLabel}: ${l10n.missingCount('${u.missing}')}'),
                  for (final c in result.conflicts
                      .where((c) => c.severity == ConflictSeverity.error))
                    _bullet(c.message),
                  for (final g in result.staffingConflicts)
                    _bullet(g.message),
                ],
                const SizedBox(height: 16),
              ],
              if (result.warnings.isNotEmpty) ...[
                Text(l10n.warnings,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final w in result.warnings) _bullet(w),
                const SizedBox(height: 16),
              ],
              Text(l10n.perEmployeeStats,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.symmetric(
                    inside:
                        BorderSide(color: Colors.grey.shade300, width: 0.5)),
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.6),
                  4: FlexColumnWidth(1.4),
                },
                children: [
                  TableRow(children: [
                    Padding(
                        padding: const EdgeInsets.all(4), child: Text(l10n.employee)),
                    Padding(
                        padding: const EdgeInsets.all(4), child: Text(l10n.colHours)),
                    Padding(
                        padding: const EdgeInsets.all(4), child: Text(l10n.colShifts)),
                    Padding(
                        padding: const EdgeInsets.all(4), child: Text(l10n.colNights)),
                    Padding(
                        padding: const EdgeInsets.all(4), child: Text(l10n.colWeekend)),
                  ]),
                  ...result.employeeStats.map((s) => TableRow(children: [
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(employeeNames[s.employeeId] ??
                                s.employeeId)),
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(s.totalHours.toStringAsFixed(1))),
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('${s.shiftCount}')),
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('${s.nightShifts}')),
                        Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text('${s.weekendShifts}')),
                      ])),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.reviewDraft),
        ),
      ],
    );
  }

  Widget _summaryCard(
      BuildContext context, WeekCoverageResult coverage, Color statusColor) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          _stat(l10n.coverage, '${coverage.coveragePercentage.toStringAsFixed(1)}%'),
          _stat(l10n.colScheduled, '${coverage.totalScheduled}/${coverage.totalRequired}'),
          _stat(l10n.missingLabel, '${coverage.totalMissing}'),
          _stat(l10n.extraLabel, '${coverage.totalExtra}'),
          Chip(
            backgroundColor: statusColor,
            label: Text(
              result.isFullyValid ? l10n.valid : l10n.needsReview,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );

  String _area(String areaId) => areaNames[areaId] ?? areaId;
}
