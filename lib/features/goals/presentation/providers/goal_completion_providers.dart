import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/goal_completion.dart';
import '../../../../core/models/goal_period.dart';
import '../../../../core/models/life_domain.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/goal_completion_repository.dart';
import 'goal_providers.dart';

final goalCompletionRepositoryProvider = Provider<GoalCompletionRepository>((
  ref,
) {
  return GoalCompletionRepository();
});

/// "Today", as a provider rather than a bare `DateTime.now()` call
/// scattered through the UI. Two reasons this matters:
///  1. It's the single place that will need to change once we honor the
///     user's stored timezone (TRD §21) instead of the device clock.
///  2. Tests can override this provider to pin "today" to a fixed date.
///
/// NOTE: currently uses device local time, not AppUser.timezone. That's
/// an acceptable gap for now (most users' device timezone matches their
/// actual timezone) but is the first thing to fix if "today" ever looks
/// wrong for a user who travels or has misconfigured their profile.
final todayProvider = Provider<DateTime>((ref) {
  return GoalCompletion.normalizeDate(DateTime.now());
});

/// Completions for an arbitrary date, keyed by goalId. This is the
/// general form; [todayCompletionsProvider] is just this pinned to
/// [todayProvider]. History/Calendar screens watch this directly for
/// whatever past date the user is looking at.
///
/// NOTE: this is an EXACT-DAY lookup (matches GoalCompletion.date to
/// [date] precisely) — appropriate for History, which shows what
/// actually happened on a specific day. It is NOT what checkbox/progress
/// UI should use for weekly/monthly goals, since those are satisfied by
/// a completion on ANY day within their period, not necessarily today.
/// See [isGoalDoneForCurrentPeriodProvider] for that case.
final completionsForDateProvider =
    StreamProvider.family<Map<String, GoalCompletion>, DateTime>((ref, date) {
      final userId = ref.watch(authStateChangesProvider).value?.id;
      if (userId == null) return Stream.value(const {});

      final normalized = GoalCompletion.normalizeDate(date);
      final repo = ref.watch(goalCompletionRepositoryProvider);

      return repo
          .watchCompletionsForDate(userId, normalized)
          .map((completions) => {for (final c in completions) c.goalId: c});
    });

/// Every completion recorded today, keyed by goalId. Empty map while
/// signed out or before the first emission.
final todayCompletionsProvider =
    Provider<AsyncValue<Map<String, GoalCompletion>>>((ref) {
      final today = ref.watch(todayProvider);
      return ref.watch(completionsForDateProvider(today));
    });

/// Whether a specific goal has an exact completion recorded on [date].
/// Same exact-day caveat as [completionsForDateProvider] above — for
/// weekly/monthly goals this is NOT "is it satisfied," just "was there
/// a completion doc dated exactly this day." History uses this
/// intentionally (see history_providers.dart's goalsForDateProvider);
/// checkbox/progress UI should use [isGoalDoneForCurrentPeriodProvider].
final isCompletedOnDateProvider =
    Provider.family<bool, ({String goalId, DateTime date})>((ref, params) {
      final completions =
          ref.watch(completionsForDateProvider(params.date)).value ?? const {};
      return completions.containsKey(params.goalId);
    });

/// Whether a specific goal has an exact completion recorded today.
/// Exact-day, same caveat as above.
final isCompletedTodayProvider = Provider.family<bool, String>((ref, goalId) {
  final today = ref.watch(todayProvider);
  return ref.watch(isCompletedOnDateProvider((goalId: goalId, date: today)));
});

/// A window guaranteed to contain BOTH the current week and the current
/// month, regardless of how they align (a week can straddle a month
/// boundary). Querying this single range once, instead of separately
/// per frequency, is what lets [currentPeriodCompletionsProvider] cover
/// daily/weekly/monthly goals with one Firestore listener.
(DateTime start, DateTime end) _currentPeriodQueryWindow() {
  final now = GoalCompletion.normalizeDate(DateTime.now());
  final (weekStart, _) = goalPeriodFor(GoalFrequency.weekly, now);
  final (monthStart, monthEnd) = goalPeriodFor(GoalFrequency.monthly, now);
  final start = weekStart.isBefore(monthStart) ? weekStart : monthStart;
  return (start, monthEnd);
}

/// Every completion within [_currentPeriodQueryWindow] — the data
/// [isGoalDoneForCurrentPeriodProvider] and [todayProgressByDomainProvider]
/// are both built on.
final currentPeriodCompletionsProvider = StreamProvider<List<GoalCompletion>>((
  ref,
) {
  final userId = ref.watch(authStateChangesProvider).value?.id;
  if (userId == null) return Stream.value(const []);

  final (start, end) = _currentPeriodQueryWindow();
  return ref
      .watch(goalCompletionRepositoryProvider)
      .watchCompletionsForDateRange(userId, start, end);
});

