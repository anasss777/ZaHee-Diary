import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/goal_completion.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/models/moment.dart';
import '../../../core/models/reflection.dart';
import '../../goals/presentation/providers/goal_completion_providers.dart';
import '../../moments/presentation/moment_compose_screen.dart';
import '../../moments/presentation/providers/moment_providers.dart';
import '../../reflections/presentation/providers/reflection_providers.dart';
import '../../reflections/presentation/reflection_compose_screen.dart';
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
/// to that day (read-only — see goalsForDateProvider's own doc comment
/// on the historical-reconstruction heuristic this relies on), plus
/// whatever reflections and moments were recorded for it (both CAN be
/// added/edited/deleted from here, unlike the goals section).
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
    final reflections =
        ref.watch(reflectionsForDateProvider(normalized)).value ?? const [];
    final moments =
        ref.watch(momentsForDateProvider(normalized)).value ?? const [];

    final hasAnyGoals = goalsByDomain.values.any((g) => g.isNotEmpty);
    final hasAnyContent =
        hasAnyGoals || reflections.isNotEmpty || moments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_weekdayNames[normalized.weekday - 1]}, '
          '${_monthNames[normalized.month - 1]} ${normalized.day}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Add reflection',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ReflectionComposeScreen(date: normalized),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Add moment',
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => MomentComposeScreen(date: normalized),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: !hasAnyContent
            ? const Center(child: Text('Nothing recorded for this day'))
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
                  if (reflections.isNotEmpty)
                    _ReflectionsSection(
                      date: normalized,
                      reflections: reflections,
                    ),
                  if (moments.isNotEmpty)
                    _MomentsSection(date: normalized, moments: moments),
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
        color: isCompleted ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(goal.title),
      subtitle: subtitle != null ? Text(subtitle) : null,
    );
  }
}

class _ReflectionsSection extends StatelessWidget {
  final DateTime date;
  final List<Reflection> reflections;

  const _ReflectionsSection({required this.date, required this.reflections});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Reflections',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final reflection in reflections)
          ListTile(
            leading: Text(
              reflection.domainId?.emoji ?? '📝',
              style: const TextStyle(fontSize: 20),
            ),
            title: Text(reflection.content),
            subtitle: Text(reflection.domainId?.label ?? 'Whole day'),
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) =>
                    ReflectionComposeScreen(date: date, existing: reflection),
              ),
            ),
          ),
      ],
    );
  }
}

class _MomentsSection extends StatelessWidget {
  final DateTime date;
  final List<Moment> moments;

  const _MomentsSection({required this.date, required this.moments});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Moments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final moment in moments)
          ListTile(
            leading: Text(
              moment.domainId?.emoji ?? '✨',
              style: const TextStyle(fontSize: 20),
            ),
            title: Text(
              moment.title?.isNotEmpty == true ? moment.title! : moment.content,
            ),
            subtitle: moment.title?.isNotEmpty == true
                ? Text(
                    moment.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            onTap: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) =>
                    MomentComposeScreen(date: date, existing: moment),
              ),
            ),
          ),
      ],
    );
  }
}
