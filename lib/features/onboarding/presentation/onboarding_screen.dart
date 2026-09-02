import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/goal.dart';
import '../../../core/models/life_domain.dart';
import '../../../core/models/subcategory.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../goals/presentation/goal_form_screen.dart';
import '../../goals/presentation/providers/goal_providers.dart';
import '../../subcategories/presentation/providers/subcategory_providers.dart';

/// The first-run flow (TRD §20): intro, the four fixed domains (with
/// their seeded default subsections), creating a few initial goals,
/// then done. Notification preferences (Step 5) is still skipped — the
/// Notifications feature doesn't exist yet, so there's nothing real to
/// configure there.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isFinishing = false;

  static const _stepCount = 3;

  @override
  void initState() {
    super.initState();
    _seedDefaultSubcategories();
  }

  /// Fire-and-forget: seedDefaultsIfNeeded is itself a no-op for anyone
  /// who already has subcategories (including a returning user who's
  /// customized theirs), so it's safe to call unconditionally on every
  /// onboarding visit rather than tracking "have I seeded yet" separately.
  Future<void> _seedDefaultSubcategories() async {
    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;
    await ref.read(subcategoryRepositoryProvider).seedDefaultsIfNeeded(userId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    final userId = ref.read(authStateChangesProvider).value?.id;
    if (userId == null) return;

    setState(() => _isFinishing = true);
    try {
      await ref.read(authRepositoryProvider).completeOnboarding(userId);
      // No manual navigation: the router's redirect logic reacts to the
      // live AppUser stream and moves to /today on its own once
      // hasCompletedOnboarding flips to true.
    } finally {
      if (mounted) setState(() => _isFinishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepDots(current: _step, count: _stepCount),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _IntroStep(onNext: () => _goToStep(1)),
                  _DomainsStep(
                    onBack: () => _goToStep(0),
                    onNext: () => _goToStep(2),
                  ),
                  _GoalsStep(
                    onBack: () => _goToStep(1),
                    onFinish: _isFinishing ? null : _finish,
                    isFinishing: _isFinishing,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final int count;
  const _StepDots({required this.current, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isActive = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _IntroStep extends StatelessWidget {
  final VoidCallback onNext;
  const _IntroStep({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "This isn't a diary.",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "It's a simple way to keep track of the life you're trying "
            'to build.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          FilledButton(onPressed: onNext, child: const Text('Get started')),
        ],
      ),
    );
  }
}

class _DomainsStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _DomainsStep({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subcategoriesByDomain = ref.watch(
      activeSubcategoriesByDomainProvider,
    );

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Four areas of life',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'These are always on. Each one starts with a few '
            'subsections — you can rename or add your own anytime.',
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                for (final domain in LifeDomain.values)
                  _DomainSubcategoryPreview(
                    domain: domain,
                    subcategories: subcategoriesByDomain[domain] ?? const [],
                  ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(onPressed: onNext, child: const Text('Next')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainSubcategoryPreview extends StatelessWidget {
  final LifeDomain domain;
  final List<Subcategory> subcategories;

  const _DomainSubcategoryPreview({
    required this.domain,
    required this.subcategories,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(domain.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                // Empty while seedDefaultsIfNeeded's write is still in
                // flight on the very first app launch — resolves within
                // a frame or two once the Firestore listener picks it up.
                Text(
                  subcategories.isEmpty
                      ? 'Setting up…'
                      : subcategories.map((s) => s.name).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalsStep extends ConsumerWidget {
  final VoidCallback onBack;
  final VoidCallback? onFinish;
  final bool isFinishing;

  const _GoalsStep({
    required this.onBack,
    required this.onFinish,
    required this.isFinishing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsByDomain = ref.watch(activeGoalsByDomainProvider);
    final totalGoals = goalsByDomain.values.fold(0, (sum, g) => sum + g.length);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Start small', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            "Add one or two goals for what matters most right now. "
            "You can always add more later.",
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final domain in LifeDomain.values)
                  _DomainGoalsRow(
                    domain: domain,
                    goals: goalsByDomain[domain] ?? const [],
                  ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('Back')),
              const Spacer(),
              FilledButton(
                onPressed: onFinish,
                child: isFinishing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(totalGoals == 0 ? 'Skip for now' : "I'm ready"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DomainGoalsRow extends StatelessWidget {
  final LifeDomain domain;
  final List<Goal> goals;

  const _DomainGoalsRow({required this.domain, required this.goals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(domain.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  domain.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (goals.isEmpty)
                  Text(
                    'No goals yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    goals.map((g) => g.title).join(', '),
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => GoalFormScreen(initialDomain: domain),
              ),
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
