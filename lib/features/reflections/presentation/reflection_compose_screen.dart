import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/models/reflection.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/reflection_providers.dart';

class ReflectionComposeScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final Reflection? existing;

  const ReflectionComposeScreen({super.key, required this.date, this.existing});

  @override
  ConsumerState<ReflectionComposeScreen> createState() =>
      _ReflectionComposeScreenState();
}

class _ReflectionComposeScreenState
    extends ConsumerState<ReflectionComposeScreen> {
  late final TextEditingController _contentController;

  LifeDomain? _domain;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    _contentController = TextEditingController(
      text: widget.existing?.content ?? '',
    );

    _domain = widget.existing?.domainId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) {
    const months = [
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

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return '${weekdays[date.weekday - 1]}, '
        '${months[date.month - 1]} ${date.day}';
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();

    if (content.isEmpty) {
      FocusScope.of(context).unfocus();
      return;
    }

    final userId = ref.read(authStateChangesProvider).value?.id;

    if (userId == null) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    final repo = ref.read(reflectionRepositoryProvider);

    try {
      if (_isEditing) {
        await repo.updateReflection(
          widget.existing!.copyWith(
            content: content,
            domainId: _domain,
            clearDomain: _domain == null,
          ),
        );
      } else {
        await repo.createReflection(
          userId: userId,
          domainId: _domain,
          date: widget.date,
          content: content,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;

    if (existing == null) return;

    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Delete reflection?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text('This reflection will be permanently deleted.'),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(reflectionRepositoryProvider)
          .deleteReflection(existing.userId, existing.id);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete this reflection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit reflection' : 'New reflection',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete reflection',
              onPressed: _isSubmitting ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─────────────────────────────────
                    // Date
                    // ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.55,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _dateLabel(widget.date),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─────────────────────────────────
                    // Intro
                    // ─────────────────────────────────
                    Text(
                      'Take a moment to reflect',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'Write down what is on your mind.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─────────────────────────────────
                    // Domain selector
                    // ─────────────────────────────────
                    Text(
                      'This reflection is about',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 10),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _DomainChip(
                            emoji: '🌿',
                            label: 'Whole day',
                            selected: _domain == null,
                            onSelected: () {
                              setState(() {
                                _domain = null;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          for (final domain in LifeDomain.values) ...[
                            _DomainChip(
                              emoji: domain.emoji,
                              label: domain.label,
                              selected: _domain == domain,
                              onSelected: () {
                                setState(() {
                                  _domain = domain;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ─────────────────────────────────
                    // Writing area
                    // ─────────────────────────────────
                    Container(
                      constraints: const BoxConstraints(minHeight: 360),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.38,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                      child: TextField(
                        controller: _contentController,
                        autofocus: !_isEditing,
                        maxLines: null,
                        minLines: 13,
                        textCapitalization: TextCapitalization.sentences,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText:
                              'What are you thinking about?\n\nYou can write about your day, something you learned, a feeling, a challenge, or anything that matters to you.',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.65,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'A private space for your thoughts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ───────────────────────────────────────
            // Bottom save action
            // ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded),
                            const SizedBox(width: 8),
                            Text(
                              _isEditing ? 'Save changes' : 'Save reflection',
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Domain chip
// ═══════════════════════════════════════════════════════════

class _DomainChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _DomainChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: Text(emoji, style: const TextStyle(fontSize: 16)),
      label: Text(label),
      showCheckmark: true,
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selectedColor: scheme.primaryContainer,
      side: BorderSide(
        color: selected
            ? scheme.primary.withValues(alpha: 0.3)
            : scheme.outlineVariant.withValues(alpha: 0.6),
      ),
    );
  }
}
