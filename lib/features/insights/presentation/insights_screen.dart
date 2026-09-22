import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../life/presentation/providers/life_stats_providers.dart';
import 'providers/insights_providers.dart';

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

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = shiftAnchor(_period, _anchor, direction);
    });
  }

  void _selectPeriod(StatsPeriod period) {
    setState(() {
      _period = period;
      _anchor = DateTime.now();
    });
  }

  String get _periodLabel {
    switch (_period) {
      case StatsPeriod.week:
        final (start, end) = periodRange(_period, _anchor);

        final lastDay = end.subtract(const Duration(days: 1));

        return '${_monthNames[start.month - 1]} ${start.day} – '
            '${start.month == lastDay.month ? '' : '${_monthNames[lastDay.month - 1]} '}'
            '${lastDay.day}';

      case StatsPeriod.month:
        return '${_monthNames[_anchor.month - 1]} '
            '${_anchor.year}';

      case StatsPeriod.year:
        return '${_anchor.year}';
    }
  }

  String get _periodDescription {
    switch (_period) {
      case StatsPeriod.week:
        return 'What changed this week';
      case StatsPeriod.month:
        return 'What stood out this month';
      case StatsPeriod.year:
        return 'What stood out this year';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final insights = ref.watch(insightsProvider((_period, _anchor)));

    final improvementCount = insights
        .where((i) => i.kind == InsightKind.improvement)
        .length;

    final strongAreaCount = insights
        .where((i) => i.kind == InsightKind.strongArea)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Insights',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ─────────────────────────────────────────
            // Intro
            // ─────────────────────────────────────────
            Text(
              'A look at your patterns',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'These observations can help you notice '
              'what is changing across your life.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 22),

            // ─────────────────────────────────────────
            // Period selector
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(4),

              child: SegmentedButton<StatsPeriod>(
                segments: const [
                  ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
                  ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
                  ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
                ],
                selected: {_period},
                showSelectedIcon: false,
                style: ButtonStyle(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(vertical: 11),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onSelectionChanged: (selection) {
                  _selectPeriod(selection.first);
                },
              ),
            ),

            const SizedBox(height: 18),

            // ─────────────────────────────────────────
            // Period navigation
            // ─────────────────────────────────────────
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Previous ${_period.name}',
                  onPressed: () => _shiftPeriod(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),

                Expanded(
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _periodLabel,
                          key: ValueKey(_periodLabel),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _periodDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton.filledTonal(
                  tooltip: 'Next ${_period.name}',
                  onPressed: () => _shiftPeriod(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 26),

            if (insights.isEmpty)
              const _EmptyInsights()
            else ...[
              // ───────────────────────────────────────
              // Summary
              // ───────────────────────────────────────
              _InsightSummary(
                total: insights.length,
                improvements: improvementCount,
                strongAreas: strongAreaCount,
              ),

              const SizedBox(height: 24),

              // ───────────────────────────────────────
              // Section heading
              // ───────────────────────────────────────
              Text(
                'Observations',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 12),

              // ───────────────────────────────────────
              // Insights
              // ───────────────────────────────────────
              for (var i = 0; i < insights.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == insights.length - 1 ? 0 : 12,
                  ),
                  child: _InsightCard(insight: insights[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════

class _InsightSummary extends StatelessWidget {
  final int total;
  final int improvements;
  final int strongAreas;

  const _InsightSummary({
    required this.total,
    required this.improvements,
    required this.strongAreas,
  });

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
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: scheme.onPrimary,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total ${total == 1 ? 'observation' : 'observations'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildSummary(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.72),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildSummary() {
    if (improvements > 0 && strongAreas > 0) {
      return '$improvements improving · '
          '$strongAreas strong ${strongAreas == 1 ? 'area' : 'areas'}';
    }

    if (improvements > 0) {
      return '$improvements improving '
          '${improvements == 1 ? 'area' : 'areas'}';
    }

    if (strongAreas > 0) {
      return '$strongAreas strong '
          '${strongAreas == 1 ? 'area' : 'areas'}';
    }

    return 'Patterns from your recent activity';
  }
}

// ═══════════════════════════════════════════════════════════
// Insight Card
// ═══════════════════════════════════════════════════════════

class _InsightCard extends StatelessWidget {
  final Insight insight;

  const _InsightCard({required this.insight});

  ({IconData icon, Color color, Color background}) _visualsFor(
    BuildContext context,
    InsightKind kind,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return switch (kind) {
      InsightKind.improvement => (
        icon: Icons.trending_up_rounded,
        color: scheme.primary,
        background: scheme.primaryContainer,
      ),
      InsightKind.decline => (
        icon: Icons.trending_down_rounded,
        color: scheme.error,
        background: scheme.errorContainer,
      ),
      InsightKind.strongArea => (
        icon: Icons.star_rounded,
        color: scheme.tertiary,
        background: scheme.tertiaryContainer,
      ),
      InsightKind.neglectedArea => (
        icon: Icons.circle_outlined,
        color: scheme.onSurfaceVariant,
        background: scheme.surfaceContainerHighest,
      ),
    };
  }

  String _kindLabel(InsightKind kind) {
    return switch (kind) {
      InsightKind.improvement => 'Improving',
      InsightKind.decline => 'Changing',
      InsightKind.strongArea => 'Strong area',
      InsightKind.neglectedArea => 'Less active',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final visuals = _visualsFor(context, insight.kind);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visuals.background,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(visuals.icon, color: visuals.color, size: 23),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      insight.domain.emoji,
                      style: const TextStyle(fontSize: 17),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        insight.domain.label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 7),

                Text(
                  insight.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: visuals.background.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    _kindLabel(insight.kind),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: visuals.color,
                      fontWeight: FontWeight.w700,
                    ),
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
// Empty state
// ═══════════════════════════════════════════════════════════

class _EmptyInsights extends StatelessWidget {
  const _EmptyInsights();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 70, left: 20, right: 20),
      child: Column(
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
              Icons.auto_awesome_rounded,
              size: 38,
              color: scheme.primary,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            'Your story is still unfolding',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Keep using your goals and journal. '
            'As more history builds up, patterns '
            'will become easier to notice.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
