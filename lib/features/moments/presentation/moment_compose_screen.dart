import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/models/moment.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/moment_providers.dart';

/// Write or edit a moment for [date]. Pass [existing] to edit one
/// already written (also enables deleting it); omit it to create a new
/// one.
///
/// No photo/media picker here yet — Moment.media exists in the data
/// model for forward-compatibility (TRD §12), but attaching one needs
/// `firebase_storage` and an image picker, neither of which are
/// dependencies yet. Rather than silently drop that part of the design,
/// this screen shows a disabled affordance so it's visibly "not yet"
/// rather than absent.
class MomentComposeScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final Moment? existing;

  const MomentComposeScreen({super.key, required this.date, this.existing});

  @override
  ConsumerState<MomentComposeScreen> createState() => _MomentComposeScreenState();
}

class _MomentComposeScreenState extends ConsumerState<MomentComposeScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  LifeDomain? _domain;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _contentController = TextEditingController(text: widget.existing?.content ?? '');
    _domain = widget.existing?.domainId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    final title = _titleController.text.trim();
    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;

    setState(() => _isSubmitting = true);
    final repo = ref.read(momentRepositoryProvider);

    try {
      if (widget.existing != null) {
        await repo.updateMoment(
          widget.existing!.copyWith(
            title: title,
            clearTitle: title.isEmpty,
            content: content,
            domainId: _domain,
            clearDomain: _domain == null,
          ),
        );
      } else {
        await repo.createMoment(
          userId: userId,
          date: widget.date,
          title: title.isEmpty ? null : title,
          content: content,
          domainId: _domain,
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
        title: const Text('Delete moment?'),
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

    await ref.read(momentRepositoryProvider).deleteMoment(existing.userId, existing.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing != null ? 'Edit moment' : 'New moment'),
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
              TextField(
                controller: _titleController,
                autofocus: widget.existing == null,
                decoration: const InputDecoration(
                  hintText: 'Title (optional)',
                  border: InputBorder.none,
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Divider(),
              const SizedBox(height: 4),
              Text(
                'About this moment',
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
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    hintText: 'What happened?',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Visibly present-but-disabled rather than silently
              // missing — see this screen's class-level doc comment.
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photo (coming soon)'),
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
