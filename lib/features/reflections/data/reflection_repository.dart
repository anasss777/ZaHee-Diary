import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/goal_completion.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/models/reflection.dart';

/// Owns all Firestore interaction for reflections, at
/// `users/{userId}/reflections/{reflectionId}`.
///
/// Unlike goal completions, reflections use ordinary auto-generated IDs
/// rather than a deterministic `{key}_{date}` scheme — a single day can
/// have more than one reflection (e.g. one for Health, one for the day
/// as a whole), so there's no natural one-per-day uniqueness constraint
/// to enforce at the document-ID level the way there was for
/// completions.
class ReflectionRepository {
  final FirebaseFirestore _firestore;

  ReflectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('reflections');

  Future<Reflection> createReflection({
    required String userId,
    LifeDomain? domainId,
    required DateTime date,
    required String content,
  }) async {
    final docRef = _collection(userId).doc();
    final now = DateTime.now();
    final reflection = Reflection(
      id: docRef.id,
      userId: userId,
      domainId: domainId,
      date: GoalCompletion.normalizeDate(date),
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(_toFirestore(reflection));
    return reflection;
  }

  Future<void> updateReflection(Reflection reflection) async {
    await _collection(reflection.userId)
        .doc(reflection.id)
        .update(_toFirestore(reflection.copyWith(updatedAt: DateTime.now())));
  }

  Future<void> deleteReflection(String userId, String reflectionId) async {
    await _collection(userId).doc(reflectionId).delete();
  }

  /// All reflections recorded on a single date. Mirrors
  /// GoalCompletionRepository.watchCompletionsForDate's shape/intent —
  /// used by the Daily Record screen.
  Stream<List<Reflection>> watchReflectionsForDate(
    String userId,
    DateTime date,
  ) {
    final normalized = GoalCompletion.normalizeDate(date);
    return _collection(userId)
        .where('date', isEqualTo: Timestamp.fromDate(normalized))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  /// All reflections within `[start, end)` — same single-field range
  /// filter pattern as watchCompletionsForDateRange, kept available for
  /// a future calendar "has a reflection" indicator (TRD §14 lists this
  /// as something the calendar could show; not wired to the UI yet).
  Stream<List<Reflection>> watchReflectionsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final normalizedStart = GoalCompletion.normalizeDate(start);
    final normalizedEnd = GoalCompletion.normalizeDate(end);
    return _collection(userId)
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart),
        )
        .where('date', isLessThan: Timestamp.fromDate(normalizedEnd))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  Reflection _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final domainKey = data['domainId'] as String?;
    return Reflection(
      id: doc.id,
      userId: data['userId'] as String,
      domainId: domainKey != null ? LifeDomain.fromStorageKey(domainKey) : null,
      date: (data['date'] as Timestamp).toDate(),
      content: data['content'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestore(Reflection reflection) {
    return {
      'userId': reflection.userId,
      'domainId': reflection.domainId?.storageKey,
      'date': Timestamp.fromDate(reflection.date),
      'content': reflection.content,
      'createdAt': Timestamp.fromDate(reflection.createdAt),
      'updatedAt': Timestamp.fromDate(reflection.updatedAt),
    };
  }
}
