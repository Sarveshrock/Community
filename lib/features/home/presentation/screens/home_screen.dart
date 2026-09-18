import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../intents/presentation/providers/intent_providers.dart';
import '../../../notifications/presentation/providers/notification_providers.dart';
import '../../../settings/presentation/providers/app_icon_providers.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../providers/home_providers.dart';
import '../widgets/community_stats.dart';
import '../widgets/greeting_section.dart';
import '../widgets/home_action_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_style.dart';
import '../widgets/inspiration_card.dart';
import '../widgets/intent_hero_card.dart';

/// Personalized home (spec sections 59 & 92) answering "what can I do here
/// right now?" up front, rather than a chronological social feed.
///
/// Mobile-first: one [CustomScrollView] with independently scrolling
/// carousels, sized from the current breakpoint. [ResponsiveCenter] caps and
/// centres the same tree on tablet/desktop rather than duplicating layouts.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(homeHackathonsPreviewProvider);
    ref.invalidate(homeJobsPreviewProvider);
    ref.invalidate(homeProjectsPreviewProvider);
    ref.invalidate(homePostsPreviewProvider);
    ref.invalidate(pendingConnectionRequestsCountProvider);
    ref.invalidate(communityStatsProvider);
    ref.invalidate(myIntentsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Re-applies the signed-in user's saved app-icon preference to *this*
    // device if it isn't already active here (e.g. a fresh install/new
    // device) — a one-time, side-effect-only watch; it renders nothing.
    ref.watch(appIconSyncProvider);
    // Requests notification permission and registers this device's FCM
    // token so the notifications already written server-side also reach the
    // phone's notification bar, not just the in-app Notifications screen —
    // same one-time, side-effect-only watch pattern as the app-icon sync
    // above; a no-op wherever Firebase isn't configured for this build.
    ref.watch(pushNotificationSyncProvider);

    final isMobile = Responsive.screenSizeOf(context) == ScreenSize.mobile;
    final hPad = isMobile ? 16.0 : 20.0;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              backgroundColor: HomeStyle.cardBase,
              color: HomeStyle.purple,
              onRefresh: () => _refresh(ref),
              child: ResponsiveCenter(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
                      sliver: SliverList.list(
                        children: const [
                          HomeHeader(),
                          SizedBox(height: 18),
                          GreetingSection(),
                          SizedBox(height: 18),
                          IntentHeroCard(),
                          SizedBox(height: 14),
                          _PendingConnectionsCard(),
                          _ActionGrid(),
                          SizedBox(height: 14),
                          _SecondaryActionsRow(),
                          SizedBox(height: 18),
                          InspirationCard(),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: CommunityStatsRow(horizontalPadding: hPad),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 26)),
                    _HackathonsSection(hPad: hPad, isMobile: isMobile),
                    _JobsSection(hPad: hPad, isMobile: isMobile),
                    _ProjectsSection(hPad: hPad, isMobile: isMobile),
                    _PostsSection(hPad: hPad),
                    // Clears the raised Create button that overhangs the
                    // navigation bar.
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
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


class _PendingConnectionsCard extends ConsumerWidget {
  const _PendingConnectionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count =
        ref.watch(pendingConnectionRequestsCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GradientBorderCard(
        radius: 14,
        gradient: LinearGradient(colors: [
          HomeStyle.purple.withValues(alpha: 0.5),
          HomeStyle.blue.withValues(alpha: 0.2),
        ]),
        onTap: () => context.push(RoutePaths.connections),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.person_add_alt_1,
                  size: 18, color: HomeStyle.purple),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count pending connection request${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: HomeStyle.textPrimary,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: HomeStyle.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Six feature cards, two per row. Uses an [IntrinsicHeight] row pair so both
/// cards in a row match height without a fixed aspect ratio that would clip
/// text at large font scales.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 340;
    const spacing = 12.0;

    final rows = <Widget>[];
    for (var i = 0; i < homeActions.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : spacing),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: HomeActionCard(
                        action: homeActions[i], compact: compact)),
                const SizedBox(width: spacing),
                Expanded(
                    child: HomeActionCard(
                        action: homeActions[i + 1], compact: compact)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

/// Startup Opportunities / Meet Someone Nearby / Read What's New — kept on
/// Home as compact pills so those existing features stay reachable.
class _SecondaryActionsRow extends StatelessWidget {
  const _SecondaryActionsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final action in secondaryActions)
          SecondaryActionChip(action: action),
      ],
    );
  }
}

// ============================================================================
// Content sections
// ============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(
      {required this.title, required this.onSeeAll, this.trailing});

  final String title;
  final VoidCallback onSeeAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: HomeStyle.textPrimary,
              )),
        ),
        if (trailing != null) trailing!,
        TextButton(
          onPressed: onSeeAll,
          child: const Text('See all',
              style: TextStyle(color: HomeStyle.purple, fontSize: 13)),
        ),
      ],
    );
  }
}

/// One horizontally scrolling row of preview cards, with the four async
/// states handled in one place instead of repeated per section.
class _PreviewCarousel extends StatelessWidget {
  const _PreviewCarousel({
    required this.items,
    required this.itemBuilder,
    required this.emptyLabel,
    required this.onRetry,
    required this.isMobile,
    required this.hPad,
  });

  final AsyncValue<List<Map<String, dynamic>>> items;
  final Widget Function(BuildContext, Map<String, dynamic>, double width)
      itemBuilder;
  final String emptyLabel;
  final VoidCallback onRetry;
  final bool isMobile;
  final double hPad;

