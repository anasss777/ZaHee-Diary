import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/models/life_domain.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/goal_repository.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository();
});

/// Raw stream of every goal (active and archived) belonging to the
/// current user. Emits an empty list while signed out, rather than
/// erroring, so widgets don't need to null-check the user separately.
final allGoalsProvider = StreamProvider<List<Goal>>((ref) {
  final userId = ref.watch(authStateChangesProvider).value?.id;
  if (userId == null) return Stream.value(const []);
  return ref.watch(goalRepositoryProvider).watchGoals(userId);
});

/// Active-only goals, grouped by domain. This is what the Today screen
/// and Goals list screen both build on — computed from [allGoalsProvider]
/// rather than a second Firestore listener.
final activeGoalsByDomainProvider = Provider<Map<LifeDomain, List<Goal>>>((
  ref,
) {
  final goals = ref.watch(allGoalsProvider).value ?? const [];
  final active = goals.where((g) => g.isActive);

  final grouped = <LifeDomain, List<Goal>>{
    for (final domain in LifeDomain.values) domain: [],
  };
  for (final goal in active) {
    grouped[goal.domainId]!.add(goal);
  }
  return grouped;
});

/// Active goals for a single domain — a thin family wrapper so screens
/// scoped to one domain (e.g. a domain detail page) don't need to filter
/// the whole map themselves.
final activeGoalsForDomainProvider = Provider.family<List<Goal>, LifeDomain>((
  ref,
  domain,
) {
  return ref.watch(activeGoalsByDomainProvider)[domain] ?? const [];
});
