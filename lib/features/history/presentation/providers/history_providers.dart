import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/goal_completion.dart';
import '../../../../core/models/life_domain.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../goals/presentation/providers/goal_completion_providers.dart';
import '../../../goals/presentation/providers/goal_providers.dart';

// NOTE: none of the .family providers below are .autoDispose. That's
// fine for now — a user browsing a handful of months in one session
// won't notice — but if History grows a "jump to any past month"
// feature, revisit this: each visited month/day currently stays cached
// in the provider container for the app's lifetime rather than being
// released when no longer watched.

/// The first day of [date]'s month, normalized to midnight.
DateTime monthStart(DateTime date) => DateTime(date.year, date.month, 1);

/// The first day of the month *after* [date]'s month — used as the
/// exclusive upper bound for a date-range query.
DateTime nextMonthStart(DateTime date) => date.month == 12
    ? DateTime(date.year + 1, 1, 1)
    : DateTime(date.year, date.month + 1, 1);

/// Every completion within the month containing [monthAnchor], keyed by
/// normalized date. One Firestore listener per visible month rather
/// than one per visible day.
final monthCompletionsProvider =
    StreamProvider.family<Map<DateTime, List<GoalCompletion>>, DateTime>((
      ref,
      monthAnchor,
    ) {
      final userId = ref.watch(authStateChangesProvider).value?.id;
      if (userId == null) return Stream.value(const {});

      final repo = ref.watch(goalCompletionRepositoryProvider);
      final start = monthStart(monthAnchor);
      final end = nextMonthStart(monthAnchor);

      return repo.watchCompletionsForDateRange(userId, start, end).map((all) {
        final byDate = <DateTime, List<GoalCompletion>>{};
        for (final completion in all) {
          byDate.putIfAbsent(completion.date, () => []).add(completion);
        }
        return byDate;
      });
    });

/// Which goals "count" for a given day, grouped by domain.
///
/// FREQUENCY-AWARE, with a deliberate asymmetry between daily and
/// weekly/monthly goals:
///  - Daily/custom goals use the heuristic below (existed by this day,
///    and currently active or has a completion this day) — shown every
///    day, matching how they actually work.
///  - Weekly/monthly goals are shown ONLY on the day they were actually
///    completed. They are NOT shown as "still pending" on every other
///    day of their period — since a weekly goal is satisfiable on any
///    one of 7 days, repeating it as an unchecked item on all 7 would
///    clutter what's meant to be a day-by-day journal of what actually
///    happened, not a nagging list of everything not yet done. This
///    means Daily Record never surfaces "you missed this weekly goal" —
///    it only ever shows successes for non-daily goals. A reasonable,
///    bounded scope choice, not an oversight.
///
/// Uses [completionsForDateProvider] from goal_completion_providers.dart
/// (a single-date live listener, EXACT-day match) rather than slicing
/// the month bucket above — appropriate here because this provider
/// backs the DAILY RECORD screen, where only one date is ever open at a
/// time, and because "exact day" is precisely what both branches above
/// need. The calendar GRID (many days at once) uses
/// [monthDayProgressProvider] below instead, which derives from the one
/// month-range listener specifically to avoid opening up to 31 separate
/// per-day listeners.
///
/// Separately, for daily/custom goals: HEURISTIC, not a perfect
/// historical reconstruction. A goal counts for [date] if it existed by
/// then (`startDate <= date`) AND EITHER it's still active today OR it
/// has a completion recorded on that date. This is a deliberate
/// compromise — `archiveGoal()` only flips `isActive`, it never records
/// *when* archiving happened (TRD's data model doesn't call for an
/// `archivedAt` timestamp), so there's no way to know precisely whether
/// a since-archived goal was still active on some past date. The
/// practical effect: browsing history shows an archived goal on days it
/// has a completion (so past progress isn't erased), but not on days it
/// doesn't (so old history isn't cluttered with goals long since
/// dropped). Good enough for the MVP; a fully accurate version would
/// need goals to track their own archive date.
final goalsForDateProvider =
    Provider.family<Map<LifeDomain, List<Goal>>, DateTime>((ref, date) {
      final normalized = GoalCompletion.normalizeDate(date);
      final allGoals = ref.watch(allGoalsProvider).value ?? const [];
      final completions =
          ref.watch(completionsForDateProvider(normalized)).value ?? const {};
      final completedGoalIds = completions.keys.toSet();

      final relevant = allGoals.where((g) {
        if (g.startDate.isAfter(normalized)) return false;

        if (g.frequency == GoalFrequency.daily ||
            g.frequency == GoalFrequency.custom) {
          return g.isActive || completedGoalIds.contains(g.id);
        }

        // Weekly/monthly — see this provider's doc comment above.
        return completedGoalIds.contains(g.id);
      });

      final grouped = <LifeDomain, List<Goal>>{
        for (final domain in LifeDomain.values) domain: [],
      };
      for (final goal in relevant) {
        grouped[goal.domainId]!.add(goal);
      }
      return grouped;
    });

/// Aggregate completed/total for one day, built on the same heuristic as
/// [goalsForDateProvider] — used for the daily detail screen's header
/// count.
final dayProgressProvider = Provider.family<DomainProgress, DateTime>((
  ref,
  date,
) {
  final normalized = GoalCompletion.normalizeDate(date);
  final goalsByDomain = ref.watch(goalsForDateProvider(normalized));
  final completions =
      ref.watch(completionsForDateProvider(normalized)).value ?? const {};
  final completedGoalIds = completions.keys.toSet();

  final allRelevant = goalsByDomain.values.expand((g) => g);
  final total = allRelevant.length;
  final completed = allRelevant
      .where((g) => completedGoalIds.contains(g.id))
      .length;
  return DomainProgress(completed, total);
});

/// Per-day progress for every day in the month containing [monthAnchor]
/// — what the calendar grid's dots/shading are driven by. Derived
/// directly from [monthCompletionsProvider]'s single month-range
/// listener (NOT from [dayProgressProvider]/[completionsForDateProvider]
/// above) — that distinction is the whole point: rendering ~30 days
/// must not open ~30 separate Firestore listeners.
///
/// Uses the SAME frequency-aware filter as [goalsForDateProvider] above
/// (daily/custom shown every day; weekly/monthly only on days actually
/// completed) — duplicated here rather than calling that provider,
/// specifically to stay within the single month-range listener rather
/// than opening one per day.
final monthDayProgressProvider =
    Provider.family<Map<DateTime, DomainProgress>, DateTime>((
      ref,
      monthAnchor,
    ) {
      final allGoals = ref.watch(allGoalsProvider).value ?? const [];
      final monthCompletions =
          ref.watch(monthCompletionsProvider(monthAnchor)).value ?? const {};

      final start = monthStart(monthAnchor);
      final end = nextMonthStart(monthAnchor);
      final daysInMonth = end.difference(start).inDays;

      final result = <DateTime, DomainProgress>{};
      for (var i = 0; i < daysInMonth; i++) {
        final day = start.add(Duration(days: i));
        final dayCompletions = monthCompletions[day] ?? const [];
        final completedGoalIds = dayCompletions.map((c) => c.goalId).toSet();

        final relevant = allGoals.where((g) {
          if (g.startDate.isAfter(day)) return false;
          if (g.frequency == GoalFrequency.daily ||
              g.frequency == GoalFrequency.custom) {
            return g.isActive || completedGoalIds.contains(g.id);
          }
          return completedGoalIds.contains(g.id);
        });

        result[day] = DomainProgress(
          relevant.where((g) => completedGoalIds.contains(g.id)).length,
          relevant.length,
        );
      }
      return result;
    });
