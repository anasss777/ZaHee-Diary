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

/// Month calendar (TRD §14). Each day is shaded by completion status
/// (none / partial / complete) using [monthDayProgressProvider]; tapping
/// a day opens its daily record.
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

  @override
  Widget build(BuildContext context) {
    final dayProgress = ref.watch(monthDayProgressProvider(_visibleMonth));
    final today = GoalCompletion.normalizeDate(DateTime.now());

    // Dart's DateTime.weekday is 1=Monday..7=Sunday, matching the
    // Mon-first week the TRD's calendar mockup (§14) uses.
    final leadingBlanks = _visibleMonth.weekday - 1;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text(
                    '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in _weekdayLabels)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                ),
                itemCount: leadingBlanks + daysInMonth,
                itemBuilder: (context, index) {
                  if (index < leadingBlanks) return const SizedBox.shrink();

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
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DailyRecordScreen(date: day),
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),
              const _Legend(),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;

    Color? fillColor;
    if (!isFuture && progress != null && progress!.total > 0) {
      if (progress!.completed >= progress!.total) {
        fillColor = scheme.primary;
      } else if (progress!.completed > 0) {
        fillColor = scheme.primaryContainer;
      }
    }

    final textColor = fillColor == scheme.primary
        ? scheme.onPrimary
        : isFuture
        ? scheme.outline
        : null;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            border: isToday
                ? Border.all(color: scheme.primary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text('$dayNumber', style: TextStyle(color: textColor)),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendDot(color: scheme.primary, label: 'All done'),
        const SizedBox(width: 16),
        _LegendDot(color: scheme.primaryContainer, label: 'Partial'),
        const SizedBox(width: 16),
        _LegendDot(color: Colors.transparent, label: 'None', outlined: true),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;
  const _LegendDot({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: outlined
                ? Border.all(color: Theme.of(context).colorScheme.outline)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
