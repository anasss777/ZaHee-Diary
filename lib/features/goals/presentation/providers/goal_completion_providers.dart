import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/goal_completion.dart';
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

/// Every completion recorded today, keyed by goalId for O(1) lookup from
/// a goal tile. Empty map while signed out or before the first emission.
final todayCompletionsProvider =
    Provider<AsyncValue<Map<String, GoalCompletion>>>((ref) {
      final today = ref.watch(todayProvider);
      return ref.watch(completionsForDateProvider(today));
    });

/// Whether a specific goal is completed on an arbitrary date. Takes a
/// record `(goalId, date)` as its family key — records get structural
/// equality for free, which is exactly what Riverpod's family caching
/// needs here.
final isCompletedOnDateProvider =
    Provider.family<bool, ({String goalId, DateTime date})>((ref, params) {
      final completions =
          ref.watch(completionsForDateProvider(params.date)).value ?? const {};
      return completions.containsKey(params.goalId);
    });

/// Whether a specific goal is completed today. Thin wrapper over
/// [isCompletedOnDateProvider] pinned to [todayProvider].
final isCompletedTodayProvider = Provider.family<bool, String>((ref, goalId) {
  final today = ref.watch(todayProvider);
  return ref.watch(isCompletedOnDateProvider((goalId: goalId, date: today)));
});

/// Today's aggregate progress per domain, e.g. Health 2/3 — the exact
/// shape the Home screen mockup in TRD §5 needs. Built here (not in the
/// UI layer) so both the eventual Today screen and any other summary
/// view can reuse the same counts.
class DomainProgress {
  final int completed;
  final int total;
  const DomainProgress(this.completed, this.total);
}

final todayProgressByDomainProvider = Provider<Map<LifeDomain, DomainProgress>>(
  (ref) {
    final goalsByDomain = ref.watch(activeGoalsByDomainProvider);
    final completions = ref.watch(todayCompletionsProvider).value ?? const {};

    return {
      for (final entry in goalsByDomain.entries)
        entry.key: DomainProgress(
          entry.value.where((g) => completions.containsKey(g.id)).length,
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

  Future<void> complete(Goal goal, {DateTime? date, double? value}) {
    return _repo.markComplete(
      userId: _userId,
      goalId: goal.id,
      date: date ?? DateTime.now(),
      value: goal.type == GoalType.numeric ? value : null,
    );
  }

  Future<void> undo(Goal goal, {DateTime? date}) {
    return _repo.markIncomplete(
      userId: _userId,
      goalId: goal.id,
      date: date ?? DateTime.now(),
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
