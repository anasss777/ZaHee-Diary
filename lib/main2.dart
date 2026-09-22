import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/providers/auth_providers.dart';
import 'features/notifications/presentation/providers/notification_providers.dart';

class ZaheeJournalApp extends ConsumerWidget {
  const ZaheeJournalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    ref.listen(authStateChangesProvider, (previous, next) {
      final user = next.value;

      if (user != null) {
        ref
            .read(notificationServiceProvider)
            .applyPreferences(user.notificationPreferences)
            .catchError((Object e, StackTrace s) {
              debugPrint('Notification reconciliation failed: $e\n$s');
            });
      }
    });

    return MaterialApp.router(
      title: 'Zahee Journal',
      debugShowCheckedModeBanner: false,

      themeMode: themeMode,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF334155),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF334155),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),

      routerConfig: router,

      builder: (context, child) {
        final clampedScaler = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 1.0, maxScaleFactor: 1.5);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
    );
  }
}
