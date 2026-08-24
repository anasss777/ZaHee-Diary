import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal_completion.dart';
import '../../../../core/models/reflection.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/reflection_repository.dart';

final reflectionRepositoryProvider = Provider<ReflectionRepository>((ref) {
  return ReflectionRepository();
});

/// All reflections for a given date, current user. Empty while signed
/// out, matching the pattern used throughout goals/history.
final reflectionsForDateProvider =
    StreamProvider.family<List<Reflection>, DateTime>((ref, date) {
      final userId = ref.watch(authStateChangesProvider).value?.id;
      if (userId == null) return Stream.value(const []);

      final normalized = GoalCompletion.normalizeDate(date);
      return ref
          .watch(reflectionRepositoryProvider)
          .watchReflectionsForDate(userId, normalized);
    });
