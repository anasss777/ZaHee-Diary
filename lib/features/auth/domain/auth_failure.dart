/// A typed, user-presentable auth error.
///
/// Screens should only ever catch [AuthFailure], never raw
/// `FirebaseAuthException` — that mapping happens once, in the repository.
class AuthFailure implements Exception {
  final String message;
  final String code;

  const AuthFailure(this.message, {required this.code});

  /// Maps a Firebase Auth error code to a user-facing message.
  /// See: https://firebase.google.com/docs/reference/js/auth#autherrorcodes
  factory AuthFailure.fromCode(String code) {
    final message = switch (code) {
      'invalid-email' => 'That email address looks invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found with that email.',
      'wrong-password' => 'Incorrect password.',
      'invalid-credential' => 'Incorrect email or password.',
      'email-already-in-use' => 'An account already exists with that email.',
      'weak-password' => 'Choose a stronger password (at least 6 characters).',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'network-request-failed' =>
        'Network error. Check your connection and try again.',
      'too-many-requests' => 'Too many attempts. Please wait and try again.',
      'account-exists-with-different-credential' =>
        'An account already exists with a different sign-in method.',
      'sign-in-cancelled' => 'Sign-in was cancelled.',
      'requires-recent-login' =>
        'For your security, please sign out and sign back in, then try again.',
      _ => 'Something went wrong. Please try again.',
    };
    return AuthFailure(message, code: code);
  }

  @override
  String toString() => message;
}
