import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal_completion.dart';
import '../../../../core/models/goal_period.dart';
import '../../../../core/models/life_domain.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/providers/goal_completion_providers.dart';
import '../../../goals/presentation/providers/goal_providers.dart';
import '../../../history/presentation/providers/history_providers.dart'
    show monthStart, nextMonthStart;

/// Moves [anchor] forward/backward by one [period] (direction: -1 for
/// previous, +1 for next). Shared by Life's prev/next navigation and
/// Insights' "compare against the previous period" logic — one
/// implementation of "what does 'last month' mean" rather than two that
/// could drift apart.
DateTime shiftAnchor(StatsPeriod period, DateTime anchor, int direction) {
  switch (period) {
    case StatsPeriod.week:
      return anchor.add(Duration(days: 7 * direction));
    case StatsPeriod.month:
      return DateTime(anchor.year, anchor.month + direction, 1);
    case StatsPeriod.year:
      return DateTime(anchor.year + direction, anchor.month, 1);
  }
}

/// TRD §15's three switchable periods.
enum StatsPeriod { week, month, year }

/// The `[start, end)` range for [period], anchored on [anchor] (usually
/// "today," but a distinct parameter so prev/next navigation can shift
/// it without recomputing "today" everywhere).
///
/// Week starts Monday, matching the Mon-first week already used by the
/// Calendar screen (TRD §14) — kept consistent across the app rather
/// than picking a different convention per screen.
(DateTime start, DateTime end) periodRange(
  StatsPeriod period,
  DateTime anchor,
) {
  switch (period) {
    case StatsPeriod.week:
      final normalized = GoalCompletion.normalizeDate(anchor);
      final start = normalized.subtract(Duration(days: normalized.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    case StatsPeriod.month:
      return (monthStart(anchor), nextMonthStart(anchor));
    case StatsPeriod.year:
      return (DateTime(anchor.year, 1, 1), DateTime(anchor.year + 1, 1, 1));
  }
}

/// Every completion within `[start, end)` for the current user, one
/// Firestore listener per call — reuses the same repository method
/// History's month view is built on, just with a caller-chosen range
/// instead of always a calendar month.
final _rangeCompletionsProvider =
    StreamProvider.family<List<GoalCompletion>, (DateTime, DateTime)>((
      ref,
      range,
    ) {
      final userId = ref.watch(authStateChangesProvider).value?.id;
      if (userId == null) return Stream.value(const []);
      return ref
          .watch(goalCompletionRepositoryProvider)
          .watchCompletionsForDateRange(userId, range.$1, range.$2);
    });

/// A domain's completion percentage for a period, or null if there's
/// nothing to measure yet (no currently-active goal in that domain
/// existed during any part of the period) — distinguished from 0% so
/// the UI can show "no goals" instead of a misleading empty bar.
class DomainStat {
  final double? percentage; // 0.0–1.0, or null
  final int completed;
  final int expected;
  const DomainStat({
    required this.percentage,
    required this.completed,
    required this.expected,
  });
}

/// Per-domain stats for [period] anchored on [anchor] (TRD §15/§16).
///
/// FREQUENCY-AWARE: "expected" is counted in each goal's own period unit
/// via [periodsElapsed] — a weekly goal expects ~4 occurrences across a
/// month, not ~30. This now matches the same period model Today and
/// Daily Record use for determining whether a goal is "done."
///
/// "Completed" counts DISTINCT satisfied periods (via each completion's
/// own period-start, deduplicated), not a raw completion-document count.
/// That distinction only matters in a rare edge case: two completion
/// docs landing in the same week/month for one goal (documented as
/// possible-but-unlikely in GoalCompletionActions.complete). Counting
/// distinct periods keeps this provider correct even then, rather than
/// letting `completed` exceed `expected`.
///
/// Only considers currently-active goals (unlike Daily Record's
/// heuristic, which also surfaces archived goals on days they have a
/// completion) — period aggregates read oddly if they include a goal
/// the user no longer has, whereas a single day's history benefits from
/// showing it happened.
final domainStatsProvider =
    Provider.family<Map<LifeDomain, DomainStat>, (StatsPeriod, DateTime)>((
      ref,
      args,
    ) {
      final (period, anchor) = args;
      final (start, end) = periodRange(period, anchor);
      final today = GoalCompletion.normalizeDate(DateTime.now());
      // Never count "expected" occurrences for days that haven't happened
      // yet (e.g. viewing the current, still-in-progress month/week/year).
      final effectiveEnd = end.isAfter(today.add(const Duration(days: 1)))
          ? today.add(const Duration(days: 1))
          : end;

      final goalsByDomain = ref.watch(activeGoalsByDomainProvider);
      final completions =
          ref.watch(_rangeCompletionsProvider((start, end))).value ?? const [];

      final completionsByGoal = <String, List<GoalCompletion>>{};
      for (final c in completions) {
        completionsByGoal.putIfAbsent(c.goalId, () => []).add(c);
      }

      final result = <LifeDomain, DomainStat>{};
      for (final domain in LifeDomain.values) {
        var totalExpected = 0;
        var totalCompleted = 0;

        for (final goal in goalsByDomain[domain] ?? const []) {
          final overlapStart = goal.startDate.isAfter(start)
              ? goal.startDate
              : start;
          if (!overlapStart.isBefore(effectiveEnd)) {
            continue; // no overlap at all
          }

          final expected = periodsElapsed(
            goal.frequency,
            overlapStart,
            effectiveEnd,
          );
          if (expected <= 0) continue;

          final distinctPeriodsSatisfied =
              (completionsByGoal[goal.id] ?? const [])
                  .map((c) => goalPeriodFor(goal.frequency, c.date).$1)
                  .toSet()
                  .length;

          totalExpected += expected;
          // Defensive cap — see this provider's doc comment on why
          // distinctPeriodsSatisfied could, in a rare case, exceed expected.
          totalCompleted += distinctPeriodsSatisfied > expected
              ? expected
              : distinctPeriodsSatisfied;
        }

        result[domain] = DomainStat(
          percentage: totalExpected == 0
              ? null
              : totalCompleted / totalExpected,
          completed: totalCompleted,
          expected: totalExpected,
        );
      }
      return result;
    });
