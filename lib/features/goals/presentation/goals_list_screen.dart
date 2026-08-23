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
    final progress = ref.watch(todayProgressByDomainProvider)[domain];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${domain.emoji}  ${domain.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (progress != null)
                Text(
                  '${progress.completed} / ${progress.total}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          ),
        ),
        for (final goal in goals) GoalTile(goal: goal),
      ],
    );
  }
}
