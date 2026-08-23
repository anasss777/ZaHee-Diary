import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/goal_completion.dart';

/// Owns all Firestore interaction for goal completions, at
/// `users/{userId}/goalCompletions/{completionId}`.
///
/// Completion documents use a DETERMINISTIC id — `{goalId}_{yyyy-MM-dd}`
/// — rather than an auto-generated one. This is the key design choice
/// here: it makes "mark complete" and "undo" idempotent set()/delete()
/// calls against a known document path instead of a query-then-write,
/// which is what actually prevents duplicate completions for the same
/// goal on the same day (TRD §29) even under flaky connectivity or a
/// double-tap.
///
/// "Not completed" is represented by the ABSENCE of a document, not a
/// stored negative record — undoing a completion deletes the doc.
class GoalCompletionRepository {
  final FirebaseFirestore _firestore;

  GoalCompletionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _completionsCollection(
    String userId,
  ) => _firestore.collection('users').doc(userId).collection('goalCompletions');

  static String _dateKey(DateTime date) {
    final d = GoalCompletion.normalizeDate(date);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  static String _docId(String goalId, DateTime date) =>
      '${goalId}_${_dateKey(date)}';

  /// Marks [goalId] complete on [date]. Safe to call repeatedly — it's a
  /// set(), not an add(), so re-tapping "complete" just rewrites the same
  /// document rather than creating duplicates.
  Future<void> markComplete({
    required String userId,
    required String goalId,
    required DateTime date,
    double? value,
    String? note,
  }) async {
    final normalizedDate = GoalCompletion.normalizeDate(date);
    final completion = GoalCompletion(
      id: _docId(goalId, date),
      goalId: goalId,
      userId: userId,
      date: normalizedDate,
      completedAt: DateTime.now(),
      value: value,
      note: note,
    );

    await _completionsCollection(
      userId,
    ).doc(completion.id).set(_toFirestore(completion));
  }

  /// Undoes a completion. Safe to call even if it was never completed —
  /// deleting a nonexistent document is a no-op in Firestore.
  Future<void> markIncomplete({
    required String userId,
    required String goalId,
    required DateTime date,
  }) async {
    await _completionsCollection(userId).doc(_docId(goalId, date)).delete();
  }

  Future<GoalCompletion?> getCompletion({
    required String userId,
    required String goalId,
    required DateTime date,
  }) async {
    final doc = await _completionsCollection(
      userId,
    ).doc(_docId(goalId, date)).get();
    if (!doc.exists) return null;
    return _fromFirestore(doc);
  }

  /// All completions recorded on a single date, across every goal. This
  /// is what "today" screens are built on: one listener, sliced by goal
  /// in the provider layer, rather than one listener per goal.
  Stream<List<GoalCompletion>> watchCompletionsForDate(
    String userId,
    DateTime date,
  ) {
    final normalizedDate = GoalCompletion.normalizeDate(date);
    return _completionsCollection(userId)
        .where('date', isEqualTo: Timestamp.fromDate(normalizedDate))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  /// All completions within `[start, end)` — used by the calendar month
  /// view to populate a whole month with a single listener rather than
  /// one query per visible day. Single-field range filter on `date`
  /// alone, so (like the other queries here) no composite index needed.
  Stream<List<GoalCompletion>> watchCompletionsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final normalizedStart = GoalCompletion.normalizeDate(start);
    final normalizedEnd = GoalCompletion.normalizeDate(end);
    return _completionsCollection(userId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart),
        )
        .where('date', isLessThan: Timestamp.fromDate(normalizedEnd))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  /// A single goal's completion history, most recent first — used for
  /// per-goal stats/streaks later (not wired to any UI yet).
  Stream<List<GoalCompletion>> watchCompletionsForGoal(
    String userId,
    String goalId,
  ) {
    return _completionsCollection(userId)
        .where('goalId', isEqualTo: goalId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  GoalCompletion _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return GoalCompletion(
      id: doc.id,
      goalId: data['goalId'] as String,
      userId: data['userId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      completedAt: (data['completedAt'] as Timestamp).toDate(),
      value: (data['value'] as num?)?.toDouble(),
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> _toFirestore(GoalCompletion completion) {
    return {
      'goalId': completion.goalId,
      'userId': completion.userId,
      'date': Timestamp.fromDate(completion.date),
      'completedAt': Timestamp.fromDate(completion.completedAt),
      'value': completion.value,
      'note': completion.note,
    };
  }
}