  @override
  Widget build(BuildContext context) {
    // Leaves a sliver of the next card visible on phones — a cheap, standard
    // affordance that tells the user the row scrolls.
    final cardWidth = isMobile
        ? math.min(232.0, MediaQuery.sizeOf(context).width * 0.62)
        : 220.0;
    // Scales with the user's font setting so large accessibility text can't
    // overflow a hardcoded height.
    final height =
        100.0 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.4);

    return SizedBox(
      height: height,
      child: items.when(
        loading: () => _CarouselSkeleton(width: cardWidth, hPad: hPad),
        error: (_, __) => Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Couldn\'t load — retry'),
              onPressed: onRetry,
            ),
          ),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(emptyLabel,
                    style: const TextStyle(
                        fontSize: 13, color: HomeStyle.textSecondary)),
              ),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) =>
                itemBuilder(context, rows[i], cardWidth),
          );
        },
      ),
    );
  }
}

class _CarouselSkeleton extends StatelessWidget {
  const _CarouselSkeleton({required this.width, required this.hPad});

  final double width;
  final double hPad;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: HomeStyle.cardBase,
      highlightColor: const Color(0xFF1A2038),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => Container(
          width: width,
          decoration: BoxDecoration(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.width,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final double width;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: GradientBorderCard(
        radius: 16,
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.4),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: HomeStyle.textPrimary,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: HomeStyle.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HackathonsSection extends ConsumerWidget {
  const _HackathonsSection({required this.hPad, required this.isMobile});

  final double hPad;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad, right: hPad - 8),
            child: _SectionHeader(
                title: 'Hackathons',
                onSeeAll: () => context.push(RoutePaths.hackathons)),
          ),
          const SizedBox(height: 6),
          _PreviewCarousel(
            items: ref.watch(homeHackathonsPreviewProvider),
            emptyLabel: 'No hackathons yet',
            onRetry: () => ref.invalidate(homeHackathonsPreviewProvider),
            isMobile: isMobile,
            hPad: hPad,
            itemBuilder: (context, h, width) => _PreviewCard(
              width: width,
              accent: HomeStyle.green,
              title: h['name'] as String,
              subtitle: h['event_date'] != null
                  ? DateFormat.yMMMd()
                      .format(DateTime.parse(h['event_date'] as String))
                  : '',
              onTap: () =>
                  context.push(RoutePaths.hackathonDetailOf(h['id'] as String)),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _JobsSection extends ConsumerWidget {
  const _JobsSection({required this.hPad, required this.isMobile});

  final double hPad;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad, right: hPad - 8),
            child: _SectionHeader(
                title: 'Jobs', onSeeAll: () => context.push(RoutePaths.jobs)),
          ),
          const SizedBox(height: 6),
          _PreviewCarousel(
            items: ref.watch(homeJobsPreviewProvider),
            emptyLabel: 'No open jobs yet',
            onRetry: () => ref.invalidate(homeJobsPreviewProvider),
            isMobile: isMobile,
            hPad: hPad,
            itemBuilder: (context, j, width) => _PreviewCard(
              width: width,
              accent: HomeStyle.amber,
              title: j['title'] as String,
              subtitle: j['company_name'] as String? ?? '',
              onTap: () =>
                  context.push(RoutePaths.jobDetailOf(j['id'] as String)),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _ProjectsSection extends ConsumerWidget {
  const _ProjectsSection({required this.hPad, required this.isMobile});

  final double hPad;
  final bool isMobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: hPad, right: hPad - 8),
            child: _SectionHeader(
                title: 'Projects',
                onSeeAll: () => context.push(RoutePaths.projects)),
          ),
          const SizedBox(height: 6),
          _PreviewCarousel(
            items: ref.watch(homeProjectsPreviewProvider),
            emptyLabel: 'No open projects yet',
            onRetry: () => ref.invalidate(homeProjectsPreviewProvider),
            isMobile: isMobile,
            hPad: hPad,
            itemBuilder: (context, p, width) => _PreviewCard(
              width: width,
              accent: HomeStyle.violet,
              title: p['title'] as String,
              subtitle: p['category'] as String? ?? '',
              onTap: () =>
                  context.push(RoutePaths.projectDetailOf(p['id'] as String)),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _PostsSection extends ConsumerWidget {
  const _PostsSection({required this.hPad});

  final double hPad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(homePostsPreviewProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(left: hPad, right: hPad - 8),
            child: _SectionHeader(
              title: 'Posts',
              onSeeAll: () => context.push(RoutePaths.posts),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: HomeStyle.textSecondary),
                tooltip: 'Create post',
                onPressed: () => context.push(RoutePaths.newPost),
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 6)),
        postsAsync.when(
          loading: () => SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: const _PostSkeleton(),
            ),
          ),
          error: (_, __) => SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Couldn\'t load posts — retry'),
                  onPressed: () => ref.invalidate(homePostsPreviewProvider),
                ),
              ),
            ),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: const Text(
                    'No posts yet. Share something about tech or your latest project.',
                    style:
                        TextStyle(fontSize: 13, color: HomeStyle.textSecondary),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              sliver: SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => PostCard(post: posts[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PostSkeleton extends StatelessWidget {
  const _PostSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: HomeStyle.cardBase,
      highlightColor: const Color(0xFF1A2038),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              height: 140,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: HomeStyle.cardBase,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
        ],
      ),
    );
  }
}
