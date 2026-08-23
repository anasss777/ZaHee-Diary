import 'package:flutter/material.dart';

/// The four permanent top-level life domains.
///
/// These are fixed by product design (see TRD §2) — users can customize
/// [Subcategory] entries within a domain, but cannot add, remove, or
/// rename the domains themselves.
enum LifeDomain {
  health,
  relationships,
  education,
  religion;

  /// Stable string key used for storage (Firestore document IDs, etc).
  /// Do not change these values once data exists — they are persisted.
  String get storageKey => switch (this) {
    LifeDomain.health => 'health',
    LifeDomain.relationships => 'relationships',
    LifeDomain.education => 'education',
    LifeDomain.religion => 'religion',
  };

  static LifeDomain fromStorageKey(String key) {
    return LifeDomain.values.firstWhere(
      (d) => d.storageKey == key,
      orElse: () => throw ArgumentError('Unknown LifeDomain key: $key'),
    );
  }

  String get label => switch (this) {
    LifeDomain.health => 'Health',
    LifeDomain.relationships => 'Relationships',
    LifeDomain.education => 'Education',
    LifeDomain.religion => 'Religion',
  };

  /// Emoji used in list rows / headers per the TRD mockups (§5, §15, §16).
  String get emoji => switch (this) {
    LifeDomain.health => '💪',
    LifeDomain.relationships => '❤️',
    LifeDomain.education => '📚',
    LifeDomain.religion => '☪️',
  };

  IconData get icon => switch (this) {
    LifeDomain.health => Icons.favorite_border,
    LifeDomain.relationships => Icons.people_outline,
    LifeDomain.education => Icons.menu_book_outlined,
    LifeDomain.religion => Icons.mosque_outlined,
  };

  /// Fixed display order (§2 lists them in this order everywhere).
  int get sortOrder => switch (this) {
    LifeDomain.health => 0,
    LifeDomain.relationships => 1,
    LifeDomain.education => 2,
    LifeDomain.religion => 3,
  };
}
