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

    final hasAnyGoals = goalsByDomain.values.any((goals) => goals.isNotEmpty);

    final hasAnyContent =
        hasAnyGoals || reflections.isNotEmpty || moments.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daily Record',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Add',
            icon: const Icon(Icons.add_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'reflection') {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => ReflectionComposeScreen(date: normalized),
                  ),
                );
              }

              if (value == 'moment') {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => MomentComposeScreen(date: normalized),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reflection',
                child: Row(
                  children: [
                    Icon(Icons.auto_stories_outlined),
                    SizedBox(width: 12),
                    Text('Reflection'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'moment',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined),
                    SizedBox(width: 12),
                    Text('Moment'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: !hasAnyContent
            ? _EmptyDayState(date: normalized)
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ───────────────────────────────────────
                  // Date header
                  // ───────────────────────────────────────
                  _DateHeader(date: normalized),

                  const SizedBox(height: 20),

                  // ───────────────────────────────────────
                  // Overall goal progress
                  // ───────────────────────────────────────
                  if (progress.total > 0)
                    _ProgressCard(
                      completed: progress.completed,
                      total: progress.total,
                    ),

                  if (progress.total > 0) const SizedBox(height: 24),

                  // ───────────────────────────────────────
                  // Goals
                  // ───────────────────────────────────────
                  for (final domain in LifeDomain.values)
                    if (goalsByDomain[domain]!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _DomainRecordSection(
                          domain: domain,
                          goals: goalsByDomain[domain]!,
                          completedById: completedById,
                        ),
                      ),

                  // ───────────────────────────────────────
                  // Reflections
                  // ───────────────────────────────────────
                  if (reflections.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ReflectionsSection(
                      date: normalized,
                      reflections: reflections,
                    ),
                  ],

                  // ───────────────────────────────────────
                  // Moments
                  // ───────────────────────────────────────
                  if (moments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MomentsSection(date: normalized, moments: moments),
                  ],
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Date Header
// ═══════════════════════════════════════════════════════════

class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _monthNames[date.month - 1].substring(0, 3).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${date.day}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weekdayNames[date.weekday - 1],
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_monthNames[date.month - 1]} ${date.year}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Progress Card
// ═══════════════════════════════════════════════════════════

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressCard({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final percentage = total == 0 ? 0.0 : completed / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 8,
                      color: scheme.surfaceContainerHighest,
                    ),
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 8,
                      strokeCap: StrokeCap.round,
                      color: scheme.primary,
                    ),
                    Text(
                      '${(value * 100).round()}%',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s goals',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completed of $total completed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Domain Section
// ═══════════════════════════════════════════════════════════

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final completedCount = goals
        .where((goal) => completedById.containsKey(goal.id))
        .length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    domain.emoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    domain.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$completedCount/${goals.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: scheme.outlineVariant.withValues(alpha: 0.35),
          ),
          for (var i = 0; i < goals.length; i++)
            _GoalRecordRow(
              goal: goals[i],
              completion: completedById[goals[i].id],
              isLast: i == goals.length - 1,
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Goal Row
// ═══════════════════════════════════════════════════════════

class _GoalRecordRow extends StatelessWidget {
  final Goal goal;
  final GoalCompletion? completion;
  final bool isLast;

  const _GoalRecordRow({
    required this.goal,
    required this.completion,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isCompleted = completion != null;

    String? subtitle;

    if (isCompleted &&
        goal.type == GoalType.numeric &&
        completion!.value != null) {
      subtitle = '${completion!.value!.toStringAsFixed(0)} ${goal.unit ?? ''}'
          .trim();
    }

    return Container(
      color: isCompleted
          ? scheme.primaryContainer.withValues(alpha: 0.18)
          : Colors.transparent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_rounded : Icons.circle_outlined,
                    size: isCompleted ? 20 : 18,
                    color: isCompleted
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: isCompleted ? TextDecoration.none : null,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (isCompleted)
                  Icon(Icons.done_all_rounded, size: 19, color: scheme.primary),
              ],
            ),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Reflections
// ═══════════════════════════════════════════════════════════

class _ReflectionsSection extends StatelessWidget {
  final DateTime date;
  final List<Reflection> reflections;

  const _ReflectionsSection({required this.date, required this.reflections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.auto_stories_outlined,
                    color: scheme.onTertiaryContainer,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reflections',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${reflections.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            for (var i = 0; i < reflections.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == reflections.length - 1 ? 0 : 12,
                ),
                child: _EntryCard(
                  emoji: reflections[i].domainId?.emoji ?? '📝',
                  title: reflections[i].content,
                  subtitle: reflections[i].domainId?.label ?? 'Whole day',
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => ReflectionComposeScreen(
                          date: date,
                          existing: reflections[i],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Moments
// ═══════════════════════════════════════════════════════════

class _MomentsSection extends StatelessWidget {
  final DateTime date;
  final List<Moment> moments;

  const _MomentsSection({required this.date, required this.moments});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.auto_awesome_outlined,
                    color: scheme.onSecondaryContainer,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Moments',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${moments.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            for (var i = 0; i < moments.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == moments.length - 1 ? 0 : 12,
                ),
                child: _EntryCard(
                  emoji: moments[i].domainId?.emoji ?? '✨',
                  title: moments[i].title?.isNotEmpty == true
                      ? moments[i].title!
                      : moments[i].content,
                  subtitle: moments[i].title?.isNotEmpty == true
                      ? moments[i].content
                      : null,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => MomentComposeScreen(
                          date: date,
                          existing: moments[i],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Generic entry card
// ═══════════════════════════════════════════════════════════

class _EntryCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _EntryCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 21)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════

class _EmptyDayState extends StatelessWidget {
  final DateTime date;

  const _EmptyDayState({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 38,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'A blank page',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nothing was recorded for this day yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_weekdayNames[date.weekday - 1]}, '
              '${_monthNames[date.month - 1]} ${date.day}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