/// The actual "is this goal done" check for checkbox/progress UI —
/// frequency-aware: true if [goal] has ANY completion within its
/// current period (today for daily, this Mon–Sun week for weekly, this
/// calendar month for monthly), not just today specifically.
bool _isDoneForCurrentPeriod(
  Goal goal,
  List<GoalCompletion> periodCompletions,
) {
  final (periodStart, periodEnd) = goalPeriodFor(
    goal.frequency,
    DateTime.now(),
  );
  return periodCompletions.any(
    (c) =>
        c.goalId == goal.id &&
        !c.date.isBefore(periodStart) &&
        c.date.isBefore(periodEnd),
  );
}

final isGoalDoneForCurrentPeriodProvider = Provider.family<bool, Goal>((
  ref,
  goal,
) {
  final completions =
      ref.watch(currentPeriodCompletionsProvider).value ?? const [];
  return _isDoneForCurrentPeriod(goal, completions);
});

/// Today's aggregate progress per domain, e.g. Health 2/3 — the exact
/// shape the Home screen mockup in TRD §5 needs. Frequency-aware: a
/// weekly goal counts as "completed" for the whole week once satisfied
/// once, not just on the specific day it was done.
class DomainProgress {
  final int completed;
  final int total;
  const DomainProgress(this.completed, this.total);
}

final todayProgressByDomainProvider = Provider<Map<LifeDomain, DomainProgress>>(
  (ref) {
    final goalsByDomain = ref.watch(activeGoalsByDomainProvider);
    final periodCompletions =
        ref.watch(currentPeriodCompletionsProvider).value ?? const [];

    return {
      for (final entry in goalsByDomain.entries)
        entry.key: DomainProgress(
          entry.value
              .where((g) => _isDoneForCurrentPeriod(g, periodCompletions))
              .length,
          entry.value.length,
        ),
    };
  },
);

/// Centralizes the complete/undo logic so screens don't duplicate the
/// "which repository call for which goal type" branching.
class GoalCompletionActions {
  final GoalCompletionRepository _repo;
  final String _userId;

  GoalCompletionActions(this._repo, this._userId);

  /// Records a completion on [date] (defaults to today). Relies on the
  /// caller (GoalTile) only invoking this when
  /// [isGoalDoneForCurrentPeriodProvider] is currently false — it does
  /// NOT itself guard against creating a second completion within an
  /// already-satisfied week/month. That's a deliberate simplification:
  /// the reactive UI state makes a double-completion within one period
  /// very unlikely in normal use (not impossible under a race, e.g. two
  /// rapid taps before the first write's snapshot updates the UI) and
  /// adding a read-before-write guard here would trade a rare, harmless
  /// edge case for a slower, more complex write path.
  Future<void> complete(Goal goal, {DateTime? date, double? value}) {
    return _repo.markComplete(
      userId: _userId,
      goalId: goal.id,
      date: date ?? DateTime.now(),
      value: goal.type == GoalType.numeric ? value : null,
    );
  }

  /// Undoes completion for [goal]'s CURRENT period containing [date]
  /// (defaults to today). For daily goals this is just today's single
  /// document. For weekly/monthly goals, the completion actually
  /// satisfying the period might be on any earlier day within it — not
  /// necessarily today — so this clears every day across the whole
  /// period rather than only today's (possibly nonexistent) document.
  Future<void> undo(Goal goal, {DateTime? date}) {
    final targetDate = date ?? DateTime.now();

    if (goal.frequency == GoalFrequency.daily ||
        goal.frequency == GoalFrequency.custom) {
      return _repo.markIncomplete(
        userId: _userId,
        goalId: goal.id,
        date: targetDate,
      );
    }

    final (start, end) = goalPeriodFor(goal.frequency, targetDate);
    return _repo.clearCompletionsInRange(
      userId: _userId,
      goalId: goal.id,
      start: start,
      end: end,
    );
  }
}

/// Null while signed out — callers should already be behind the
/// router's auth gate, but this keeps the provider honest rather than
/// throwing.
final goalCompletionActionsProvider = Provider<GoalCompletionActions?>((ref) {
  final userId = ref.watch(authStateChangesProvider).value?.id;
  if (userId == null) return null;
  return GoalCompletionActions(
    ref.watch(goalCompletionRepositoryProvider),
    userId,
  );
});
