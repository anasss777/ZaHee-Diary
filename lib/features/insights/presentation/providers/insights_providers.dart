import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/life_domain.dart';
import '../../../life/presentation/providers/life_stats_providers.dart';

/// TRD §17's categories, kept purely for icon/color differentiation in
/// the UI — never for wording. The message text is identical in style
/// for a "strong area" and a "neglected area" (just the two numbers,
/// stated plainly); TRD is explicit that judgmental phrasing like "you
/// are failing at X" is exactly what this feature must avoid.
enum InsightKind { improvement, decline, strongArea, neglectedArea }

class Insight {
  final LifeDomain domain;
  final InsightKind kind;
  final String message;
  const Insight({required this.domain, required this.kind, required this.message});
}

// Named thresholds rather than magic numbers inline — makes "what
// counts as notable" easy to find and adjust in one place.
const _significantChangePoints = 15; // percentage points, current vs previous
const _strongAreaThreshold = 0.80;
const _neglectedThreshold = 0.30;
// Below this many expected occurrences, a percentage is more noise than
// signal (1 expected, 1 completed = 100%; 1 expected, 0 completed = 0%
// — neither tells you much). Skips strong/neglected classification for
// very sparse data. Improvement/decline still applies below this
// threshold, since that's about the SIZE of the change, not the
// absolute number.
const _minExpectedForAbsoluteInsight = 3;

/// Insights for [period] anchored on [anchor], comparing it against the
/// immediately preceding period of the same length (TRD §17).
///
/// Deliberately rule-based and deterministic — no AI/LLM involved here.
/// TRD §17 (this) and §18 (AI features) are separate, and §18 is
/// explicit that AI is optional/secondary; nothing here calls out to a
/// model. Every message states two numbers the user can independently
/// verify against the Life tab, matching TRD §17's own "Better:"
/// example rather than the "Bad:" framing it warns against.
///
/// At most ONE insight per domain per period — if a domain both changed
/// significantly AND crossed the strong/neglected threshold, only the
/// change is surfaced (it's the more specific, more recent signal).
/// Avoids the app ever showing two insights about the same domain at
/// once, which would read as noisier and more "productivity app nagging
/// you" than TRD's stated product feel allows for.
final insightsProvider =
    Provider.family<List<Insight>, (StatsPeriod, DateTime)>((ref, args) {
  final (period, anchor) = args;
  final previousAnchor = shiftAnchor(period, anchor, -1);

  final current = ref.watch(domainStatsProvider((period, anchor)));
  final previous = ref.watch(domainStatsProvider((period, previousAnchor)));

  final periodLabel = switch (period) {
    StatsPeriod.week => 'this week',
    StatsPeriod.month => 'this month',
    StatsPeriod.year => 'this year',
  };
  final previousLabel = switch (period) {
    StatsPeriod.week => 'last week',
    StatsPeriod.month => 'last month',
    StatsPeriod.year => 'last year',
  };

  final insights = <Insight>[];

  for (final domain in LifeDomain.values) {
    final currentStat = current[domain];
    final previousStat = previous[domain];
    if (currentStat?.percentage == null) continue; // nothing measurable yet

    final currentPct = currentStat!.percentage!;

    if (previousStat?.percentage != null) {
      final previousPct = previousStat!.percentage!;
      final deltaPoints = ((currentPct - previousPct) * 100).round();

      if (deltaPoints >= _significantChangePoints) {
        insights.add(Insight(
          domain: domain,
          kind: InsightKind.improvement,
          message: 'You completed ${(currentPct * 100).round()}% of your '
              '${domain.label} goals $periodLabel, compared with '
              '${(previousPct * 100).round()}% $previousLabel.',
        ));
        continue;
      }
      if (deltaPoints <= -_significantChangePoints) {
        insights.add(Insight(
          domain: domain,
          kind: InsightKind.decline,
          message: 'Your ${domain.label} goals were completed less '
              'frequently $periodLabel than $previousLabel — '
              '${(currentPct * 100).round()}% compared with '
              '${(previousPct * 100).round()}%.',
        ));
        continue;
      }
    }

    if (currentStat.expected < _minExpectedForAbsoluteInsight) continue;

    if (currentPct >= _strongAreaThreshold) {
      insights.add(Insight(
        domain: domain,
        kind: InsightKind.strongArea,
        message: 'You completed ${(currentPct * 100).round()}% of your '
            '${domain.label} goals $periodLabel.',
      ));
    } else if (currentPct <= _neglectedThreshold) {
      insights.add(Insight(
        domain: domain,
        kind: InsightKind.neglectedArea,
        message: 'You completed ${(currentPct * 100).round()}% of your '
            '${domain.label} goals $periodLabel.',
      ));
    }
  }

  return insights;
});
