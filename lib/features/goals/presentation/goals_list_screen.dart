import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/router/app_routes.dart';
import 'goal_form_screen.dart';
import 'providers/goal_completion_providers.dart';
import 'providers/goal_providers.dart';
import 'widgets/goal_tile.dart';

/// Lists every active goal grouped by domain, with create/edit/archive.
/// This is a working management screen, not the Today screen (that's a
/// separate, completion-focused view built in the next milestone).
class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allGoalsAsync = ref.watch(allGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Manage subsections',
            onPressed: () => context.push(AppRoutes.subcategories),
          ),
        ],
      ),
      body: allGoalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load goals: $err')),
        data: (goals) {
          final grouped = ref.watch(activeGoalsByDomainProvider);
          final hasAnyActiveGoal = grouped.values.any((g) => g.isNotEmpty);

          if (!hasAnyActiveGoal) {
            return const _EmptyState();
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final domain in LifeDomain.values)
                if (grouped[domain]!.isNotEmpty)
                  _DomainSection(domain: domain, goals: grouped[domain]!),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const GoalFormScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No goals yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start small. You can always add more later.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainSection extends ConsumerWidget {
  final LifeDomain domain;
  final List<Goal> goals;

  const _DomainSection({required this.domain, required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final progress = ref.watch(todayProgressByDomainProvider)[domain];

    final isComplete =
        progress != null &&
        progress.total > 0 &&
        progress.completed == progress.total;

    final progressValue = progress == null || progress.total == 0
        ? 0.0
        : (progress.completed / progress.total).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: colors.primaryFixedDim.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primaryContainer.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─────────────────────────────────────
              // Domain header
              // ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        domain.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            domain.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (progress != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              isComplete
                                  ? 'Completed'
                                  : '${progress.completed} of ${progress.total} completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isComplete
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: isComplete ? FontWeight.w600 : null,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    if (progress != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isComplete
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${progress.completed}/${progress.total}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isComplete
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ─────────────────────────────────────
              // Domain progress
              // ─────────────────────────────────────
              if (progress != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 5,
                      backgroundColor: colors.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // ─────────────────────────────────────
              // Goals
              // ─────────────────────────────────────
              for (final goal in goals)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: GoalTile(goal: goal),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
