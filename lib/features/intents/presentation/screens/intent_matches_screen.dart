import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../providers/intent_providers.dart';

/// The "explainable match" surface (spec-extension: Matching Engine). Every
/// card must answer "why am I seeing this?" — never a bare percentage — via
/// the reasons/matched-skills breakdown from [MatchResult], now joined by a
/// real LLM-generated rationale (`ai_rationale`, see
/// `supabase/functions/ai-match-intent`) when an AI provider is configured;
/// the deterministic `reasons[]`/`scoreBreakdown` are always present as a
/// fallback either way, so this screen never depends on AI being on.
class IntentMatchesScreen extends ConsumerStatefulWidget {
  const IntentMatchesScreen({super.key, required this.intentId});

  final String intentId;

  @override
  ConsumerState<IntentMatchesScreen> createState() => _IntentMatchesScreenState();
}

class _IntentMatchesScreenState extends ConsumerState<IntentMatchesScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  Future<void> _findMatches() async {
    _revealController.reset();
    final ok = await ref.read(intentControllerProvider.notifier).findMatchesAndRecommendations(widget.intentId);
    if (!mounted) return;
    if (ok) {
      _revealController.forward();
    } else {
      context.showSnack('Could not refresh matches', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final intentAsync = ref.watch(intentDetailProvider(widget.intentId));
    final matchesAsync = ref.watch(intentMatchesProvider(widget.intentId));
    final isRefreshing = ref.watch(intentControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              maxWidth: 560,
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(intentMatchesProvider(widget.intentId)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      child: Row(
                        children: [
                          _BackButton(onTap: () => context.pop()),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Matches',
                                    style: TextStyle(
                                        fontSize: 22, fontWeight: FontWeight.w800, color: HomeStyle.textPrimary)),
                                SizedBox(height: 2),
                                Text('People who complement what you\'re looking for.',
                                    style: TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    intentAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (intent) => GradientBorderCard(
                        radius: 18,
                        gradient: LinearGradient(
                            colors: [HomeStyle.purple.withValues(alpha: 0.20), HomeStyle.blue.withValues(alpha: 0.10)]),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: HomeStyle.brandGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(intent.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 2),
                                    Text(intent.intentType.label,
                                        style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: isRefreshing
                            ? const SizedBox(width: 16, height: 16, child: _SearchingSpinner())
                            : const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: Text(isRefreshing ? 'Finding your best matches…' : 'Find Matches'),
                        onPressed: isRefreshing ? null : _findMatches,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isRefreshing)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: _FindingMatchesLoader())
                    else
                      matchesAsync.when(
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (e, _) => ErrorState(message: e.toString()),
                        data: (matches) {
                          if (matches.isEmpty) {
                            return const EmptyState(
                              icon: Icons.auto_awesome_outlined,
                              title: 'No matches yet',
                              message: 'Tap "Find Matches" to search for candidates.',
                            );
                          }
                          if (_revealController.status == AnimationStatus.dismissed) {
                            _revealController.value = 1;
                          }
                          final intentTitle = intentAsync.valueOrNull?.title ?? 'this intent';
                          return Column(
                            children: [
                              for (var i = 0; i < matches.length; i++)
                                _RevealingMatchCard(
                                  index: i,
                                  controller: _revealController,
                                  match: matches[i],
                                  intentTitle: intentTitle,
                                ),
                            ],
                          );
                        },
                      ),
                    if (!isRefreshing) _RecommendationsSection(intentId: widget.intentId),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Staggers each card's entrance off one shared [AnimationController] so a
/// fresh batch of matches feels like it's arriving, not just appearing —
/// the "moment" the plan calls for turning a few seconds of real AI latency
/// into a payoff rather than a wait.
class _RevealingMatchCard extends StatelessWidget {
  const _RevealingMatchCard({
    required this.index,
    required this.controller,
    required this.match,
    required this.intentTitle,
  });

  final int index;
  final AnimationController controller;
  final MatchResult match;
  final String intentTitle;

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.85, index * 0.12);
    final end = math.min(1.0, start + 0.5);
    final curved = CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        return Opacity(
          opacity: curved.value.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, (1 - curved.value.clamp(0, 1)) * 24), child: child),
        );
      },
      child: _MatchCard(match: match, intentTitle: intentTitle),
    );
  }
}

class _MatchCard extends ConsumerStatefulWidget {
  const _MatchCard({required this.match, required this.intentTitle});

  final MatchResult match;
  final String intentTitle;

  @override
  ConsumerState<_MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends ConsumerState<_MatchCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.push(RoutePaths.personDetailOf(m.candidateId)),
              child: Row(
                children: [
                  UserAvatar(avatarUrl: m.avatarUrl, name: m.displayName, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayName,
                            style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5)),
                        if ((m.currentRole ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(m.currentRole!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AnimatedScoreBadge(score: m.score.toDouble()),
                ],
              ),
            ),
            if (m.hasAiRationale) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HomeStyle.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 16, color: HomeStyle.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(m.aiRationale!,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 12.5, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ],
            if (m.scoreBreakdown.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CompatibilityBreakdown(breakdown: m.scoreBreakdown),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(RoutePaths.personDetailOf(m.candidateId)),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('View profile'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => openDirectConversation(
                      context,
                      ref,
                      m.candidateId,
                      prefillText: 'Hi! I saw we might be a match on my Intent: ${widget.intentTitle}',
                    ),
                    icon: const Icon(Icons.message_outlined, size: 16),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
            if (m.reasons.isNotEmpty || m.missingSkills.isNotEmpty) ...[
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Hide details' : 'See match details'),
              ),
              if (_expanded) ...[
                for (final reason in m.reasons)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('✓ ', style: TextStyle(color: HomeStyle.textSecondary)),
                        Expanded(child: Text(reason, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12.5))),
                      ],
                    ),
                  ),
                if (m.missingSkills.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Still missing: ${m.missingSkills.join(', ')}',
                      style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Counts up from 0 to the real score whenever it first appears/changes —
/// a bare static "92%" reads as a database value; watching it climb reads
/// as the system having just computed it.
class _AnimatedScoreBadge extends StatelessWidget {
  const _AnimatedScoreBadge({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${value.round()}% Match',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11.5)),
        );
      },
    );
  }
}

const _breakdownLabels = {
  'skills': 'Skills',
  'interests': 'Interests',
  'experience': 'Experience',
  'availability': 'Availability',
};

class _CompatibilityBreakdown extends StatelessWidget {
  const _CompatibilityBreakdown({required this.breakdown});

