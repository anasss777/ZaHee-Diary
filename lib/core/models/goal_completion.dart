import 'package:equatable/equatable.dart';

/// A single completion record for a [Goal] on a specific date (TRD §7).
///
/// Stored separately from the goal itself so that daily/weekly/monthly
/// completion rates, streaks, and trends can be computed, and so that
/// editing or archiving a goal never rewrites or deletes history.
class GoalCompletion extends Equatable {
  final String id;
  final String goalId;
  final String userId;

  /// The calendar date (local to the user's timezone, time-of-day
  /// stripped) this completion applies to. Completion status is always
  /// evaluated per local date — see TRD §21 on why timezone matters.
  final DateTime date;

  /// When the completion was actually recorded, distinct from [date]
  /// (e.g. logging yesterday's walk after midnight).
  final DateTime completedAt;

  /// For numeric goals, the value logged (e.g. 75 minutes against a
  /// 60-minute target). Null / ignored for boolean goals, where existence
  /// of this record simply means "completed: true".
  final double? value;

  final String? note;

  const GoalCompletion({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.date,
    required this.completedAt,
    this.value,
    this.note,
  });

  /// Normalizes [date] to midnight so completion lookups by day are
  /// stable regardless of what time-of-day this was constructed.
  static DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  GoalCompletion copyWith({double? value, String? note}) {
    return GoalCompletion(
      id: id,
      goalId: goalId,
      userId: userId,
      date: date,
      completedAt: completedAt,
      value: value ?? this.value,
      note: note ?? this.note,
    );
  }

  @override
  List<Object?> get props => [
    id,
    goalId,
    userId,
    date,
    completedAt,
    value,
    note,
  ];
}
