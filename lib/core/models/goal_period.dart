import 'goal.dart';
import 'goal_completion.dart';

/// The `[start, end)` period boundaries containing [date], for a goal
/// with [frequency].
///
/// This is the single interpretation of "weekly"/"monthly" used
/// throughout the app: a period, not a specific day. A weekly goal is
/// satisfied once anywhere in its Monday–Sunday week; a monthly goal,
/// anywhere in its calendar month. TRD §6.1 lists "specific weekdays"
/// as a FUTURE frequency option distinct from the current
/// daily/weekly/monthly types, which is the basis for this
/// interpretation — those types describe periods, not fixed days.
///
/// `custom` isn't selectable anywhere in the UI yet (goal_form_screen
/// explicitly excludes it from the frequency dropdown) and its real
/// semantics aren't defined by the TRD beyond "reserved for post-MVP
/// options." Falls back to daily-period behavior here — the safest
/// default, and moot in practice since no goal can currently have this
/// frequency via the app itself.
(DateTime start, DateTime end) goalPeriodFor(GoalFrequency frequency, DateTime date) {
  final normalized = GoalCompletion.normalizeDate(date);
  switch (frequency) {
    case GoalFrequency.daily:
    case GoalFrequency.custom:
      return (normalized, normalized.add(const Duration(days: 1)));
    case GoalFrequency.weekly:
      final start = normalized.subtract(Duration(days: normalized.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    case GoalFrequency.monthly:
      final start = DateTime(normalized.year, normalized.month, 1);
      final end = normalized.month == 12
          ? DateTime(normalized.year + 1, 1, 1)
          : DateTime(normalized.year, normalized.month + 1, 1);
      return (start, end);
  }
}

/// How many periods of [frequency] are fully or partially contained in
/// `[start, end)`. Used by Life stats to compute "expected occurrences"
/// in the right unit for each goal's cadence — a weekly goal expects
/// ~4 occurrences in a month, not ~30.
int periodsElapsed(GoalFrequency frequency, DateTime start, DateTime end) {
  if (!start.isBefore(end)) return 0;

  switch (frequency) {
    case GoalFrequency.daily:
    case GoalFrequency.custom:
      return end.difference(start).inDays;

    case GoalFrequency.weekly:
      var count = 0;
      var cursor = goalPeriodFor(GoalFrequency.weekly, start).$1;
      while (cursor.isBefore(end)) {
        count++;
        cursor = cursor.add(const Duration(days: 7));
      }
      return count;

    case GoalFrequency.monthly:
      var count = 0;
      var cursor = DateTime(start.year, start.month, 1);
      while (cursor.isBefore(end)) {
        count++;
        cursor = cursor.month == 12
            ? DateTime(cursor.year + 1, 1, 1)
            : DateTime(cursor.year, cursor.month + 1, 1);
      }
      return count;
  }
}
