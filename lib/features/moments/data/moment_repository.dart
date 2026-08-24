import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/goal_completion.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/models/moment.dart';

/// Owns all Firestore interaction for moments, at
/// `users/{userId}/moments/{momentId}`.
///
/// Ordinary auto-generated IDs, same reasoning as ReflectionRepository —
/// a day can have several moments, so there's no one-per-day uniqueness
/// to enforce at the document-ID level.
class MomentRepository {
  final FirebaseFirestore _firestore;

  MomentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('moments');

  Future<Moment> createMoment({
    required String userId,
    required DateTime date,
    String? title,
    required String content,
    LifeDomain? domainId,
    List<String> media = const [],
  }) async {
    final docRef = _collection(userId).doc();
    final now = DateTime.now();
    final moment = Moment(
      id: docRef.id,
      userId: userId,
      date: GoalCompletion.normalizeDate(date),
      title: title,
      content: content,
      domainId: domainId,
      media: media,
      createdAt: now,
      updatedAt: now,
    );
    await docRef.set(_toFirestore(moment));
    return moment;
  }

  Future<void> updateMoment(Moment moment) async {
    await _collection(moment.userId)
        .doc(moment.id)
        .update(_toFirestore(moment.copyWith(updatedAt: DateTime.now())));
  }

  Future<void> deleteMoment(String userId, String momentId) async {
    await _collection(userId).doc(momentId).delete();
  }

  /// All moments recorded on a single date — used by the Daily Record
  /// screen, same shape/intent as watchReflectionsForDate.
  Stream<List<Moment>> watchMomentsForDate(String userId, DateTime date) {
    final normalized = GoalCompletion.normalizeDate(date);
    return _collection(userId)
        .where('date', isEqualTo: Timestamp.fromDate(normalized))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  /// All moments within `[start, end)` — kept available for a future
  /// searchable-timeline view (TRD §12) or a calendar "has a moment"
  /// indicator; not wired to any UI yet.
  Stream<List<Moment>> watchMomentsForDateRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    final normalizedStart = GoalCompletion.normalizeDate(start);
    final normalizedEnd = GoalCompletion.normalizeDate(end);
    return _collection(userId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedStart))
        .where('date', isLessThan: Timestamp.fromDate(normalizedEnd))
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  Moment _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final domainKey = data['domainId'] as String?;
    return Moment(
      id: doc.id,
      userId: data['userId'] as String,
      date: (data['date'] as Timestamp).toDate(),
      title: data['title'] as String?,
      content: data['content'] as String,
      domainId: domainKey != null ? LifeDomain.fromStorageKey(domainKey) : null,
      media: (data['media'] as List<dynamic>?)?.cast<String>() ?? const [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestore(Moment moment) {
    return {
      'userId': moment.userId,
      'date': Timestamp.fromDate(moment.date),
      'title': moment.title,
      'content': moment.content,
      'domainId': moment.domainId?.storageKey,
      'media': moment.media,
      'createdAt': Timestamp.fromDate(moment.createdAt),
      'updatedAt': Timestamp.fromDate(moment.updatedAt),
    };
  }
}
