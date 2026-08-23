import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/goal.dart';
import '../goal_form_screen.dart';
import '../providers/goal_completion_providers.dart';
import '../providers/goal_providers.dart';

/// A single goal row with a completion toggle, used by both the Goals
/// management screen and the Today screen. Kept as one shared widget
/// rather than two copies so completion logic (the numeric-value dialog,
/// undo behavior) can't drift between the two screens.
class GoalTile extends ConsumerWidget {
  final Goal goal;

  /// The Goals screen offers archiving from here; Today is a daily-use
  /// surface and deliberately doesn't expose goal management actions
  /// (TRD's "do first" philosophy — Today should never feel like a
  /// place you go to administer things).
  final bool showManagementActions;

  const GoalTile({
    super.key,
    required this.goal,
    this.showManagementActions = true,
  });

  Future<void> _handleCheckboxTap(
    BuildContext context,
    WidgetRef ref,
    bool isCompleted,
  ) async {
    final actions = ref.read(goalCompletionActionsProvider);
    if (actions == null) return;

    if (isCompleted) {
      await actions.undo(goal);
      return;
    }

    if (goal.type == GoalType.boolean) {
      await actions.complete(goal);
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
      await actions.complete(goal, value: value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = ref.watch(isCompletedTodayProvider(goal.id));

    final subtitle = goal.type == GoalType.numeric
        ? '${goal.frequency.label} · ${goal.target?.toStringAsFixed(0)} ${goal.unit ?? ''}'
        : goal.frequency.label;

    return ListTile(
      leading: IconButton(
        icon: Icon(
          isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: isCompleted ? Theme.of(context).colorScheme.primary : null,
        ),
        onPressed: () => _handleCheckboxTap(context, ref, isCompleted),
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
