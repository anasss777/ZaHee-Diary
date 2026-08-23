import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';
import '../../../../core/models/app_user.dart';

/// Singleton repository instance for the app's lifetime.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// The live auth state: emits the current [AppUser], or null when signed
/// out. The router (added in the next milestone) watches this to decide
/// between the auth flow, onboarding, and main navigation.
final authStateChangesProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// Convenience accessor for "is someone signed in right now" without
/// unwrapping an AsyncValue everywhere.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateChangesProvider).value != null;
});
