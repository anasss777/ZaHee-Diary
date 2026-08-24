import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal_completion.dart';
import '../../../../core/models/moment.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/moment_repository.dart';

final momentRepositoryProvider = Provider<MomentRepository>((ref) {
  return MomentRepository();
});

/// All moments for a given date, current user. Empty while signed out,
/// matching the pattern used throughout goals/history/reflections.
final momentsForDateProvider =
    StreamProvider.family<List<Moment>, DateTime>((ref, date) {
  final userId = ref.watch(authStateChangesProvider).value?.id;
  if (userId == null) return Stream.value(const []);

  final normalized = GoalCompletion.normalizeDate(date);
  return ref.watch(momentRepositoryProvider).watchMomentsForDate(userId, normalized);
});
