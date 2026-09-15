import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/utils/motion.dart';
import 'providers/life_stats_providers.dart';

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

class LifeScreen extends ConsumerStatefulWidget {
  const LifeScreen({super.key});

  @override
  ConsumerState<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends ConsumerState<LifeScreen> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = shiftAnchor(_period, _anchor, direction);
    });
  }

  String get _periodLabel {
    final (start, end) = periodRange(_period, _anchor);
    final lastDay = end.subtract(const Duration(days: 1));

    switch (_period) {
      case StatsPeriod.week:
        return '${_monthNames[start.month - 1]} ${start.day} – '
            '${start.month == lastDay.month ? '' : '${_monthNames[lastDay.month - 1]} '}'
            '${lastDay.day}';

      case StatsPeriod.month:
        return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';

      case StatsPeriod.year:
        return '${_anchor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stats = ref.watch(domainStatsProvider((_period, _anchor)));

    final availableStats = stats.values
        .where((stat) => stat.percentage != null)
        .toList();

    final hasAnyData = availableStats.isNotEmpty;

    final overallPercentage = hasAnyData
        ? availableStats
                  .map((stat) => stat.percentage!)
                  .reduce((a, b) => a + b) /
              availableStats.length
        : 0.0;

    final completedDomains = availableStats
        .where((stat) => stat.percentage! >= 1.0)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Life',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // ─────────────────────────────────────────────
            // Period selector
            // ─────────────────────────────────────────────
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
                  visualDensity: VisualDensity.compact,
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
                  setState(() {
                    _period = selection.first;
                    _anchor = DateTime.now();
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─────────────────────────────────────────────
            // Period navigation
            // ─────────────────────────────────────────────
            Row(
              children: [
                _PeriodButton(
                  icon: Icons.chevron_left_rounded,
                  tooltip: 'Previous ${_period.name}',
                  onPressed: () => _shiftPeriod(-1),
                ),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 250),
                    ),
                    child: Text(
                      _periodLabel,
                      key: ValueKey(_periodLabel),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                _PeriodButton(
                  icon: Icons.chevron_right_rounded,
                  tooltip: 'Next ${_period.name}',
                  onPressed: () => _shiftPeriod(1),
                ),
              ],
            ),

            const SizedBox(height: 28),

            if (!hasAnyData)
              _EmptyState()
            else ...[
              // ─────────────────────────────────────────────
              // Overall progress card
              // ─────────────────────────────────────────────
              _OverallProgressCard(
                percentage: overallPercentage,
                completedDomains: completedDomains,
                totalDomains: availableStats.length,
              ),

              const SizedBox(height: 28),

              Text(
                'Life domains',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              // ─────────────────────────────────────────────
              // Domain cards
              // ─────────────────────────────────────────────
              for (final domain in LifeDomain.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DomainStatCard(domain: domain, stat: stats[domain]!),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Period button
// ═══════════════════════════════════════════════════════════

class _PeriodButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PeriodButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 22,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Overall progress
// ═══════════════════════════════════════════════════════════

class _OverallProgressCard extends StatelessWidget {
  final double percentage;
  final int completedDomains;
  final int totalDomains;

  const _OverallProgressCard({
    required this.percentage,
    required this.completedDomains,
    required this.totalDomains,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final percentText = '${(percentage * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percentage),
            duration: motionDuration(
              context,
              const Duration(milliseconds: 600),
            ),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 9,
                        color: colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      percentText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 20),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$completedDomains of $totalDomains domains completed',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.75,
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
// Domain card
// ═══════════════════════════════════════════════════════════

class _DomainStatCard extends StatelessWidget {
  final LifeDomain domain;
  final DomainStat stat;

  const _DomainStatCard({required this.domain, required this.stat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final pct = stat.percentage;
    final value = pct ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryFixedDim.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          // Domain icon
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(domain.emoji, style: const TextStyle(fontSize: 25)),
          ),

          const SizedBox(width: 16),

          // Name + progress bar
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
                const SizedBox(height: 9),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: value),
                    duration: motionDuration(
                      context,
                      const Duration(milliseconds: 450),
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedValue, _) {
                      return LinearProgressIndicator(
                        value: animatedValue,
                        minHeight: 7,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Percentage
          AnimatedSwitcher(
            duration: motionDuration(
              context,
              const Duration(milliseconds: 250),
            ),
            child: Text(
              pct == null ? '—' : '${(pct * 100).round()}%',
              key: ValueKey(pct),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: pct == null
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.primary,
              ),
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 34,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nothing here yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some goals to see your\nlife progress here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
