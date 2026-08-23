import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/router/app_routes.dart';
import '../../goals/presentation/providers/goal_completion_providers.dart';
import '../../goals/presentation/providers/goal_providers.dart';
import '../../goals/presentation/widgets/goal_tile.dart';

/// The primary screen of the app (TRD §5). Shows today's date, a
/// greeting, per-domain progress, and lets the user complete goals
/// inline without navigating away — that's the whole "10-30 second"
/// core loop the product is built around.
///
/// NOTE: this screen isn't yet wrapped in the bottom-nav shell
/// (Today / Life / History / Insights tabs) described in the project's
/// milestone plan. That shell is its own small piece of work, separate
/// from this screen's content, and hasn't been built yet — for now this
/// is reached directly via the router's /today route.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning.';
    if (hour < 18) return 'Good afternoon.';
    return 'Good evening.';
  }

  String _formattedDate() {
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
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
    final now = DateTime.now();
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsByDomain = ref.watch(activeGoalsByDomainProvider);
    final progressByDomain = ref.watch(todayProgressByDomainProvider);

    final totalCompleted = progressByDomain.values.fold(
      0,
      (sum, p) => sum + p.completed,
    );
    final totalGoals = progressByDomain.values.fold(
      0,
      (sum, p) => sum + p.total,
    );
    final hasAnyGoals = totalGoals > 0;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_outlined),
            tooltip: 'Manage goals',
            onPressed: () => context.push(AppRoutes.goals),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(_greeting(), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              _formattedDate(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),

            if (!hasAnyGoals)
              const _NoGoalsYetCard()
            else ...[
              for (final domain in LifeDomain.values)
                if (goalsByDomain[domain]!.isNotEmpty)
                  _DomainExpansion(
                    domain: domain,
                    goals: goalsByDomain[domain]!,
                  ),

              const Divider(height: 32),

              Center(
                child: Text(
                  '$totalCompleted / $totalGoals goals completed',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 24),

              // Journal, reflections, and moments aren't built yet
              // (TRD §11-13) — these surface the intended entry points
              // now so the layout matches the product design, without
              // blocking this screen on features that come later.
              OutlinedButton(
                onPressed: () => _showComingSoon(context, "Today's journal"),
                child: const Text("View today's journal"),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => _showComingSoon(context, 'Reflections'),
                    icon: const Icon(Icons.add),
                    label: const Text('Reflection'),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _showComingSoon(context, 'Moments'),
                    icon: const Icon(Icons.add),
                    label: const Text('Moment'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming in a future milestone')),
    );
  }
}

class _NoGoalsYetCard extends StatelessWidget {
  const _NoGoalsYetCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No goals yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              "This isn't a diary — it's a simple way to keep track of "
              'the life you\'re trying to build. Add your first goal to '
              'get started.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.push(AppRoutes.goals),
              child: const Text('Add a goal'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One domain's row (emoji, label, X/Y count) that expands in place to
/// show its goals with completion checkboxes — no navigation required
/// to complete a goal from Today.
class _DomainExpansion extends ConsumerWidget {
  final LifeDomain domain;
  final List<Goal> goals;

  const _DomainExpansion({required this.domain, required this.goals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(todayProgressByDomainProvider)[domain];
    final isDomainComplete =
        progress != null &&
        progress.total > 0 &&
        progress.completed == progress.total;

    return Theme(
      // Removes the default divider ExpansionTile draws, which looks
      // noisy stacked four times in a row on this screen.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: !isDomainComplete,
        tilePadding: EdgeInsets.zero,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${domain.emoji}  ${domain.label}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (progress != null)
              Text(
                '${progress.completed} / ${progress.total}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDomainComplete
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
          ],
        ),
        children: [
          for (final goal in goals)
            GoalTile(goal: goal, showManagementActions: false),
        ],
      ),
    );
  }
}
