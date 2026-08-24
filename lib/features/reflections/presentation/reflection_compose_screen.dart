import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/models/reflection.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/reflection_providers.dart';

/// Write or edit a reflection for [date]. Pass [existing] to edit one
/// already written (also enables deleting it); omit it to create a new
/// one. Deliberately minimal — a domain chip row and a text field, no
/// mood/tags/attachments (TRD §11 lists those, but keeping this MVP
/// screen fast to open and close matters more than completeness here).
class ReflectionComposeScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final Reflection? existing;

  const ReflectionComposeScreen({super.key, required this.date, this.existing});

  @override
  ConsumerState<ReflectionComposeScreen> createState() => _ReflectionComposeScreenState();
}

class _ReflectionComposeScreenState extends ConsumerState<ReflectionComposeScreen> {
  late final TextEditingController _contentController;
  LifeDomain? _domain;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.existing?.content ?? '');
    _domain = widget.existing?.domainId;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(reflectionRepositoryProvider);

    try {
      if (widget.existing != null) {
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
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete reflection?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(reflectionRepositoryProvider).deleteReflection(
          existing.userId,
          existing.id,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit reflection' : 'New reflection'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'About this reflection',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Whole day'),
                    selected: _domain == null,
                    onSelected: (_) => setState(() => _domain = null),
                  ),
                  for (final domain in LifeDomain.values)
                    ChoiceChip(
                      avatar: Text(domain.emoji),
                      label: Text(domain.label),
                      selected: _domain == domain,
                      onSelected: (_) => setState(() => _domain = domain),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: TextField(
                  controller: _contentController,
                  autofocus: widget.existing == null,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'What are you thinking about?',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _save,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
