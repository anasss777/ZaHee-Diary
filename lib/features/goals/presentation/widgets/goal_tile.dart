import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../../../../core/utils/motion.dart';
import '../goal_form_screen.dart';
import '../providers/goal_completion_providers.dart';
import '../providers/goal_providers.dart';

/// A single goal row with a completion toggle, used by the Goals
/// management screen and the Today screen.
///
/// [date] exists for a future use case (an interactive, editable
/// History view) but nothing currently passes it — Daily Record has its
/// own separate, deliberately read-only row widget instead, which stays
/// correct under the frequency-aware model without needing this one:
/// weekly/monthly goals only ever appear there on the exact day they
/// were completed (see history_providers.dart's goalsForDateProvider),
/// so an exact-day completion check is already sufficient there. Wiring
/// History to this widget instead — trading "read-only journal" for
/// "editable past days" — is a reasonable future product decision, not
/// something this change should make silently by half-wiring it.
class GoalTile extends ConsumerWidget {
  final Goal goal;

  /// The Goals screen offers archiving from here; Today and History are
  /// daily-use surfaces and deliberately don't expose goal management
  /// actions (TRD's "do first" philosophy).
  final bool showManagementActions;

  /// Which day this tile reflects completion for. Defaults to today
  /// (via [todayProvider]) when omitted — History passes a specific past
  /// date so the same widget works for "today" and "any day" without a
  /// separate read-only variant.
  final DateTime? date;

  const GoalTile({
    super.key,
    required this.goal,
    this.showManagementActions = true,
    this.date,
  });

  Future<void> _handleCheckboxTap(
    BuildContext context,
    WidgetRef ref,
    bool isCompleted,
    DateTime effectiveDate,
  ) async {
    final actions = ref.read(goalCompletionActionsProvider);
    if (actions == null) return;

    if (isCompleted) {
      // A lighter, neutral click rather than an impact — undoing is a
      // normal, everyday action here (correcting a mis-tap, changing
      // your mind), not something to give negative/punitive feedback
      // for. Matches TRD's non-judgmental tone in haptic form, not just
      // wording.
      HapticFeedback.selectionClick();
      await actions.undo(goal, date: effectiveDate);
      return;
    }

    if (goal.type == GoalType.boolean) {
      HapticFeedback.lightImpact();
      await actions.complete(goal, date: effectiveDate);
      return;
    }

    // Numeric goal: ask for the value before recording completion.
    final controller = TextEditingController(
      text: goal.target?.toStringAsFixed(0) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(goal.title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: goal.unit ?? 'Value',
            helperText: goal.target != null
                ? 'Target: ${goal.target!.toStringAsFixed(0)} ${goal.unit ?? ''}'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (value != null) {
      HapticFeedback.lightImpact();
      await actions.complete(goal, date: effectiveDate, value: value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final effectiveDate = date ?? today;
    final isFutureDate = effectiveDate.isAfter(today);

    // Explicit date (History showing a specific past day) → exact-day
    // status, matching what actually happened that day. No explicit
    // date (Today/Goals, meaning "right now") → frequency-aware status:
    // a weekly/monthly goal reads as complete for the whole period once
    // satisfied anywhere in it, not just on the day it was done.
    final isCompleted = date != null
        ? ref.watch(
            isCompletedOnDateProvider((goalId: goal.id, date: effectiveDate)),
          )
        : ref.watch(isGoalDoneForCurrentPeriodProvider(goal));

    final subtitle = goal.type == GoalType.numeric
        ? '${goal.frequency.label} · ${goal.target?.toStringAsFixed(0)} ${goal.unit ?? ''}'
        : goal.frequency.label;

    return ListTile(
      leading: IconButton(
        icon: AnimatedSwitcher(
          duration: motionDuration(context, const Duration(milliseconds: 180)),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.circle_outlined,
            // The KEY is what makes AnimatedSwitcher treat these as two
            // different widgets to cross-fade between, rather than one
            // it just mutates in place with no transition.
            key: ValueKey(isCompleted),
            color: isCompleted
                ? Theme.of(context).colorScheme.primary
                : isFutureDate
                ? Theme.of(context).disabledColor
                : null,
          ),
        ),
        // Completing a goal for a future date doesn't make sense — the
        // control is visible (so the layout stays consistent day to
        // day) but inert.
        onPressed: isFutureDate
            ? null
            : () =>
                  _handleCheckboxTap(context, ref, isCompleted, effectiveDate),
      ),
      title: Text(
        goal.title,
        style: isCompleted
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Text(subtitle),
      onTap: showManagementActions
          ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GoalFormScreen(goal: goal)),
            )
          : null,
      trailing: showManagementActions
          ? PopupMenuButton<String>(
              onSelected: (value) async {
                final repo = ref.read(goalRepositoryProvider);
                if (value == 'archive') {
                  await repo.archiveGoal(goal.userId, goal.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            )
          : null,
    );
  }
}
