import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';

class _CreateOption {
  const _CreateOption(this.label, this.description, this.icon, this.path);
  final String label;
  final String description;
  final IconData icon;
  final String path;
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
          RoutePaths.newIntent),
      const _CreateOption(
          'Post',
          'Share something about tech, code, or what you\'re building',
          Icons.forum_outlined,
          RoutePaths.newPost),
      const _CreateOption(
          'Find a Team',
          'Post a hackathon you\'re registering for and find teammates',
          Icons.bolt_outlined,
          RoutePaths.newTeamRequirementStandalone),
      const _CreateOption(
          'Project',
          'Find collaborators for something you\'re building',
          Icons.handyman_outlined,
          RoutePaths.newProject),
      const _CreateOption('Job', 'Post a job or internship opening',
          Icons.work_outline, RoutePaths.newJob),
      const _CreateOption(
          'Referral Offer',
          'Let others request a referral from you at your company',
          Icons.badge_outlined,
          RoutePaths.newReferralOffer),
      const _CreateOption('Startup', 'Share your startup and open roles',
          Icons.rocket_launch_outlined, RoutePaths.newStartup),
      const _CreateOption(
          'Community',
          'Start a community around a shared interest',
          Icons.groups_outlined,
          RoutePaths.newCommunity),
      const _CreateOption('Event', 'Organize a workshop, talk, or meetup',
          Icons.event_outlined, RoutePaths.newEvent),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ResponsiveCenter(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: options.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final o = options[index];
            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: context.colors.primaryContainer,
                  child: Icon(o.icon, color: context.colors.onPrimaryContainer),
                ),
                title: Text(o.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(o.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(o.path),
              ),
            );
          },
        ),
      ),
    );
  }
}
