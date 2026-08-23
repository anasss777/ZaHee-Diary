import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/google_auth_config.dart';
import '../../../core/models/app_user.dart';
import '../domain/auth_failure.dart';

/// Owns all interaction with Firebase Auth, Google Sign-In, and the
/// `users/{userId}` Firestore profile document.
///
/// This is the ONLY place in the app that should import `firebase_auth`
/// or `google_sign_in` directly — everything above this layer works with
/// [AppUser] and [AuthFailure].
///
/// IMPORTANT (google_sign_in v7+): [initialize] MUST be awaited exactly
/// once, before [signInWithGoogle] is ever called — typically in main()
/// before runApp(). Calling any other GoogleSignIn method first will
/// throw. See core/constants/google_auth_config.dart for the client ID
/// this needs.
class AuthRepository {
  final fb_auth.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  bool _googleSignInInitialized = false;

  AuthRepository({
    fb_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Must be awaited once at app startup, before any sign-in attempt.
  /// Safe to call more than once — subsequent calls are no-ops.
  Future<void> initialize() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(serverClientId: kGoogleSignInServerClientId);
    _googleSignInInitialized = true;
  }

  /// Emits the current [AppUser], or null when signed out. This is the
  /// stream the app's top-level router listens to for auth-gating.
  ///
  /// Uses Firestore's `snapshots()` (a live listener), not a one-time
  /// `get()` — that's what makes profile changes made elsewhere (e.g.
  /// [completeOnboarding], or a future settings screen) propagate to the
  /// router automatically, instead of requiring a manual refresh. When
  /// the underlying Firebase Auth user changes (sign-in/out), asyncExpand
  /// tears down the previous Firestore listener and starts a new one for
  /// the new user — it never leaves a listener attached to a stale uid.
  Stream<AppUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().asyncExpand((fbUser) {
      if (fbUser == null) return Stream.value(null);
      return _watchProfile(fbUser);
    });
  }

  AppUser? get currentUserSnapshot {
    final fbUser = _firebaseAuth.currentUser;
    if (fbUser == null) return null;
    // Best-effort synchronous snapshot from Firebase Auth alone, used only
    // for quick UI checks before the Firestore-backed stream emits.
    return AppUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName,
      photoURL: fbUser.photoURL,
      timezone: 'UTC',
      locale: 'en',
      createdAt: fbUser.metadata.creationTime ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _loadOrCreateProfileOnce(credential.user!);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return _loadOrCreateProfileOnce(credential.user!);
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// google_sign_in v7 splits this into two steps: `authenticate()`
  /// establishes *identity* (who the user is, gives an ID token);
  /// `authorizationClient.authorizationForScopes()` separately grants
  /// *permissions* (gives an access token for the requested scopes).
  /// Firebase's credential accepts either or both — we request both so
  /// downstream Google API calls (if any are added later) have a token.
  Future<AppUser> signInWithGoogle() async {
    await initialize();

    try {
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate(scopeHint: const ['email']);

      final idToken = googleUser.authentication.idToken;

      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);

      final credential = fb_auth.GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      return _loadOrCreateProfileOnce(userCredential.user!);
    } on GoogleSignInException catch (e) {
      // v7 throws this (not a null return) when the user cancels.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw AuthFailure.fromCode('sign-in-cancelled');
      }
      throw AuthFailure.fromCode('unknown');
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  Future<void> signOut() async {
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Marks onboarding as done. Because [authStateChanges] listens live,
  /// this single write is enough to move the router past the onboarding
  /// redirect — no extra "refresh the user" step needed on the caller's
  /// end.
  Future<void> completeOnboarding(String userId) async {
    await _usersCollection.doc(userId).update({
      'hasCompletedOnboarding': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// One-time fetch used right after a sign-in/sign-up call completes,
  /// so those methods can return an [AppUser] immediately without
  /// waiting on the live stream's first emission. Creates the profile
  /// document if this is the user's first sign-in.
  Future<AppUser> _loadOrCreateProfileOnce(fb_auth.User fbUser) async {
    final docRef = _usersCollection.doc(fbUser.uid);
    final snapshot = await docRef.get();

    if (snapshot.exists) {
      return _fromFirestore(snapshot);
    }

    return _createProfile(fbUser);
  }

  /// The live-listening counterpart to [_loadOrCreateProfileOnce], used
  /// by [authStateChanges]. Ensures the profile document exists, then
  /// yields every subsequent change to it.
  Stream<AppUser> _watchProfile(fb_auth.User fbUser) async* {
    final docRef = _usersCollection.doc(fbUser.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      yield await _createProfile(fbUser);
    }

    yield* docRef.snapshots().map((doc) => _fromFirestore(doc));
  }

  /// NOTE: `timezone` is defaulted to 'UTC' here. A device timezone
  /// package (e.g. `flutter_timezone`) should replace this default in a
  /// later pass — tracked separately, not blocking this milestone.
  Future<AppUser> _createProfile(fb_auth.User fbUser) async {
    final now = DateTime.now();
    final newUser = AppUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName,
      photoURL: fbUser.photoURL,
      timezone: 'UTC',
      locale: 'en',
      hasCompletedOnboarding: false,
      createdAt: now,
      updatedAt: now,
    );

    await _usersCollection.doc(fbUser.uid).set(_toFirestore(newUser));
    return newUser;
  }

  AppUser _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppUser(
      id: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoURL: data['photoURL'] as String?,
      timezone: data['timezone'] as String? ?? 'UTC',
      locale: data['locale'] as String? ?? 'en',
      hasCompletedOnboarding: data['hasCompletedOnboarding'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> _toFirestore(AppUser user) {
    return {
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'timezone': user.timezone,
      'locale': user.locale,
      'hasCompletedOnboarding': user.hasCompletedOnboarding,
      'createdAt': Timestamp.fromDate(user.createdAt),
      'updatedAt': Timestamp.fromDate(user.updatedAt),
    };
  }
}