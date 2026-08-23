import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final container = ProviderContainer();

  // google_sign_in v7 requires this to complete before any sign-in
  // attempt. Doing it here (rather than lazily inside signInWithGoogle)
  // means it's already done by the time the user taps the button.
  await container.read(authRepositoryProvider).initialize();

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
