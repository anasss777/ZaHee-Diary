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
    // Watching this triggers the initial load; the actual grouped data
    // each section reads comes from activeSubcategoriesForDomainProvider
    // so per-domain reorders don't rebuild sections that didn't change.
    ref.watch(allSubcategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subsections')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final domain in LifeDomain.values)
            _DomainSubcategorySection(domain: domain),
        ],
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
      builder: (context) => AlertDialog(
        title: const Text('New subsection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;

    final existingCount = ref
        .read(activeSubcategoriesForDomainProvider(domain))
        .length;

    await ref
        .read(subcategoryRepositoryProvider)
        .createSubcategory(
          userId: userId,
          domainId: domain,
          name: name,
          order: existingCount,
        );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Subcategory subcategory,
  ) async {
    final controller = TextEditingController(text: subcategory.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || name == subcategory.name) return;

    await ref
        .read(subcategoryRepositoryProvider)
        .updateSubcategory(subcategory.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategories = ref.watch(
      activeSubcategoriesForDomainProvider(domain),
    );
    final repo = ref.read(subcategoryRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${domain.emoji}  ${domain.label}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                onPressed: () => _addSubcategory(context, ref),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        if (subcategories.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text('No subsections yet'),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: subcategories.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = List<Subcategory>.from(subcategories);
              if (newIndex > oldIndex) newIndex -= 1;
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              repo.reorderSubcategories(moved.userId, reordered);
            },
            itemBuilder: (context, index) {
              final subcategory = subcategories[index];
              return ListTile(
                key: ValueKey(subcategory.id),
                title: Text(subcategory.name),
                onTap: () => _rename(context, ref, subcategory),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'archive') {
                      repo.archiveSubcategory(
                        subcategory.userId,
                        subcategory.id,
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'archive', child: Text('Archive')),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
