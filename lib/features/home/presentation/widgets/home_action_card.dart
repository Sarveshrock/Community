import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import 'home_style.dart';

/// One feature entry point. `path` always points at an existing route — this
/// grid is presentation only, it owns no navigation logic of its own.
class HomeAction {
  const HomeAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.chips,
    required this.path,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final List<String> chips;
  final String path;
}

const homeActions = <HomeAction>[
  HomeAction(
    label: 'Buddies',
    description: 'Find like-minded people for anything',
    icon: Icons.favorite_border_rounded,
    accent: HomeStyle.pink,
    chips: ['Friends', 'Study', 'Communities'],
    path: RoutePaths.buddies,
  ),
  HomeAction(
    label: 'Find a Person',
    description: 'Connect with amazing people',
    icon: Icons.person_search_outlined,
    accent: HomeStyle.blue,
    chips: ['Developers', 'Designers', 'Founders'],
    path: RoutePaths.people,
  ),
  HomeAction(
    label: 'Find a Team',
    description: 'Get the right teammates for your goals',
    icon: Icons.groups_2_outlined,
    accent: HomeStyle.green,
    chips: ['Hackathons', 'Projects', 'Startups'],
    path: RoutePaths.hackathons,
  ),
  HomeAction(
    label: 'Find a Project',
    description: 'Discover or collaborate on projects',
    icon: Icons.handyman_outlined,
    accent: HomeStyle.violet,
    chips: ['Open Source', 'Ideas', 'Real World'],
    path: RoutePaths.projects,
  ),
  HomeAction(
    label: 'Find a Job',
    description: 'Explore opportunities that fit you',
    icon: Icons.work_outline_rounded,
    accent: HomeStyle.amber,
    chips: ['Internships', 'Jobs', 'Referrals'],
    path: RoutePaths.jobs,
  ),
  HomeAction(
    label: 'Find a Mentor',
    description: 'Learn from experienced professionals',
    icon: Icons.school_outlined,
    accent: HomeStyle.cyan,
    chips: ['Guidance', 'Career', 'Growth'],
    path: RoutePaths.mentors,
  ),
];

/// The three entry points the reference layout doesn't show as large cards.
/// They stay on Home (existing features must keep working) as a compact
/// secondary row beneath the main grid.
const secondaryActions = <HomeAction>[
  HomeAction(
    label: 'Startup Opportunities',
    description: '',
    icon: Icons.rocket_launch_outlined,
    accent: HomeStyle.amber,
    chips: [],
    path: RoutePaths.startups,
  ),
  HomeAction(
    label: 'Meet Someone Nearby',
    description: '',
    icon: Icons.near_me_outlined,
    accent: HomeStyle.green,
    chips: [],
    path: RoutePaths.local,
  ),
  HomeAction(
    label: 'Read What\'s New',
    description: '',
    icon: Icons.newspaper_outlined,
    accent: HomeStyle.blue,
    chips: [],
    path: RoutePaths.news,
  ),
];

class HomeActionCard extends StatelessWidget {
  const HomeActionCard({super.key, required this.action, required this.compact});

  final HomeAction action;

  /// Narrow phones drop the chip row so the card doesn't grow taller than
  /// the text it wraps.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = action.accent;

    return GradientBorderCard(
      radius: 18,
      borderWidth: 1,
      glowColor: accent,
      gradient: LinearGradient(
        colors: [
          accent.withValues(alpha: 0.55),
          accent.withValues(alpha: 0.12),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      onTap: () => context.push(action.path),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.10),
              HomeStyle.cardBase.withValues(alpha: 0.0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AccentIcon(icon: action.icon, accent: accent),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              action.label,
                              // Wraps rather than ellipsising: "Find a
                              // Project" must stay readable on a 320px
                              // screen, where a single line won't fit.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                height: 1.15,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.textPrimary,
                              ),
                            ),
                          ),
                          const HomeCardArrow(),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: HomeStyle.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!compact && action.chips.isNotEmpty) ...[
              const SizedBox(height: 9),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final chip in action.chips)
                    HomeChip(chip, accent: accent),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccentIcon extends StatelessWidget {
  const _AccentIcon({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.28),
            accent.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.6)),
        boxShadow: HomeStyle.glow(accent, opacity: 0.28, blur: 12),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }
}

/// Compact pill used for the three secondary entry points.
class SecondaryActionChip extends StatelessWidget {
  const SecondaryActionChip({super.key, required this.action});

  final HomeAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.cardBase,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(action.path),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          // Was an unprotected Row: fine at the font metrics this was eyeballed
          // against, but "Startup Opportunities" (the longest label) has no
          // shrink/ellipsis path, so a wider font, a larger accessibility
          // text scale, or a longer future label overflows outright at
          // narrow widths — caught by actually rendering at 320px.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 17, color: action.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD7DEF0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
