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
  final bool showManagementActions;
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
      HapticFeedback.selectionClick();
      await actions.undo(goal, date: effectiveDate);
      return;
    }

    if (goal.type == GoalType.boolean) {
      HapticFeedback.lightImpact();
      await actions.complete(goal, date: effectiveDate);
      return;
    }

    final controller = TextEditingController(
      text: goal.target?.toStringAsFixed(0) ?? '',
    );

    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        return AlertDialog(
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
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
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
        );
      },
    );

    if (value != null) {
      HapticFeedback.lightImpact();
      await actions.complete(goal, date: effectiveDate, value: value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final today = ref.watch(todayProvider);
    final effectiveDate = date ?? today;
    final isFutureDate = effectiveDate.isAfter(today);

    final isCompleted = date != null
        ? ref.watch(
            isCompletedOnDateProvider((goalId: goal.id, date: effectiveDate)),
          )
        : ref.watch(isGoalDoneForCurrentPeriodProvider(goal));

    final subtitle = goal.type == GoalType.numeric
        ? '${goal.frequency.label} · ${goal.target?.toStringAsFixed(0)} ${goal.unit ?? ''}'
        : goal.frequency.label;

    final backgroundColor = isCompleted
        ? colors.primaryContainer.withValues(alpha: 0.35)
        : colors.surfaceContainerLow;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: showManagementActions
            ? () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GoalFormScreen(goal: goal)),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _CompletionButton(
                isCompleted: isCompleted,
                isFutureDate: isFutureDate,
                title: goal.title,
                onPressed: isFutureDate
                    ? null
                    : () => _handleCheckboxTap(
                        context,
                        ref,
                        isCompleted,
                        effectiveDate,
                      ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationThickness: 1.5,
                        color: isCompleted
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              if (showManagementActions)
                PopupMenuButton<String>(
                  tooltip: 'Goal options',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                  onSelected: (value) async {
                    final repo = ref.read(goalRepositoryProvider);

                    if (value == 'archive') {
                      await repo.archiveGoal(goal.userId, goal.id);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  final bool isCompleted;
  final bool isFutureDate;
  final String title;
  final VoidCallback? onPressed;

  const _CompletionButton({
    required this.isCompleted,
    required this.isFutureDate,
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Semantics(
      button: true,
      label: isCompleted
          ? 'Mark "$title" as not done'
          : 'Mark "$title" as done',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: AnimatedSwitcher(
          duration: motionDuration(context, const Duration(milliseconds: 220)),
          transitionBuilder: (child, animation) {
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Container(
            key: ValueKey(isCompleted),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? colors.primary : Colors.transparent,
              border: Border.all(
                color: isCompleted
                    ? colors.primary
                    : isFutureDate
                    ? colors.outlineVariant
                    : colors.outline,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 22,
              color: isCompleted
                  ? colors.onPrimary
                  : isFutureDate
                  ? colors.outlineVariant
                  : Colors.transparent,
            ),
          ),
        ),
      ),
    );
  }
}
