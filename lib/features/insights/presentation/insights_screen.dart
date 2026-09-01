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

/// TRD §17: observations, not judgments. Reuses the same period model
/// as the Life tab (Week/Month/Year, prev/next navigation) since these
/// two screens are two views of the same underlying stats.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  StatsPeriod _period = StatsPeriod.month;
  DateTime _anchor = DateTime.now();

  void _shiftPeriod(int direction) {
    setState(() => _anchor = shiftAnchor(_period, _anchor, direction));
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
        return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
      case StatsPeriod.year:
        return '${_anchor.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(insightsProvider((_period, _anchor)));

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
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
                  _anchor = DateTime.now();
                }),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftPeriod(-1),
                  ),
                  Text(
                    _periodLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shiftPeriod(1),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: insights.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nothing notable yet — check back as you build '
                            'up more history.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: insights.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) =>
                            _InsightCard(insight: insights[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  (IconData, Color) _visualsFor(BuildContext context, InsightKind kind) {
    final scheme = Theme.of(context).colorScheme;
    return switch (kind) {
      InsightKind.improvement => (Icons.trending_up, scheme.primary),
      InsightKind.decline => (Icons.trending_down, scheme.error),
      InsightKind.strongArea => (Icons.star_outline, scheme.primary),
      InsightKind.neglectedArea => (Icons.circle_outlined, scheme.outline),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _visualsFor(context, insight.kind);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${insight.domain.emoji}  ${insight.domain.label}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(insight.message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
