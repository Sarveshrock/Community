import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/community_providers.dart';

/// The community's Members section (spec part 10) — owner, moderators,
/// members, with owner-only remove/promote controls (part 11). Reuses the
/// existing member-list pattern already established for hackathon teams.
class CommunityMembersScreen extends ConsumerWidget {
  const CommunityMembersScreen({super.key, required this.communityId});

  final String communityId;

  Future<void> _removeMember(BuildContext context, WidgetRef ref, CommunityMember member) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${member.displayName}?',
      message: 'They\'ll lose access to member discussions and the community chat.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(communityControllerProvider.notifier).removeMember(communityId, member.profileId);
    if (context.mounted) context.showSnack(ok ? 'Member removed' : 'Could not remove member', isError: !ok);
  }

  Future<void> _toggleModerator(BuildContext context, WidgetRef ref, CommunityMember member) async {
    final newRole = member.isModerator ? 'member' : 'moderator';
    final ok = await ref.read(communityControllerProvider.notifier).setMemberRole(communityId, member.profileId, newRole);
    if (context.mounted) {
      context.showSnack(ok ? (member.isModerator ? 'Removed as moderator' : 'Made moderator') : 'Could not update role',
          isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(communityId));
    final communityAsync = ref.watch(communityDetailProvider(communityId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isOwner = communityAsync.valueOrNull?.isOwner(myId) ?? false;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Members', style: TextStyle(color: HomeStyle.textPrimary)),
        iconTheme: const IconThemeData(color: HomeStyle.textPrimary),
      ),
      body: ResponsiveCenter(
        child: membersAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(communityMembersProvider(communityId))),
          data: (members) {
            if (members.isEmpty) {
              return const EmptyState(icon: Icons.groups_2_outlined, title: 'No members yet');
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final member = members[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HomeStyle.cardBase,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push(RoutePaths.personDetailOf(member.profileId)),
                        child: UserAvatar(avatarUrl: member.avatarUrl, name: member.displayName, radius: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(getDisplayName(ref, profileId: member.profileId, mainName: member.fullName),
                                style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                            if (member.headline != null)
                              Text(member.headline!, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      if (member.isOwnerRole)
                        const _RoleBadge('Owner', color: HomeStyle.purple)
                      else if (member.isModerator)
                        const _RoleBadge('Moderator', color: HomeStyle.blue),
                      if (isOwner && !member.isOwnerRole)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: HomeStyle.textSecondary),
                          onSelected: (action) {
                            if (action == 'role') _toggleModerator(context, ref, member);
                            if (action == 'remove') _removeMember(context, ref, member);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'role', child: Text(member.isModerator ? 'Remove as moderator' : 'Make moderator')),
                            const PopupMenuItem(value: 'remove', child: Text('Remove from community')),
                          ],
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.label, {required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
