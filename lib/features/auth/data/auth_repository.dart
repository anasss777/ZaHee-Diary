import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/google_auth_config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/notification_preferences.dart';
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
  }) : _firebaseAuth = firebaseAuth ?? fb_auth.FirebaseAuth.instance,
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
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email'],
      );

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

  /// Updates the stored IANA timezone (e.g. "Africa/Tunis"). Called from
  /// Settings, either with a value the user picked or one detected via
  /// [detectAndUpdateTimezone].
  Future<void> updateTimezone(String userId, String timezone) async {
    await _usersCollection.doc(userId).update({
      'timezone': timezone,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Re-runs timezone detection and persists the result — what Settings'
  /// "Detect automatically" button calls. Combined into one repository
  /// method (rather than exposing [_detectTimezone] publicly) so
  /// `flutter_timezone` stays imported only here, same principle as
  /// `firebase_auth`/`google_sign_in` being confined to this file.
  Future<void> detectAndUpdateTimezone(String userId) async {
    await updateTimezone(userId, await _detectTimezone());
  }

  /// Persists the full notification preferences object as a nested map.
  /// The caller (Settings) builds the new [NotificationPreferences] via
  /// its own `copyWith` and passes the whole thing — simpler than N
  /// individual toggle methods on this repository for each field.
  Future<void> updateNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    await _usersCollection.doc(userId).update({
      'notificationPreferences': preferences.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Permanently deletes the user's account and all of their data.
  ///
  /// Order matters: Firestore data is wiped FIRST, then the Firebase
  /// Auth account itself — if we deleted the Auth account first and the
  /// Firestore cleanup then failed partway through, the user would be
  /// locked out with orphaned data still sitting in Firestore and no way
  /// to sign back in and retry.
  ///
  /// KNOWN LIMITATION: Firebase requires a *recent* sign-in for account
  /// deletion (a security measure, not a bug on our end). If the user's
  /// session is old, `_firebaseAuth.currentUser.delete()` throws
  /// `requires-recent-login`, which is mapped to a clear message telling
  /// them to sign out and back in first. A smoother flow would silently
  /// re-prompt for credentials inline instead of making them start over
  /// — that's a reasonable follow-up, not implemented here to keep this
  /// milestone bounded.
  Future<void> deleteAccount(String userId) async {
    await _deleteAllUserData(userId);

    try {
      await _firebaseAuth.currentUser?.delete();
    } on fb_auth.FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code);
    }
  }

  /// Deletes every document in every subcollection under
  /// `users/{userId}`, then the user document itself. Batched in chunks
  /// of 400 (Firestore's hard limit is 500 writes per batch — leaving
  /// headroom rather than cutting it exactly at the ceiling).
  ///
  /// Deliberately hardcodes this list of collection names rather than
  /// importing each feature's repository class — AuthRepository staying
  /// decoupled from Goals/Reflections/Moments/Subcategories matters more
  /// here than avoiding this small amount of duplication, since every
  /// other repository already constructs these same paths independently.
  Future<void> _deleteAllUserData(String userId) async {
    const subcollections = [
      'goals',
      'goalCompletions',
      'subcategories',
      'reflections',
      'moments',
    ];

    for (final name in subcollections) {
      final collectionRef = _usersCollection.doc(userId).collection(name);
      var snapshot = await collectionRef.limit(400).get();

      while (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        snapshot = await collectionRef.limit(400).get();
      }
    }

    await _usersCollection.doc(userId).delete();
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

  /// Detects the device's IANA timezone (e.g. "Africa/Tunis") via
  /// `flutter_timezone`. Falls back to 'UTC' on any failure — this runs
  /// during account creation, and a failed timezone lookup should never
  /// block sign-up. The user can always correct it later in Settings.
  Future<String> _detectTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } catch (_) {
      return 'UTC';
    }
  }

  Future<AppUser> _createProfile(fb_auth.User fbUser) async {
    final now = DateTime.now();
    final newUser = AppUser(
      id: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName,
      photoURL: fbUser.photoURL,
      timezone: await _detectTimezone(),
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
      notificationPreferences: NotificationPreferences.fromMap(
        data['notificationPreferences'] as Map<String, dynamic>?,
      ),
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
      'notificationPreferences': user.notificationPreferences.toMap(),
      'createdAt': Timestamp.fromDate(user.createdAt),
      'updatedAt': Timestamp.fromDate(user.updatedAt),
    };
  }
}
