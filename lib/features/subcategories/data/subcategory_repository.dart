import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/models/subcategory.dart';

/// TRD §10's example subsections, used to seed a new user's first
/// subcategories during onboarding. Deliberately the shorter example set
/// (not §2's longer illustrative lists) — these are meant to be a
/// starting point the user immediately customizes, not a comprehensive
/// taxonomy.
const Map<LifeDomain, List<String>> kDefaultSubcategoryNames = {
  LifeDomain.health: ['Fitness', 'Sleep', 'Nutrition'],
  LifeDomain.relationships: ['Family', 'Friends', 'Partner'],
  LifeDomain.education: ['Programming', 'Languages', 'Books'],
  LifeDomain.religion: ['Prayer', "Qur'an", 'Charity'],
};

/// Owns all Firestore interaction for subcategories, at
/// `users/{userId}/subcategories/{subcategoryId}`.
class SubcategoryRepository {
  final FirebaseFirestore _firestore;

  SubcategoryRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) =>
      _firestore.collection('users').doc(userId).collection('subcategories');

  /// All subcategories for the user, active and archived. Ordered by
  /// [Subcategory.order] only (a single-field orderBy, so no composite
  /// Firestore index is required) — grouping by domain happens
  /// client-side in the provider layer, same pattern as goals.
  Stream<List<Subcategory>> watchSubcategories(String userId) {
    return _collection(userId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(_fromFirestore).toList());
  }

  Future<Subcategory> createSubcategory({
    required String userId,
    required LifeDomain domainId,
    required String name,
    String icon = '',
    required int order,
  }) async {
    final docRef = _collection(userId).doc();
    final subcategory = Subcategory(
      id: docRef.id,
      userId: userId,
      domainId: domainId,
      name: name,
      icon: icon,
      order: order,
      isActive: true,
      createdAt: DateTime.now(),
    );
    await docRef.set(_toFirestore(subcategory));
    return subcategory;
  }

  Future<void> updateSubcategory(Subcategory subcategory) async {
    await _collection(
      subcategory.userId,
    ).doc(subcategory.id).update(_toFirestore(subcategory));
  }

  /// Archived, not deleted — goals referencing this subcategory (via
  /// subcategoryId) keep working, matching the same "never delete
  /// history" principle used for goals themselves (TRD §9).
  Future<void> archiveSubcategory(String userId, String subcategoryId) async {
    await _collection(userId).doc(subcategoryId).update({'isActive': false});
  }

  Future<void> reactivateSubcategory(
    String userId,
    String subcategoryId,
  ) async {
    await _collection(userId).doc(subcategoryId).update({'isActive': true});
  }

  /// Persists a new order for a set of subcategories (typically all of
  /// one domain, after a drag-reorder). Uses a single batch write so the
  /// reorder applies atomically rather than as N separate round-trips.
  Future<void> reorderSubcategories(
    String userId,
    List<Subcategory> reordered,
  ) async {
    final batch = _firestore.batch();
    for (var i = 0; i < reordered.length; i++) {
      batch.update(_collection(userId).doc(reordered[i].id), {'order': i});
    }
    await batch.commit();
  }

  /// Creates [kDefaultSubcategoryNames] for a user who has none yet.
  /// Safe to call on every onboarding run — it's a no-op if the user
  /// already has any subcategory at all (including ones they've since
  /// renamed or archived), so it never overwrites customization with
  /// defaults.
  Future<void> seedDefaultsIfNeeded(String userId) async {
    final existing = await _collection(userId).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    for (final entry in kDefaultSubcategoryNames.entries) {
      final domain = entry.key;
      final names = entry.value;
      for (var i = 0; i < names.length; i++) {
        final docRef = _collection(userId).doc();
        final subcategory = Subcategory(
          id: docRef.id,
          userId: userId,
          domainId: domain,
          name: names[i],
          icon: '',
          order: i,
          isActive: true,
          createdAt: DateTime.now(),
        );
        batch.set(docRef, _toFirestore(subcategory));
      }
    }
    await batch.commit();
  }

  Subcategory _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Subcategory(
      id: doc.id,
      userId: data['userId'] as String,
      domainId: LifeDomain.fromStorageKey(data['domainId'] as String),
      name: data['name'] as String,
      icon: data['icon'] as String? ?? '',
      order: data['order'] as int? ?? 0,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestore(Subcategory subcategory) {
    return {
      'userId': subcategory.userId,
      'domainId': subcategory.domainId.storageKey,
      'name': subcategory.name,
      'icon': subcategory.icon,
      'order': subcategory.order,
      'isActive': subcategory.isActive,
      'createdAt': Timestamp.fromDate(subcategory.createdAt),
    };
  }
}
