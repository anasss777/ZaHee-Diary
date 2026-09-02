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

/// TRD §15/§16: per-domain completion percentages, switchable between
/// Week/Month/Year, with prev/next navigation through periods.
class LifeScreen extends ConsumerStatefulWidget {
  const LifeScreen({super.key});

  @override
  ConsumerState<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends ConsumerState<LifeScreen> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();

  void _shiftPeriod(int direction) {
    setState(() => _anchor = shiftAnchor(_period, _anchor, direction));
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
    final stats = ref.watch(domainStatsProvider((_period, _anchor)));
    final hasAnyData = stats.values.any((s) => s.percentage != null);

    return Scaffold(
      appBar: AppBar(title: const Text('My Life')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<StatsPeriod>(
                segments: const [
                  ButtonSegment(value: StatsPeriod.week, label: Text('Week')),
                  ButtonSegment(value: StatsPeriod.month, label: Text('Month')),
                  ButtonSegment(value: StatsPeriod.year, label: Text('Year')),
                ],
                selected: {_period},
                onSelectionChanged: (s) => setState(() {
                  _period = s.first;
                  _anchor = DateTime.now(); // reset to "current" on switch
                }),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous ${_period.name}',
                    onPressed: () => _shiftPeriod(-1),
                  ),
                  Text(
                    _periodLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next ${_period.name}',
                    onPressed: () => _shiftPeriod(1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!hasAnyData)
                Expanded(
                  child: Center(
                    child: Text(
                      'No goals in this period yet',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      for (final domain in LifeDomain.values)
                        _DomainStatRow(domain: domain, stat: stats[domain]!),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DomainStatRow extends StatelessWidget {
  final LifeDomain domain;
  final DomainStat stat;

  const _DomainStatRow({required this.domain, required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = stat.percentage;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${domain.emoji}  ${domain.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                pct == null ? 'No goals' : '${(pct * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            // Plain LinearProgressIndicator jumps instantly between
            // values — wrapping in a tween is what makes switching
            // periods (Week/Month/Year, prev/next) animate the bar
            // sliding to its new length instead of snapping.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct ?? 0),
              duration: motionDuration(
                context,
                const Duration(milliseconds: 400),
              ),
              curve: Curves.easeOut,
              builder: (context, animatedValue, _) => LinearProgressIndicator(
                value: animatedValue,
                minHeight: 10,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
