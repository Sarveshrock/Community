import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart' show GlowBackdrop;
import '../../../profile/presentation/providers/profile_providers.dart';
import '../providers/people_providers.dart';
import '../widgets/people_style.dart';
import '../widgets/person_card.dart';

/// One People screen with two independent selectors, per the redesign
/// brief: [PeopleCategory] ("who am I looking for?" — All/Developer/
/// Professional/Student/Job Seeker/Fresher) and the All/Recommended
/// `TabController` ("how should they be surfaced?"). Neither resets the
/// other — [peopleCategoryProvider] lives outside this widget's state and
/// the `TabController`'s index is untouched by category taps, so switching
/// one always keeps whatever the other was set to.
///
/// There has never been a separate route for "All" vs. "Recommended" in
/// this app (`RoutePaths.people` -> this screen is the only People route) —
/// they were already a `TabBarView` inside one screen. This redesign adds
/// the category dimension on top of that, it doesn't need to remove or
/// merge any routes.
class PeopleListScreen extends ConsumerStatefulWidget {
  const PeopleListScreen({super.key});

  @override
  ConsumerState<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends ConsumerState<PeopleListScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PeopleStyle.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _PeopleFiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PeopleStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(onFilterTap: _openFilters),
                  const _CategoryChips(),
                  const SizedBox(height: 4),
                  _ModeTabs(controller: _tabController),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [_AllPeopleTab(), _RecommendedPeopleTab()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () => context.pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'People',
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 360 ? 22 : 25,
                    fontWeight: FontWeight.w800,
                    color: PeopleStyle.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Find and connect with amazing people',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, height: 1.25, color: PeopleStyle.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.tune_rounded,
            tooltip: 'Filters',
            highlighted: true,
            onTap: onFilterTap,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: highlighted ? PeopleStyle.selectedChipGradient : null,
            color: highlighted ? null : PeopleStyle.card,
            borderRadius: BorderRadius.circular(13),
            border: highlighted ? null : Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: highlighted ? PeopleStyle.glow(PeopleStyle.purple, opacity: 0.3) : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onTap,
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(peopleCategoryProvider);
    // A plain Row in a SingleChildScrollView, not a lazily-virtualized
    // ListView — matching the same pattern the News screen's filter chips
    // already use (news_list_screen.dart). Six chips is a trivial, fixed
    // set; eagerly building all of them avoids any of them being skipped
    // by viewport/cache-extent virtualization before the user scrolls.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final category in PeopleCategory.values) ...[
              _CategoryChip(
                category: category,
                isSelected: category == selected,
                onTap: () => ref.read(peopleCategoryProvider.notifier).state = category,
              ),
              if (category != PeopleCategory.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.isSelected, required this.onTap});

  final PeopleCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon => switch (category) {
        PeopleCategory.all => Icons.groups_rounded,
        PeopleCategory.developer => Icons.code_rounded,
        PeopleCategory.professional => Icons.business_center_outlined,
        PeopleCategory.student => Icons.school_outlined,
        PeopleCategory.jobSeeker => Icons.search_rounded,
        PeopleCategory.fresher => Icons.person_add_alt_1_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected ? PeopleStyle.selectedChipGradient : null,
            color: isSelected ? null : PeopleStyle.card.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(100),
            border: isSelected ? null : Border.all(color: PeopleStyle.border),
            boxShadow: isSelected ? PeopleStyle.glow(PeopleStyle.purple, opacity: 0.28) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 16, color: isSelected ? Colors.white : PeopleStyle.textSecondary),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : PeopleStyle.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorColor: PeopleStyle.brightPurple,
        indicatorWeight: 3,
        labelColor: PeopleStyle.brightPurple,
        unselectedLabelColor: PeopleStyle.textMuted,
        labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
        tabs: const [Tab(text: 'All'), Tab(text: 'Recommended')],
      ),
    );
  }
}

String _emptyTitle(PeopleCategory category, {required bool recommended}) {
  if (category == PeopleCategory.all) {
    return recommended ? 'No recommendations yet' : 'No matching people yet';
  }
  return recommended ? 'No recommended ${category.label}s found' : 'No ${category.label}s found';
}

const _emptyMessageAll = 'Try another category or switch to All.';
const _emptyMessageRecommended = 'Try another category, or complete your profile for better matches.';

class _AllPeopleTab extends ConsumerWidget {
  const _AllPeopleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(peopleSearchResultsProvider);
    final category = ref.watch(peopleCategoryProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(peopleSearchResultsProvider),
      child: resultsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(peopleSearchResultsProvider)),
        data: (people) {
          if (people.isEmpty) {
            return EmptyState(
              icon: Icons.people_alt_outlined,
              title: _emptyTitle(category, recommended: false),
              message: _emptyMessageAll,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => PersonCard(profile: people[i]),
          );
        },
      ),
    );
  }
}

class _RecommendedPeopleTab extends ConsumerWidget {
  const _RecommendedPeopleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recAsync = ref.watch(aiRecommendedPeopleProvider);
    final category = ref.watch(peopleCategoryProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(aiRecommendedPeopleProvider),
      child: recAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(aiRecommendedPeopleProvider)),
        data: (recommendations) {
          if (recommendations.isEmpty) {
            return EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: _emptyTitle(category, recommended: true),
              message: _emptyMessageRecommended,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final rec = recommendations[i];
              final profileAsync =
                  ref.watch(profileByIdProvider(rec['candidate_id'] as String));
              return profileAsync.when(
                loading: () => const SizedBox(height: 88),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => PersonCard(
                  profile: profile,
                  matchScore: (rec['score'] as num?)?.toDouble(),
                  matchReason: rec['reason'] as String?,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PeopleFiltersSheet extends ConsumerStatefulWidget {
  const _PeopleFiltersSheet();

  @override
  ConsumerState<_PeopleFiltersSheet> createState() =>
      _PeopleFiltersSheetState();
}

class _PeopleFiltersSheetState extends ConsumerState<_PeopleFiltersSheet> {
  late final _cityController =
      TextEditingController(text: ref.read(peopleFiltersProvider).city);
  late final _queryController =
      TextEditingController(text: ref.read(peopleFiltersProvider).query);

  @override
  void dispose() {
    _cityController.dispose();
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filters',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PeopleStyle.textPrimary)),
          const SizedBox(height: 16),
          _FilterField(
            controller: _queryController,
            hint: 'Name, role, or company',
          ),
          const SizedBox(height: 12),
          _FilterField(controller: _cityController, hint: 'City'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PeopleStyle.textPrimary,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    ref.read(peopleFiltersProvider.notifier).state =
                        const PeopleFilters();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      ref.read(peopleFiltersProvider.notifier).state =
                          PeopleFilters(
                        query: _queryController.text.trim().isEmpty
                            ? null
                            : _queryController.text.trim(),
                        city: _cityController.text.trim().isEmpty
                            ? null
                            : _cityController.text.trim(),
                      );
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: PeopleStyle.selectedChipGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Apply',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PeopleStyle.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: PeopleStyle.textPrimary, fontSize: 14.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: PeopleStyle.textMuted),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
