import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No explicit FirebaseOptions needed: on Android, the google-services
  // Gradle plugin reads android/app/google-services.json at build time
  // and configures the native Firebase app automatically.
  //
  // If iOS or web support is added later, switch to the FlutterFire CLI
  // (`flutterfire configure`) to generate firebase_options.dart and pass
  // `options: DefaultFirebaseOptions.currentPlatform` here instead —
  // those platforms don't have an equivalent auto-config step.
  await Firebase.initializeApp();

  // Explicit, not strictly required — `cloud_firestore` already enables
  // disk persistence and offline write queuing by default on mobile.
  // Set here anyway so the behavior TRD §23 asks for ("view/complete
  // goals offline, sync when connectivity returns") is a deliberate,
  // documented configuration rather than an implicit SDK default that's
  // easy to forget is even happening. This is also the ONLY code this
  // app needs for the actual queue-and-sync mechanics — Firestore
  // handles the rest natively; nothing here hand-builds a sync engine.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final container = ProviderContainer();

  // google_sign_in v7 requires initialize() before any sign-in attempt,
  // which is why this was originally awaited before runApp(). But that
  // makes app startup itself depend on this succeeding — and an
  // already-signed-in user opening the app while offline doesn't need
  // Google Sign-In at all right now, so a hang or failure here should
  // never block them from reaching their (cached, offline-readable)
  // data. A short timeout plus a catch means startup proceeds
  // regardless; if the user later taps "Continue with Google" while
  // genuinely offline, that specific action will fail with a clear
  // network error at the point it's actually attempted, which is the
  // right place for that failure to surface.
  try {
    await container
        .read(authRepositoryProvider)
        .initialize()
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint(
      'Google Sign-In initialize() did not complete at startup '
      '($e) — continuing without it; will retry lazily if the user '
      'attempts Google sign-in.',
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ZaheeJournalApp(),
    ),
  );
}

class ZaheeJournalApp extends ConsumerWidget {
  const ZaheeJournalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Whenever the signed-in user's profile changes — including right
    // after Settings persists a preference change, since that write
    // flows back through the same live Firestore listener
    // authStateChangesProvider watches — reconcile the OS-level
    // notification schedule to match. This single listener is also
    // what re-establishes schedules on a cold app launch, since the
    // provider emits the current user again at startup. Settings
    // itself only ever writes preferences; it never calls
    // NotificationService directly.
    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        ref
            .read(notificationServiceProvider)
            .applyPreferences(user.notificationPreferences)
            .catchError((Object e, StackTrace s) {
              // applyPreferences already catches and logs per-notification
              // failures internally; this outer catch is a last-resort net
              // for anything unexpected (e.g. initialize() itself failing)
              // so it's visible in the console instead of becoming a
              // silent, unhandled Future rejection.
              debugPrint('Notification reconciliation failed: $e\n$s');
            });
      }
    });

    return MaterialApp.router(
      title: 'Zahee Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E6259)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