  final Map<String, num> breakdown;

  @override
  Widget build(BuildContext context) {
    final entries = _breakdownLabels.entries.where((e) => breakdown.containsKey(e.key)).toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(e.value, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (breakdown[e.key] ?? 0).toDouble().clamp(0, 1)),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        valueColor: const AlwaysStoppedAnimation(HomeStyle.cyan),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A small looping scan/search animation shown inside the "Find Matches"
/// button itself while a request is in flight.
class _SearchingSpinner extends StatefulWidget {
  const _SearchingSpinner();

  @override
  State<_SearchingSpinner> createState() => _SearchingSpinnerState();
}

class _SearchingSpinnerState extends State<_SearchingSpinner> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
    );
  }
}

/// The "we're thinking" moment — real LLM latency turned into a short,
/// reassuring narrative instead of a bare spinner.
class _FindingMatchesLoader extends StatefulWidget {
  const _FindingMatchesLoader();

  @override
  State<_FindingMatchesLoader> createState() => _FindingMatchesLoaderState();
}

class _FindingMatchesLoaderState extends State<_FindingMatchesLoader> with SingleTickerProviderStateMixin {
  static const _phases = [
    'Reading your intent…',
    'Comparing skills & interests…',
    'Asking the matching engine…',
    'Ranking your best matches…',
  ];

  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  late final Stream<int> _phaseTicker = Stream.periodic(const Duration(milliseconds: 1400), (i) => i % _phases.length);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = 0.9 + (_pulse.value * 0.15);
            return Transform.scale(scale: scale, child: child);
          },
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(gradient: HomeStyle.brandGradient, shape: BoxShape.circle),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 18),
        StreamBuilder<int>(
          stream: _phaseTicker,
          initialData: 0,
          builder: (context, snapshot) {
            final phase = _phases[snapshot.data ?? 0];
            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(phase,
                  key: ValueKey(phase),
                  style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            );
          },
        ),
      ],
    );
  }
}

/// "Because of this match" — the cross-entity ("Communeo Intelligence")
/// layer on top of people matching: communities/events/projects/posts a
/// top match is visibly, publicly involved with. Deliberately non-fatal —
/// a loading/error state here never blocks or clutters the person-matches
/// list above it, since this is an enhancement layer, not the core feature.
class _RecommendationsSection extends ConsumerWidget {
  const _RecommendationsSection({required this.intentId});

  final String intentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recsAsync = ref.watch(intentRecommendationsProvider(intentId));
    return recsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (recs) {
        if (recs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Because of this match',
                  style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              const Text('Communities, events, projects, and posts connected to your Intent through your matches.',
                  style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
              const SizedBox(height: 12),
              for (final rec in recs) _RecommendationCard(recommendation: rec),
            ],
          ),
        );
      },
    );
  }
}

const _recommendationIcons = {
  RecommendationType.community: Icons.groups_rounded,
  RecommendationType.event: Icons.event_rounded,
  RecommendationType.project: Icons.rocket_launch_rounded,
  RecommendationType.post: Icons.article_rounded,
};

const _recommendationActionLabels = {
  RecommendationType.community: 'Explore',
  RecommendationType.event: 'View Event',
  RecommendationType.project: 'View Project',
  RecommendationType.post: 'Read Post',
};

class _RecommendationCard extends StatefulWidget {
  const _RecommendationCard({required this.recommendation});

  final IntentRecommendation recommendation;

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _expanded = false;

  void _open(BuildContext context) {
    final r = widget.recommendation;
    final path = switch (r.recommendationType) {
      RecommendationType.community => RoutePaths.communityDetailOf(r.targetId),
      RecommendationType.event => RoutePaths.eventDetailOf(r.targetId),
      RecommendationType.project => RoutePaths.projectDetailOf(r.targetId),
      RecommendationType.post => RoutePaths.postDetailOf(r.targetId),
    };
    context.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recommendation;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: HomeStyle.blue.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_recommendationIcons[r.recommendationType], color: HomeStyle.blue, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.recommendationType.label.toUpperCase(),
                          style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      const SizedBox(height: 2),
                      Text(r.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (r.hasAiRationale) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: HomeStyle.purple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: HomeStyle.purple.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: HomeStyle.purple),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(r.aiRationale!, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 12, height: 1.35)),
                    ),
                  ],
                ),
              ),
            ] else if (r.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(r.reasons.first, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12, height: 1.3)),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(_expanded ? 'Hide why' : 'Why am I seeing this?'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _open(context),
                    child: Text(_recommendationActionLabels[r.recommendationType]!),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              for (final reason in r.reasons)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('✓ ', style: TextStyle(color: HomeStyle.textSecondary)),
                      Expanded(child: Text(reason, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: const Icon(Icons.arrow_back_rounded, size: 21, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
