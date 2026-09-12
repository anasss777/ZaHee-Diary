import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/router/app_routes.dart';
import '../../goals/presentation/providers/goal_completion_providers.dart';
import '../../goals/presentation/providers/goal_providers.dart';
import '../../goals/presentation/widgets/goal_tile.dart';
import '../../history/presentation/daily_record_screen.dart';
import '../../moments/presentation/moment_compose_screen.dart';
import '../../reflections/presentation/reflection_compose_screen.dart';

/// The primary screen of the app (TRD §5). Shows today's date, a
/// greeting, per-domain progress, and lets the user complete goals
/// inline without navigating away — that's the whole "10-30 second"
/// core loop the product is built around.
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

  IconData _greetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 18) return Icons.wb_sunny_rounded;
    return Icons.nightlight_round;
  }

  Color _greetingBackgroundColor(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      // Morning — warm golden glow
      return const Color(0xFFFFF3CD);
    }
    if (hour < 18) {
      // Afternoon — sunny yellow/orange
      return const Color(0xFFFFE8B3);
    } // Evening — soft indigo/violet
    return const Color(0xFFE8E5FF);
  }

  Color _greetingIconColor(BuildContext context) {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return const Color(0xFFE6A700);
    }
    if (hour < 18) {
      return const Color(0xFFF28C28);
    }
    return const Color(0xFF6655C7);
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _greetingBackgroundColor(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _greetingIcon(),
                      color: _greetingIconColor(context),
                      size: 24,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _formattedDate(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Today',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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

              const SizedBox(height: 8),

              // ─────────────────────────────────────────────
              // Daily progress
              // ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s progress',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalCompleted == totalGoals
                                    ? 'Everything is done. Nice work!'
                                    : 'Keep going at your own pace.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '$totalCompleted',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5, left: 3),
                          child: Text(
                            '/ $totalGoals',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: totalGoals == 0
                            ? 0
                            : (totalCompleted / totalGoals).clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      '$totalCompleted of $totalGoals goals completed',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─────────────────────────────────────────────
              // Journal
              // ─────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyRecordScreen(date: DateTime.now()),
                    ),
                  ),
                  icon: const Icon(Icons.auto_stories_rounded),
                  label: const Text('View today\'s journal'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─────────────────────────────────────────────
              // Quick capture
              // ─────────────────────────────────────────────
              Text(
                'Capture something',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _QuickCaptureCard(
                      icon: Icons.add_comment_outlined,
                      label: 'Reflection',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReflectionComposeScreen(date: DateTime.now()),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickCaptureCard(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Moment',
                      onTap: () =>
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  MomentComposeScreen(date: DateTime.now()),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final progress = ref.watch(todayProgressByDomainProvider)[domain];

    final isDomainComplete =
        progress != null &&
        progress.total > 0 &&
        progress.completed == progress.total;

    final progressValue = progress == null || progress.total == 0
        ? 0.0
        : (progress.completed / progress.total).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor: Colors.transparent,
          splashColor: colors.primary.withValues(alpha: 0.05),
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: !isDomainComplete,
          tilePadding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(15),
            ),
            alignment: Alignment.center,
            child: Text(domain.emoji, style: const TextStyle(fontSize: 23)),
          ),
          title: Text(
            domain.label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          subtitle: progress != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 5,
                            backgroundColor: colors.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDomainComplete
                                  ? colors.primary
                                  : colors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${progress.completed}/${progress.total}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDomainComplete
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : null,
          children: [
            for (final goal in goals)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GoalTile(goal: goal, showManagementActions: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickCaptureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickCaptureCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: colors.primary),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
