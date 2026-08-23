import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/goal_completion.dart';
import '../../../core/models/life_domain.dart';
import '../../goals/presentation/providers/goal_completion_providers.dart';
import 'providers/history_providers.dart';

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// A single day's auto-generated record (TRD §13): every goal relevant
/// to that day, grouped by domain, with a check or a dash showing
/// whether it was completed.
///
/// Deliberately READ-ONLY. TRD §13 frames this as a generated summary
/// of what happened, not an editing surface — and Reflections/Moments
/// (also part of the §13 mockup) aren't built yet, so this screen only
/// shows the goals section for now.
class DailyRecordScreen extends ConsumerWidget {
  final DateTime date;
  const DailyRecordScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalized = GoalCompletion.normalizeDate(date);
    final goalsByDomain = ref.watch(goalsForDateProvider(normalized));
    final completedById =
        ref.watch(completionsForDateProvider(normalized)).value ?? const {};
    final progress = ref.watch(dayProgressProvider(normalized));

    final hasAnyGoals = goalsByDomain.values.any((g) => g.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_weekdayNames[normalized.weekday - 1]}, '
          '${_monthNames[normalized.month - 1]} ${normalized.day}',
        ),
      ),
      body: SafeArea(
        child: !hasAnyGoals
            ? const Center(child: Text('No goals recorded for this day'))
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (progress.total > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Text(
                        '${progress.completed} / ${progress.total} goals completed',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  for (final domain in LifeDomain.values)
                    if (goalsByDomain[domain]!.isNotEmpty)
                      _DomainRecordSection(
                        domain: domain,
                        goals: goalsByDomain[domain]!,
                        completedById: completedById,
                      ),
                ],
              ),
      ),
    );
  }
}

class _DomainRecordSection extends StatelessWidget {
  final LifeDomain domain;
  final List<Goal> goals;
  final Map<String, GoalCompletion> completedById;

  const _DomainRecordSection({
    required this.domain,
    required this.goals,
    required this.completedById,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${domain.emoji}  ${domain.label}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final goal in goals)
          _GoalRecordRow(goal: goal, completion: completedById[goal.id]),
      ],
    );
  }
}

class _GoalRecordRow extends StatelessWidget {
  final Goal goal;
  final GoalCompletion? completion;

  const _GoalRecordRow({required this.goal, required this.completion});

  @override
  Widget build(BuildContext context) {
    final isCompleted = completion != null;
    final scheme = Theme.of(context).colorScheme;

    String? subtitle;
    if (isCompleted &&
        goal.type == GoalType.numeric &&
        completion!.value != null) {
      subtitle = '${completion!.value!.toStringAsFixed(0)} ${goal.unit ?? ''}';
    }

    return ListTile(
      dense: true,
      leading: Icon(
        isCompleted ? Icons.check_circle : Icons.circle_outlined,
        color: isCompleted ? scheme.primary : scheme.outline,
      ),
      title: Text(goal.title),
      subtitle: subtitle != null ? Text(subtitle) : null,
    );
  }
}
