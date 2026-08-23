import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/models/subcategory.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../subcategories/presentation/providers/subcategory_providers.dart';
import 'providers/goal_providers.dart';

/// Null-safe find, since relying on `.firstOrNull` here would depend on
/// an extension whose availability without an explicit import varies by
/// Dart version — writing it out avoids that ambiguity entirely.
Subcategory? _findById(List<Subcategory>? items, String? id) {
  if (items == null || id == null) return null;
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
}

/// Create or edit a goal. Pass an existing [goal] to edit; omit it to
/// create a new one, optionally pre-selecting [initialDomain].
class GoalFormScreen extends ConsumerStatefulWidget {
  final Goal? goal;
  final LifeDomain? initialDomain;

  const GoalFormScreen({super.key, this.goal, this.initialDomain});

  bool get isEditing => goal != null;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _targetController;
  late final TextEditingController _unitController;

  late LifeDomain _domain;
  String? _subcategoryId;
  late GoalFrequency _frequency;
  late GoalType _type;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _descriptionController = TextEditingController(
      text: goal?.description ?? '',
    );
    _targetController = TextEditingController(
      text: goal?.target?.toString() ?? '',
    );
    _unitController = TextEditingController(text: goal?.unit ?? '');
    _domain = goal?.domainId ?? widget.initialDomain ?? LifeDomain.health;
    _subcategoryId = goal?.subcategoryId;
    _frequency = goal?.frequency ?? GoalFrequency.daily;
    _type = goal?.type ?? GoalType.boolean;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _addSubcategoryInline() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New subsection'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: '${_domain.label} subsection'),
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

    if (name == null || name.isEmpty || !mounted) return;

    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;

    final existingCount = ref
        .read(activeSubcategoriesForDomainProvider(_domain))
        .length;

    final created = await ref
        .read(subcategoryRepositoryProvider)
        .createSubcategory(
          userId: userId,
          domainId: _domain,
          name: name,
          order: existingCount,
        );

    if (mounted) setState(() => _subcategoryId = created.id);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return; // Router guarantees this shouldn't happen.
    if (_subcategoryId == null) return; // Validator already caught this.

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repo = ref.read(goalRepositoryProvider);
    final target = _type == GoalType.numeric
        ? double.tryParse(_targetController.text)
        : null;
    final unit = _type == GoalType.numeric ? _unitController.text.trim() : null;

    try {
      if (widget.isEditing) {
        final updated = widget.goal!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequency,
          target: target,
          unit: unit,
        );
        await repo.updateGoal(updated);
      } else {
        // New goals go to the end of the domain's list. A proper reorder
        // UI can replace this later; for now, count existing goals.
        final existingCount = ref
            .read(activeGoalsForDomainProvider(_domain))
            .length;

        await repo.createGoal(
          userId: userId,
          domainId: _domain,
          subcategoryId: _subcategoryId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          frequency: _frequency,
          type: _type,
          target: target,
          unit: unit,
          order: existingCount,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subcategories = ref.watch(
      activeSubcategoriesForDomainProvider(_domain),
    );

    // Editing an existing goal whose subcategory has since been archived:
    // keep showing it as a selectable option rather than having it
    // silently vanish from the dropdown (which would force an unwanted
    // change just from opening the edit screen).
    final currentSubcategory =
        widget.isEditing &&
            _subcategoryId != null &&
            !subcategories.any((s) => s.id == _subcategoryId)
        ? _findById(ref.watch(allSubcategoriesProvider).value, _subcategoryId)
        : null;
    final dropdownItems = [
      ...subcategories,
      if (currentSubcategory != null) currentSubcategory,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'Edit goal' : 'New goal')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!),
                  ),
                  const SizedBox(height: 16),
                ],

                // Domain picker — locked while editing, since moving a
                // goal between domains also implies moving it between
                // subcategories.
                DropdownButtonFormField<LifeDomain>(
                  initialValue: _domain,
                  decoration: const InputDecoration(labelText: 'Domain'),
                  items: LifeDomain.values
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text('${d.emoji}  ${d.label}'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.isEditing
                      ? null
                      : (d) => setState(() {
                          _domain = d ?? _domain;
                          // Previous domain's subcategory doesn't apply
                          // to the new domain — force a fresh pick.
                          _subcategoryId = null;
                        }),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  key: ValueKey(_domain), // rebuild cleanly on domain change
                  initialValue: _subcategoryId,
                  decoration: const InputDecoration(labelText: 'Subsection'),
                  items: dropdownItems
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (id) => setState(() => _subcategoryId = id),
                  validator: (v) => v == null ? 'Choose a subsection' : null,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _addSubcategoryInline,
                    child: const Text('+ New subsection'),
                  ),
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<GoalFrequency>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: GoalFrequency.values
                      .where(
                        (f) => f != GoalFrequency.custom,
                      ) // not in MVP UI yet
                      .map(
                        (f) => DropdownMenuItem(value: f, child: Text(f.label)),
                      )
                      .toList(),
                  onChanged: (f) =>
                      setState(() => _frequency = f ?? _frequency),
                ),
                const SizedBox(height: 16),

                // Goal type is fixed once created — switching a goal from
                // boolean to numeric (or back) would orphan the meaning of
                // its existing completions' `value` field.
                SegmentedButton<GoalType>(
                  segments: const [
                    ButtonSegment(
                      value: GoalType.boolean,
                      label: Text('Simple'),
                      icon: Icon(Icons.check_circle_outline),
                    ),
                    ButtonSegment(
                      value: GoalType.numeric,
                      label: Text('Measured'),
                      icon: Icon(Icons.numbers),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: widget.isEditing
                      ? null
                      : (s) => setState(() => _type = s.first),
                ),
                const SizedBox(height: 16),

                if (_type == GoalType.numeric) ...[
                  TextFormField(
                    controller: _targetController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Target'),
                    validator: (v) {
                      if (_type != GoalType.numeric) return null;
                      if (v == null || double.tryParse(v) == null) {
                        return 'Enter a number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit (e.g. minutes, pages)',
                    ),
                    validator: (v) {
                      if (_type != GoalType.numeric) return null;
                      if (v == null || v.trim().isEmpty) return 'Enter a unit';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.isEditing ? 'Save changes' : 'Create goal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
