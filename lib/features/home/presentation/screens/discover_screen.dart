import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../widgets/home_style.dart';

class _DiscoverCategory {
  const _DiscoverCategory({
    required this.label,
    required this.description,
    required this.cta,
    required this.icon,
    required this.accent,
    required this.path,
  });

  final String label;
  final String description;
  final String cta;
  final IconData icon;
  final Color accent;
  final String path;
}

/// Exact hex values from the redesign brief — kept local to this screen
/// rather than folded into [HomeStyle] since they're a specifically-chosen
/// per-category accent palette, not the app's general brand accents.
class _DiscoverAccent {
  _DiscoverAccent._();
  static const pink = Color(0xFFEC4899);
  static const purple = Color(0xFF8B5CF6);
  static const brightPurple = Color(0xFFA855F7);
  static const blue = Color(0xFF3B82F6);
  static const cyan = Color(0xFF06B6D4);
  static const green = Color(0xFF10B981);
  static const orange = Color(0xFFF97316);
  static const yellow = Color(0xFFFACC15);
}

/// Discover hub (spec section 58 & 61): the single place every opportunity
/// category fans out from, instead of one flat chronological feed.
///
/// The 10 categories in the redesign brief's reference image are a subset —
/// this app has 14 live discovery routes. All 14 are kept (nothing here may
/// remove existing functionality); the 4 not pictured in the reference
/// (Referrals, Mock Interviews, Local, Communities) get the same card
/// treatment and a copy/accent chosen to fit the same palette.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  static const _categories = [
    _DiscoverCategory(
      label: 'Intents',
      description: 'Find people with similar goals',
      cta: 'Set your intent',
      icon: Icons.flag_outlined,
      accent: _DiscoverAccent.pink,
      path: RoutePaths.intents,
    ),
    _DiscoverCategory(
      label: 'Posts',
      description: 'Explore what\'s happening',
      cta: 'See latest posts',
      icon: Icons.chat_bubble_outline_rounded,
      accent: _DiscoverAccent.purple,
      path: RoutePaths.posts,
    ),
    _DiscoverCategory(
      label: 'People',
      description: 'Meet like-minded individuals',
      cta: 'Find your people',
      icon: Icons.people_alt_outlined,
      accent: _DiscoverAccent.blue,
      path: RoutePaths.people,
    ),
    _DiscoverCategory(
      label: 'Jobs',
      description: 'Discover career opportunities',
      cta: 'Explore jobs',
      icon: Icons.work_outline_rounded,
      accent: _DiscoverAccent.cyan,
      path: RoutePaths.jobs,
    ),
    _DiscoverCategory(
      label: 'Hackathons',
      description: 'Join or create hackathons',
      cta: 'Find hackathons',
      icon: Icons.bolt_outlined,
      accent: _DiscoverAccent.brightPurple,
      path: RoutePaths.hackathons,
    ),
    _DiscoverCategory(
      label: 'Projects',
      description: 'Discover or collaborate on projects',
      cta: 'Explore projects',
      icon: Icons.handyman_outlined,
      accent: _DiscoverAccent.green,
      path: RoutePaths.projects,
    ),
    _DiscoverCategory(
      label: 'Startups',
      description: 'Find and join amazing startups',
      cta: 'Explore startups',
      icon: Icons.rocket_launch_outlined,
      accent: _DiscoverAccent.orange,
      path: RoutePaths.startups,
    ),
    _DiscoverCategory(
      label: 'Mentors',
      description: 'Learn from experienced mentors',
      cta: 'Find mentors',
      icon: Icons.school_outlined,
      accent: _DiscoverAccent.green,
      path: RoutePaths.mentors,
    ),
    _DiscoverCategory(
      label: 'Referrals',
      description: 'Get referred by people who work there',
      cta: 'Explore referrals',
      icon: Icons.badge_outlined,
      accent: _DiscoverAccent.blue,
      path: RoutePaths.referrals,
    ),
    _DiscoverCategory(
      label: 'Mock Interviews',
      description: 'Practice with a peer interviewer',
      cta: 'Find a partner',
      icon: Icons.record_voice_over_outlined,
      accent: _DiscoverAccent.brightPurple,
      path: RoutePaths.interviewPractice,
    ),
    _DiscoverCategory(
      label: 'Local',
      description: 'Meet someone nearby, casually',
      cta: 'Discover nearby',
      icon: Icons.near_me_outlined,
      accent: _DiscoverAccent.pink,
      path: RoutePaths.local,
    ),
    _DiscoverCategory(
      label: 'Communities',
      description: 'Join communities that match your interests',
      cta: 'See communities',
      icon: Icons.groups_outlined,
      accent: _DiscoverAccent.orange,
      path: RoutePaths.communities,
    ),
    _DiscoverCategory(
      label: 'Events',
      description: 'Discover upcoming events',
      cta: 'View events',
      icon: Icons.event_outlined,
      accent: _DiscoverAccent.cyan,
      path: RoutePaths.events,
    ),
    _DiscoverCategory(
      label: 'News',
      description: 'Stay updated with latest news',
      cta: 'Read news',
      icon: Icons.newspaper_outlined,
      accent: _DiscoverAccent.yellow,
      path: RoutePaths.news,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hPad = width < 360 ? 16.0 : 20.0;
    // The reference's own phone-width mockup shows 2 columns comfortably —
    // matching that (and the app's pre-existing mobile behavior) rather than
    // the brief's separate "mobile: 1 column" note. Only genuinely narrow
    // widths, where 2 columns would actually start clipping card content,
    // fall back to 1 — an overflow safety net, not the normal case.
    final columns = width < 340 ? 1 : 2;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            bottom: false,
            child: ResponsiveCenter(
              maxWidth: 720,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 4),
                    sliver: const SliverToBoxAdapter(child: _Header()),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        // A fixed pixel height rather than an aspect ratio:
                        // the card's content height (icon row + title + up
                        // to 2 description lines + CTA) doesn't meaningfully
                        // change with card width, so tying height to width
                        // via a ratio either wastes space or — as measured
                        // directly at 1 and 2 columns during testing —
                        // overflows once the ratio makes the card too flat.
                        mainAxisExtent: 198,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _CategoryCard(category: _categories[i]),
                        childCount: _categories.length,
                      ),
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
  const _Header();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GradientText(
                'Discover',
                gradient: const LinearGradient(
                  colors: [
                    HomeStyle.textPrimary,
                    HomeStyle.blue,
                    HomeStyle.purple,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                style: TextStyle(
                  fontSize: width < 360 ? 30 : 34,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Explore opportunities, people, projects and more.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  color: HomeStyle.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _SearchButton(),
      ],
    );
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: HomeStyle.brandGradient,
        boxShadow: HomeStyle.glow(HomeStyle.purple, opacity: 0.35, blur: 14),
      ),
      padding: const EdgeInsets.all(1.4),
      child: Material(
        color: HomeStyle.background,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(RoutePaths.search),
          child: const Center(
            child: Icon(Icons.search_rounded,
                size: 22, color: HomeStyle.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.category});

  final _DiscoverCategory category;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  void _setHover(bool value) {
    if (_hovering == value) return;
    setState(() => _hovering = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.category;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedScale(
        scale: _hovering ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: [
                c.accent.withValues(alpha: _hovering ? 0.65 : 0.4),
                c.accent.withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: HomeStyle.glow(c.accent,
                opacity: _hovering ? 0.32 : 0.16, blur: _hovering ? 22 : 14),
          ),
          padding: const EdgeInsets.all(1.2),
          child: Material(
            color: HomeStyle.cardBase,
            borderRadius: BorderRadius.circular(21),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push(c.path),
              child: Stack(
                children: [
                  // Subtle category-related "art": a large, low-opacity
                  // outline of the same icon in the bottom-right corner —
                  // no bitmap assets exist in this project, so this is the
                  // brief's authorized abstract-visual fallback rather than
                  // an added image dependency.
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(c.icon,
                        size: 108, color: c.accent.withValues(alpha: 0.10)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _IconChip(icon: c.icon, accent: c.accent),
                            const Spacer(),
                            _ChevronButton(accent: c.accent),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          c.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: HomeStyle.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                c.cta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.accent,
                                ),
                              ),
                            ),
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 150),
                              padding:
                                  EdgeInsets.only(left: _hovering ? 6 : 3),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: c.accent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: accent.withValues(alpha: 0.16),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: const Icon(Icons.chevron_right_rounded,
          size: 18, color: HomeStyle.textPrimary),
    );
  }
}
