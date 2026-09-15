import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zahee/features/goals/presentation/providers/goal_completion_providers.dart';

import '../../../core/models/goal_completion.dart';
import 'daily_record_screen.dart';
import 'providers/history_providers.dart';

const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();

    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final dayProgress = ref.watch(monthDayProgressProvider(_visibleMonth));

    final today = GoalCompletion.normalizeDate(DateTime.now());

    final leadingBlanks = _visibleMonth.weekday - 1;

    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    final isCurrentMonth =
        _visibleMonth.year == today.year && _visibleMonth.month == today.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!isCurrentMonth)
            TextButton(onPressed: _goToToday, child: const Text('Today')),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ─────────────────────────────────────────
            // Month header
            // ─────────────────────────────────────────
            _MonthHeader(
              month: _monthNames[_visibleMonth.month - 1],
              year: _visibleMonth.year,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),

            const SizedBox(height: 18),

            // ─────────────────────────────────────────
            // Calendar
            // ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 18),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  // Weekdays
                  Row(
                    children: [
                      for (final label in _weekdayLabels)
                        Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Days
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: leadingBlanks + daysInMonth,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemBuilder: (context, index) {
                      if (index < leadingBlanks) {
                        return const SizedBox.shrink();
                      }

                      final dayNumber = index - leadingBlanks + 1;

                      final day = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        dayNumber,
                      );

                      final progress = dayProgress[day];

                      final isToday = day == today;

                      final isFuture = day.isAfter(today);

                      return _DayCell(
                        dayNumber: dayNumber,
                        progress: progress,
                        isToday: isToday,
                        isFuture: isFuture,
                        onTap: isFuture
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        DailyRecordScreen(date: day),
                                  ),
                                );
                              },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─────────────────────────────────────────
            // Legend
            // ─────────────────────────────────────────
            const _Legend(),

            const SizedBox(height: 20),

            // ─────────────────────────────────────────
            // Small explanatory card
            // ─────────────────────────────────────────
            _HistoryHint(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Month header
// ═══════════════════════════════════════════════════════

class _MonthHeader extends StatelessWidget {
  final String month;
  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      children: [
        _MonthButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous month',
          onPressed: onPrevious,
        ),

        Expanded(
          child: Column(
            children: [
              Text(
                month,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$year',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        _MonthButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next month',
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _MonthButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MonthButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 23,
      style: IconButton.styleFrom(
        minimumSize: const Size(46, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Day cell
// ═══════════════════════════════════════════════════════

class _DayCell extends StatelessWidget {
  final int dayNumber;
  final DomainProgress? progress;
  final bool isToday;
  final bool isFuture;
  final VoidCallback? onTap;

  const _DayCell({
    required this.dayNumber,
    required this.progress,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasGoals = !isFuture && progress != null && progress!.total > 0;

    final isComplete = hasGoals && progress!.completed >= progress!.total;

    final isPartial = hasGoals && progress!.completed > 0 && !isComplete;

    final double completion = hasGoals
        ? (progress!.completed / progress!.total).clamp(0.0, 1.0)
        : 0.0;

    final Color backgroundColor;

    if (isComplete) {
      backgroundColor = scheme.primary;
    } else if (isPartial) {
      backgroundColor = scheme.primaryContainer.withValues(alpha: 0.8);
    } else {
      backgroundColor = scheme.surfaceContainerHighest.withValues(alpha: 0.38);
    }

    final Color foregroundColor;

    if (isComplete) {
      foregroundColor = scheme.onPrimary;
    } else if (isFuture) {
      foregroundColor = scheme.onSurfaceVariant.withValues(alpha: 0.45);
    } else {
      foregroundColor = scheme.onSurface;
    }

    return Semantics(
      label: 'Day $dayNumber',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(17),
            border: isToday
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle completion ring
              if (hasGoals && !isComplete)
                SizedBox(
                  width: 33,
                  height: 33,
                  child: CircularProgressIndicator(
                    value: completion,
                    strokeWidth: 2.5,
                    color: scheme.primary,
                    backgroundColor: scheme.primary.withValues(alpha: 0.10),
                  ),
                ),

              Text(
                '$dayNumber',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isToday || isComplete
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: foregroundColor,
                ),
              ),

              // Today's small indicator
              if (isToday)
                Positioned(
                  bottom: 5,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isComplete ? scheme.onPrimary : scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Legend
// ═══════════════════════════════════════════════════════

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 10,
      children: [
        _LegendItem(color: scheme.primary, label: 'Complete'),
        _LegendItem(color: scheme.primaryContainer, label: 'Partial'),
        _LegendItem(color: scheme.surfaceContainerHighest, label: 'No goals'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// Hint
// ═══════════════════════════════════════════════════════

class _HistoryHint extends StatelessWidget {
  const _HistoryHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, size: 21, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap any past day to see your goals, '
              'reflections, and moments.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
