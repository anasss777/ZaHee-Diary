import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/life_domain.dart';
import '../../../core/models/subcategory.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import 'providers/subcategory_providers.dart';

class SubcategoriesScreen extends ConsumerWidget {
  const SubcategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure the complete subcategory collection is loaded.
    ref.watch(allSubcategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subsections',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: LifeDomain.values.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          return _DomainSubcategorySection(domain: LifeDomain.values[index]);
        },
      ),
    );
  }
}

class _DomainSubcategorySection extends ConsumerWidget {
  final LifeDomain domain;

  const _DomainSubcategorySection({required this.domain});

  Future<void> _addSubcategory(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'New subsection',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Exercise',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();

              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();

                if (trimmed.isEmpty) return;

                Navigator.of(dialogContext).pop(trimmed);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) return;

    final userId = ref.read(authStateChangesProvider).value?.id;

    if (userId == null) return;

    final existingSubcategories = ref.read(
      activeSubcategoriesForDomainProvider(domain),
    );

    final order = existingSubcategories.length;

    await ref
        .read(subcategoryRepositoryProvider)
        .createSubcategory(
          userId: userId,
          domainId: domain,
          name: name,
          order: order,
        );

    // Explicitly refresh the relevant providers.
    ref.invalidate(allSubcategoriesProvider);
    ref.invalidate(activeSubcategoriesForDomainProvider(domain));
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Subcategory subcategory,
  ) async {
    final controller = TextEditingController(text: subcategory.name);

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Rename subsection',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            onSubmitted: (value) {
              final trimmed = value.trim();

              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final trimmed = controller.text.trim();

                if (trimmed.isEmpty) return;

                Navigator.of(dialogContext).pop(trimmed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty || name == subcategory.name) {
      return;
    }

    await ref
        .read(subcategoryRepositoryProvider)
        .updateSubcategory(subcategory.copyWith(name: name));

    // Refresh the changed domain.
    ref.invalidate(allSubcategoriesProvider);
    ref.invalidate(activeSubcategoriesForDomainProvider(subcategory.domainId));
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Subcategory subcategory,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Archive subsection?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            '“${subcategory.name}” will be removed from your active subsections.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
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
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await ref
        .read(subcategoryRepositoryProvider)
        .archiveSubcategory(subcategory.userId, subcategory.id);

    ref.invalidate(allSubcategoriesProvider);
    ref.invalidate(activeSubcategoriesForDomainProvider(subcategory.domainId));
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<Subcategory> subcategories,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final reordered = List<Subcategory>.from(subcategories);

    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    await ref
        .read(subcategoryRepositoryProvider)
        .reorderSubcategories(moved.userId, reordered);

    // Refresh both the global collection and this domain.
    ref.invalidate(allSubcategoriesProvider);
    ref.invalidate(activeSubcategoriesForDomainProvider(domain));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final subcategories = ref.watch(
      activeSubcategoriesForDomainProvider(domain),
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─────────────────────────────────────────────
          // Header
          // ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    domain.emoji,
                    style: const TextStyle(fontSize: 23),
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        domain.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subcategories.isEmpty
                            ? 'No subsections yet'
                            : '${subcategories.length} '
                                  '${subcategories.length == 1 ? 'subsection' : 'subsections'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                IconButton.filledTonal(
                  tooltip: 'Add subsection',
                  onPressed: () => _addSubcategory(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),

          // ─────────────────────────────────────────────
          // Empty state
          // ─────────────────────────────────────────────
          if (subcategories.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Row(
                children: [
                  Icon(
                    Icons.add_task_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add a subsection to organize your goals.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // ─────────────────────────────────────────────
          // Subsections
          // ─────────────────────────────────────────────
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: subcategories.length,
              buildDefaultDragHandles: false,

              // IMPORTANT:
              // Use Flutter's standard onReorder callback.
              onReorder: (oldIndex, newIndex) {
                _reorder(ref, subcategories, oldIndex, newIndex);
              },

              itemBuilder: (context, index) {
                final subcategory = subcategories[index];

                return _SubcategoryRow(
                  key: ValueKey(subcategory.id),
                  index: index,
                  subcategory: subcategory,
                  onRename: () => _rename(context, ref, subcategory),
                  onArchive: () => _archive(context, ref, subcategory),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// Subcategory row
// ═══════════════════════════════════════════════════════════

class _SubcategoryRow extends StatelessWidget {
  final int index;
  final Subcategory subcategory;
  final VoidCallback onRename;
  final VoidCallback onArchive;

  const _SubcategoryRow({
    super.key,
    required this.index,
    required this.subcategory,
    required this.onRename,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRename,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 5, 8, 5),
          child: Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 21,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Subsection icon
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 19,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  subcategory.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Menu
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  if (value == 'rename') {
                    onRename();
                  } else if (value == 'archive') {
                    onArchive();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child: Row(
                      children: [
                        Icon(Icons.archive_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Archive'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
