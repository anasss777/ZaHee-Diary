import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';

/// Owns all Firestore interaction for goals, at `users/{userId}/goals/{goalId}`.
///
/// Like AuthRepository, this is the only place that should import
/// `cloud_firestore` for goal data — everything above this layer works
/// with the plain [Goal] model.
class GoalRepository {
  final FirebaseFirestore _firestore;

  GoalRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _goalsCollection(String userId) =>
      _firestore.collection('users').doc(userId).collection('goals');

  /// All of a user's goals, active and inactive, ordered for display.
  /// Filtering (active-only, by domain) happens in the provider layer so
  /// the UI can slice this one stream different ways without extra
  /// Firestore listeners.
  Stream<List<Goal>> watchGoals(String userId) {
    return _goalsCollection(userId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  Future<Goal?> getGoal(String userId, String goalId) async {
    final doc = await _goalsCollection(userId).doc(goalId).get();
    if (!doc.exists) return null;
    return _fromFirestore(doc);
  }

  /// Creates a new goal. Firestore auto-generates the ID.
  Future<Goal> createGoal({
    required String userId,
    required LifeDomain domainId,
    required String subcategoryId,
    required String title,
    String? description,
    required GoalFrequency frequency,
    required GoalType type,
    double? target,
    String? unit,
    required int order,
  }) async {
    final docRef = _goalsCollection(userId).doc();
    final now = DateTime.now();

    final goal = Goal(
      id: docRef.id,
      userId: userId,
      domainId: domainId,
      subcategoryId: subcategoryId,
      title: title,
      description: description,
      frequency: frequency,
      type: type,
      target: target,
      unit: unit,
      startDate: now,
      isActive: true,
      order: order,
      createdAt: now,
      updatedAt: now,
    );

    await docRef.set(_toFirestore(goal));
    return goal;
  }

  Future<void> updateGoal(Goal goal) async {
    await _goalsCollection(goal.userId)
        .doc(goal.id)
        .update(_toFirestore(goal.copyWith(updatedAt: DateTime.now())));
  }

  /// Sets isActive: false. Per TRD §9, archiving must never delete the
  /// goal document or its completions — history stays intact.
  Future<void> archiveGoal(String userId, String goalId) async {
    await _goalsCollection(userId).doc(goalId).update({
      'isActive': false,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> reactivateGoal(String userId, String goalId) async {
    await _goalsCollection(userId).doc(goalId).update({
      'isActive': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Hard delete. NOT exposed in the MVP UI (TRD §9 says deleting a goal
  /// should not be the default path — archive is). Kept here for
  /// completeness / future "permanently delete" in settings, and for
  /// tests that need cleanup.
  Future<void> deleteGoal(String userId, String goalId) async {
    await _goalsCollection(userId).doc(goalId).delete();
  }

  Goal _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Goal(
      id: doc.id,
      userId: data['userId'] as String,
      domainId: LifeDomain.fromStorageKey(data['domainId'] as String),
      subcategoryId: data['subcategoryId'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      frequency: GoalFrequency.fromStorageKey(data['frequency'] as String),
      type: GoalType.fromStorageKey(data['type'] as String),
      target: (data['target'] as num?)?.toDouble(),
      unit: data['unit'] as String?,
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      order: data['order'] as int? ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestore(Goal goal) {
    return {
      'userId': goal.userId,
      'domainId': goal.domainId.storageKey,
      'subcategoryId': goal.subcategoryId,
      'title': goal.title,
      'description': goal.description,
      'frequency': goal.frequency.storageKey,
      'type': goal.type.storageKey,
      'target': goal.target,
      'unit': goal.unit,
      'startDate': Timestamp.fromDate(goal.startDate),
      'endDate': goal.endDate != null ? Timestamp.fromDate(goal.endDate!) : null,
      'isActive': goal.isActive,
      'order': goal.order,
      'createdAt': Timestamp.fromDate(goal.createdAt),
      'updatedAt': Timestamp.fromDate(goal.updatedAt),
    };
  }
}
