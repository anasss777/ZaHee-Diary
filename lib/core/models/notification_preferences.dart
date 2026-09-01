import 'package:equatable/equatable.dart';

/// A user's notification settings (TRD §19).
///
/// Every notification type defaults to OFF — "default behavior should
/// be conservative" per the TRD, and it also means the app never
/// requests the OS notification permission until the user actively
/// opts into something that needs it.
///
/// Deliberately simple for the MVP: goal reminder and evening
/// reflection each have one configurable daily time; weekly review is
/// fixed to Sunday evening rather than being user-configurable. A goal
/// reminder ALWAYS fires at its set time if enabled — it does not check
/// whether the user already finished their goals for the day before
/// firing (that would need a background task checking live state right
/// before delivery, not just a one-time local schedule — a reasonable
/// future enhancement, not built here).
class NotificationPreferences extends Equatable {
  final bool goalReminderEnabled;
  final int goalReminderHour;
  final int goalReminderMinute;

  final bool eveningReflectionEnabled;
  final int eveningReflectionHour;
  final int eveningReflectionMinute;

  final bool weeklyReviewEnabled;

  const NotificationPreferences({
    this.goalReminderEnabled = false,
    this.goalReminderHour = 19,
    this.goalReminderMinute = 0,
    this.eveningReflectionEnabled = false,
    this.eveningReflectionHour = 21,
    this.eveningReflectionMinute = 0,
    this.weeklyReviewEnabled = false,
  });

  NotificationPreferences copyWith({
    bool? goalReminderEnabled,
    int? goalReminderHour,
    int? goalReminderMinute,
    bool? eveningReflectionEnabled,
    int? eveningReflectionHour,
    int? eveningReflectionMinute,
    bool? weeklyReviewEnabled,
  }) {
    return NotificationPreferences(
      goalReminderEnabled: goalReminderEnabled ?? this.goalReminderEnabled,
      goalReminderHour: goalReminderHour ?? this.goalReminderHour,
      goalReminderMinute: goalReminderMinute ?? this.goalReminderMinute,
      eveningReflectionEnabled:
          eveningReflectionEnabled ?? this.eveningReflectionEnabled,
      eveningReflectionHour: eveningReflectionHour ?? this.eveningReflectionHour,
      eveningReflectionMinute:
          eveningReflectionMinute ?? this.eveningReflectionMinute,
      weeklyReviewEnabled: weeklyReviewEnabled ?? this.weeklyReviewEnabled,
    );
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPreferences();
    return NotificationPreferences(
      goalReminderEnabled: map['goalReminderEnabled'] as bool? ?? false,
      goalReminderHour: map['goalReminderHour'] as int? ?? 19,
      goalReminderMinute: map['goalReminderMinute'] as int? ?? 0,
      eveningReflectionEnabled: map['eveningReflectionEnabled'] as bool? ?? false,
      eveningReflectionHour: map['eveningReflectionHour'] as int? ?? 21,
      eveningReflectionMinute: map['eveningReflectionMinute'] as int? ?? 0,
      weeklyReviewEnabled: map['weeklyReviewEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalReminderEnabled': goalReminderEnabled,
      'goalReminderHour': goalReminderHour,
      'goalReminderMinute': goalReminderMinute,
      'eveningReflectionEnabled': eveningReflectionEnabled,
      'eveningReflectionHour': eveningReflectionHour,
      'eveningReflectionMinute': eveningReflectionMinute,
      'weeklyReviewEnabled': weeklyReviewEnabled,
    };
  }

  @override
  List<Object?> get props => [
        goalReminderEnabled,
        goalReminderHour,
        goalReminderMinute,
        eveningReflectionEnabled,
        eveningReflectionHour,
        eveningReflectionMinute,
        weeklyReviewEnabled,
      ];
}
