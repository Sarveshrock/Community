import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../widgets/home_style.dart';

class _CreateOption {
  const _CreateOption(
      this.label, this.description, this.icon, this.path, this.accent);
  final String label;
  final String description;
  final IconData icon;
  final String path;
  final Color accent;
}

/// Create menu (spec section 60). Local connections are intentionally
/// excluded here — they start from Local discovery, not generic creation.
class CreateMenuScreen extends StatelessWidget {
  const CreateMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      const _CreateOption(
          'Intent',
          'Declare what you\'re looking to accomplish right now',
          Icons.flag_outlined,
          RoutePaths.newIntent,
          HomeStyle.purple),
      const _CreateOption(
          'Post',
          'Share something about tech, code, or what you\'re building',
          Icons.forum_outlined,
          RoutePaths.newPost,
          HomeStyle.blue),
      const _CreateOption(
          'Find a Team',
          'Post a hackathon you\'re registering for and find teammates',
          Icons.bolt_outlined,
          RoutePaths.newTeamRequirementStandalone,
          HomeStyle.green),
      const _CreateOption(
          'Project',
          'Find collaborators for something you\'re building',
          Icons.handyman_outlined,
          RoutePaths.newProject,
          HomeStyle.violet),
      const _CreateOption('Job', 'Post a job or internship opening',
          Icons.work_outline, RoutePaths.newJob, HomeStyle.amber),
      const _CreateOption(
          'Referral Offer',
          'Let others request a referral from you at your company',
          Icons.badge_outlined,
          RoutePaths.newReferralOffer,
          HomeStyle.pink),
      const _CreateOption('Startup', 'Share your startup and open roles',
          Icons.rocket_launch_outlined, RoutePaths.newStartup, HomeStyle.cyan),
      const _CreateOption(
          'Community',
          'Start a community around a shared interest',
          Icons.groups_outlined,
          RoutePaths.newCommunity,
          HomeStyle.purple),
      const _CreateOption('Event', 'Organize a workshop, talk, or meetup',
          Icons.event_outlined, RoutePaths.newEvent, HomeStyle.blue),
    ];

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: HomeStyle.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'What do you want to put out there?',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: HomeStyle.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final o = options[index];
                        return GradientBorderCard(
                          radius: 18,
                          gradient: LinearGradient(
                            colors: [
                              o.accent.withValues(alpha: 0.3),
                              o.accent.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => context.push(o.path),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [
                                      o.accent,
                                      o.accent.withValues(alpha: 0.4)
                                    ]),
                                    boxShadow: HomeStyle.glow(o.accent,
                                        opacity: 0.3, blur: 10),
                                  ),
                                  child: Icon(o.icon,
                                      color: Colors.white, size: 21),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(o.label,
                                          style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w700,
                                              color: HomeStyle.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(o.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.3,
                                              color: HomeStyle.textSecondary)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const HomeCardArrow(),
                              ],
                            ),
                          ),
                        );
                      },
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
