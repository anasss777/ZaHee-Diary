import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/notification_preferences.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

String _formatTime(int hour, int minute) {
  final period = hour < 12 ? 'AM' : 'PM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isDetectingTimezone = false;
  bool _isSigningOut = false;
  bool _isDeletingAccount = false;

  Future<void> _detectTimezone(String userId) async {
    setState(() => _isDetectingTimezone = true);
    try {
      await ref.read(authRepositoryProvider).detectAndUpdateTimezone(userId);
    } finally {
      if (mounted) setState(() => _isDetectingTimezone = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSigningOut = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      // The router's redirect logic *would* eventually catch this via
      // the live authStateChanges stream, but Settings is reached via
      // context.push (an imperative push on top of the route stack) —
      // a reactive redirect firing while sitting on a pushed screen
      // doesn't forcibly tear down that pushed entry, so it can be left
      // visible even though the router now considers the user signed
      // out. Navigating explicitly avoids depending on that timing.
      if (mounted) context.go(AppRoutes.signIn);
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _deleteAccount(String userId) async {
    final confirmedIntent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This permanently deletes your account and everything in it — '
          'goals, history, reflections, and moments. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmedIntent != true || !mounted) return;

    // Second, higher-friction confirmation for an irreversible action —
    // typing the word makes it much harder to tap through by accident.
    final typedConfirmation = TextEditingController();
    final finalConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Type DELETE to confirm'),
        content: TextField(
          controller: typedConfirmation,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (finalConfirm != true || !mounted) return;
    if (typedConfirmation.text.trim().toUpperCase() != 'DELETE') return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(authRepositoryProvider).deleteAccount(userId);
      // Same reasoning as _signOut above — navigate explicitly rather
      // than relying on the reactive redirect while sitting on a
      // pushed screen.
      if (mounted) context.go(AppRoutes.signIn);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  /// Persists the new preferences. Rescheduling the OS-level
  /// notifications happens automatically elsewhere — see main.dart's
  /// authStateChangesProvider listener — since this write flows back
  /// through the same live profile stream. This method's only other job
  /// is requesting the OS permission, and ONLY when something is being
  /// turned ON (never on a toggle-off, and never proactively).
  Future<void> _updatePreferences(
    String userId,
    NotificationPreferences current,
    NotificationPreferences updated,
  ) async {
    final turningSomethingOn =
        !current.goalReminderEnabled && updated.goalReminderEnabled ||
        !current.eveningReflectionEnabled && updated.eveningReflectionEnabled ||
        !current.weeklyReviewEnabled && updated.weeklyReviewEnabled;

    if (turningSomethingOn) {
      final granted = await ref
          .read(notificationServiceProvider)
          .requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Notifications are off in your device settings — this app "
              "can't show reminders until that's enabled.",
            ),
          ),
        );
      }
    }

    await ref
        .read(authRepositoryProvider)
        .updateNotificationPreferences(userId, updated);
  }

  Future<void> _pickTime(
    String userId,
    NotificationPreferences current, {
    required bool isGoalReminder,
  }) async {
    final initial = isGoalReminder
        ? TimeOfDay(
            hour: current.goalReminderHour,
            minute: current.goalReminderMinute,
          )
        : TimeOfDay(
            hour: current.eveningReflectionHour,
            minute: current.eveningReflectionMinute,
          );

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;

    final updated = isGoalReminder
        ? current.copyWith(
            goalReminderHour: picked.hour,
            goalReminderMinute: picked.minute,
          )
        : current.copyWith(
            eveningReflectionHour: picked.hour,
            eveningReflectionMinute: picked.minute,
          );

    await _updatePreferences(userId, current, updated);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: user == null
          ? const SizedBox.shrink() // Router guarantees this shouldn't render.
          : SafeArea(
              child: ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'ACCOUNT',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(user.email),
                    subtitle: const Text('Signed in with'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign out'),
                    trailing: _isSigningOut
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isSigningOut ? null : _signOut,
                  ),

                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      'TIME',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: Text(user.timezone),
                    subtitle: const Text(
                      'Used to decide what counts as "today" for your goals',
                    ),
                    trailing: _isDetectingTimezone
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => _detectTimezone(user.id),
                            child: const Text('Detect'),
                          ),
                  ),

                  // ElevatedButton(
                  //   onPressed: ref
                  //       .read(notificationServiceProvider)
                  //       .debugPrintPending,
                  //   child: Text("Test Notification"),
                  // ),

                  // ElevatedButton(
                  //   onPressed: ref
                  //       .read(notificationServiceProvider)
                  //       .debugScheduleTestIn30Seconds,
                  //   child: Text("Test ~30s Delayed Notification"),
                  // ),
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      'NOTIFICATIONS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.checklist_outlined),
                    title: const Text('Goal reminder'),
                    subtitle: Text(
                      user.notificationPreferences.goalReminderEnabled
                          ? 'Daily at ${_formatTime(user.notificationPreferences.goalReminderHour, user.notificationPreferences.goalReminderMinute)}'
                          : 'Off',
                    ),
                    value: user.notificationPreferences.goalReminderEnabled,
                    onChanged: (enabled) => _updatePreferences(
                      user.id,
                      user.notificationPreferences,
                      user.notificationPreferences.copyWith(
                        goalReminderEnabled: enabled,
                      ),
                    ),
                  ),
                  if (user.notificationPreferences.goalReminderEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 72),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _pickTime(
                            user.id,
                            user.notificationPreferences,
                            isGoalReminder: true,
                          ),
                          child: const Text('Change time'),
                        ),
                      ),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.add_comment_outlined),
                    title: const Text('Evening reflection'),
                    subtitle: Text(
                      user.notificationPreferences.eveningReflectionEnabled
                          ? 'Daily at ${_formatTime(user.notificationPreferences.eveningReflectionHour, user.notificationPreferences.eveningReflectionMinute)}'
                          : 'Off',
                    ),
                    value:
                        user.notificationPreferences.eveningReflectionEnabled,
                    onChanged: (enabled) => _updatePreferences(
                      user.id,
                      user.notificationPreferences,
                      user.notificationPreferences.copyWith(
                        eveningReflectionEnabled: enabled,
                      ),
                    ),
                  ),
                  if (user.notificationPreferences.eveningReflectionEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 72),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => _pickTime(
                            user.id,
                            user.notificationPreferences,
                            isGoalReminder: false,
                          ),
                          child: const Text('Change time'),
                        ),
                      ),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.insights_outlined),
                    title: const Text('Weekly review'),
                    subtitle: const Text('Sunday evenings'),
                    value: user.notificationPreferences.weeklyReviewEnabled,
                    onChanged: (enabled) => _updatePreferences(
                      user.id,
                      user.notificationPreferences,
                      user.notificationPreferences.copyWith(
                        weeklyReviewEnabled: enabled,
                      ),
                    ),
                  ),

                  const Divider(height: 32),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Text(
                      'DANGER ZONE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Delete account',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    trailing: _isDeletingAccount
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isDeletingAccount
                        ? null
                        : () => _deleteAccount(user.id),
                  ),
                ],
              ),
            ),
    );
  }
}
