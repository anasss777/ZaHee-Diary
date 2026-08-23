import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/life_domain.dart';
import '../../../../core/models/subcategory.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/subcategory_repository.dart';

final subcategoryRepositoryProvider = Provider<SubcategoryRepository>((ref) {
  return SubcategoryRepository();
});

/// Every subcategory (active and archived) belonging to the current
/// user. Empty while signed out, matching the pattern used by
/// allGoalsProvider.
final allSubcategoriesProvider = StreamProvider<List<Subcategory>>((ref) {
  final userId = ref.watch(authStateChangesProvider).value?.id;
  if (userId == null) return Stream.value(const []);
  return ref.watch(subcategoryRepositoryProvider).watchSubcategories(userId);
});

/// Active subcategories grouped by domain, already sorted by `order`
/// (the repository's query is ordered, and grouping preserves that
/// order within each domain's list).
final activeSubcategoriesByDomainProvider =
    Provider<Map<LifeDomain, List<Subcategory>>>((ref) {
      final subcategories =
          ref.watch(allSubcategoriesProvider).value ?? const [];
      final active = subcategories.where((s) => s.isActive);

      final grouped = <LifeDomain, List<Subcategory>>{
        for (final domain in LifeDomain.values) domain: [],
      };
      for (final subcategory in active) {
        grouped[subcategory.domainId]!.add(subcategory);
      }
      return grouped;
    });

final activeSubcategoriesForDomainProvider =
    Provider.family<List<Subcategory>, LifeDomain>((ref, domain) {
      return ref.watch(activeSubcategoriesByDomainProvider)[domain] ?? const [];
    });
