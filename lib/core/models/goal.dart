import 'package:equatable/equatable.dart';

import 'life_domain.dart';

/// How often a goal is expected to be completed.
///
/// MVP supports the four listed in TRD §6.1. `custom` is reserved for
/// post-MVP options (specific weekdays, X times per week, interval-based).
enum GoalFrequency {
  daily,
  weekly,
  monthly,
  custom;

  String get storageKey => name;

  static GoalFrequency fromStorageKey(String key) =>
      GoalFrequency.values.firstWhere(
        (f) => f.storageKey == key,
        orElse: () => throw ArgumentError('Unknown GoalFrequency key: $key'),
      );

  String get label => switch (this) {
    GoalFrequency.daily => 'Daily',
    GoalFrequency.weekly => 'Weekly',
    GoalFrequency.monthly => 'Monthly',
    GoalFrequency.custom => 'Custom',
  };
}

/// Whether a goal is completed as a simple yes/no, or tracked with a
/// measurable value (see TRD §8).
enum GoalType {
  boolean,
  numeric;

  String get storageKey => name;

  static GoalType fromStorageKey(String key) => GoalType.values.firstWhere(
    (t) => t.storageKey == key,
    orElse: () => throw ArgumentError('Unknown GoalType key: $key'),
  );
}

/// A repeated action the user wants to track (TRD §6).
///
/// A [Goal] is the template/definition; individual completions are
/// recorded separately as [GoalCompletion] so historical stats survive
/// goal edits, pauses, or archival (TRD §7, §9).
class Goal extends Equatable {
  final String id;
  final String userId;
  final LifeDomain domainId;
  final String subcategoryId;

  final String title;
  final String? description;

  final GoalFrequency frequency;
  final GoalType type;

  /// For numeric goals: the target value per period (e.g. 30 for
  /// "30 minutes"). Null for boolean goals.
  final double? target;

  /// Unit label for numeric goals (e.g. "minutes", "pages"). Null for
  /// boolean goals.
  final String? unit;

  final DateTime startDate;
  final DateTime? endDate;

  /// Paused/archived goals are inactive but are never deleted outright —
  /// their historical completions remain queryable (TRD §9).
  final bool isActive;

  /// Manual sort position among the user's goals.
  final int order;

  final DateTime createdAt;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.domainId,
    required this.subcategoryId,
    required this.title,
    this.description,
    required this.frequency,
    required this.type,
    this.target,
    this.unit,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.order,
    required this.createdAt,
    required this.updatedAt,
  }) : assert(
         type == GoalType.boolean || target != null,
         'Numeric goals must have a target value',
       );

  Goal copyWith({
    String? title,
    String? description,
    GoalFrequency? frequency,
    double? target,
    String? unit,
    DateTime? endDate,
    bool? isActive,
    int? order,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id,
      userId: userId,
      domainId: domainId,
      subcategoryId: subcategoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      type: type,
      target: target ?? this.target,
      unit: unit ?? this.unit,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    domainId,
    subcategoryId,
    title,
    description,
    frequency,
    type,
    target,
    unit,
    startDate,
    endDate,
    isActive,
    order,
    createdAt,
    updatedAt,
  ];
}
