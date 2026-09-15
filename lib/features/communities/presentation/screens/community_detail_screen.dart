import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart' show darkInputDecoration;
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../events/presentation/providers/event_providers.dart' show communityEventsProvider;
import '../../../events/presentation/widgets/event_card.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../moderation/presentation/widgets/report_action_button.dart';
import '../providers/community_providers.dart';
import '../widgets/community_detail_view.dart';

/// The Community Detail page: a proper public landing page before joining
/// (about/what-happens-here/topics/rules/public discussions/pre-join Q&A),
/// and a richer member space after joining (members/events/chat/manage
/// controls) — all built on the exact same [Community] row and existing
/// Communeo infrastructure (posts, events, messaging, notifications).
class CommunityDetailScreen extends ConsumerWidget {
  const CommunityDetailScreen({super.key, required this.communityId});

  final String communityId;

  Future<void> _handlePrimaryAction(BuildContext context, WidgetRef ref, CommunityAction action) async {
    final controller = ref.read(communityControllerProvider.notifier);
    if (action == CommunityAction.join) {
      final ok = await controller.join(communityId);
      if (context.mounted) context.showSnack(ok ? 'You joined the community!' : 'Could not join', isError: !ok);
    } else if (action == CommunityAction.requestToJoin) {
      final ok = await controller.requestToJoin(communityId);
      if (context.mounted) context.showSnack(ok ? 'Request sent' : 'Could not send request', isError: !ok);
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Leave community?',
      message: 'You\'ll lose access to member discussions and the community chat.',
      confirmLabel: 'Leave',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(communityControllerProvider.notifier).leave(communityId);
    if (context.mounted) context.showSnack(ok ? 'You left the community' : 'Could not leave', isError: !ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final communityAsync = ref.watch(communityDetailProvider(communityId));
    final isMemberAsync = ref.watch(isCommunityMemberProvider(communityId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final isBusy = ref.watch(communityControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: communityAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString(), onRetry: () => ref.invalidate(communityDetailProvider(communityId))),
        data: (community) {
          final isMember = isMemberAsync.valueOrNull ?? false;
          final isOwner = community.isOwner(myId);
          final pendingRequestAsync = ref.watch(myCommunityJoinRequestProvider(communityId));

          final action = resolveCommunityAction(
            community: community,
            myId: myId,
            isMember: isMember,
            hasPendingRequest: pendingRequestAsync.valueOrNull != null,
          );

          return SafeArea(
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(communityDetailProvider(communityId));
                    ref.invalidate(isCommunityMemberProvider(communityId));
                  },
                  child: ResponsiveCenter(
                    child: CommunityDetailView(
                      community: community,
                      actionState: action,
                      isActionLoading: isBusy,
                      onPrimaryAction: () => _handlePrimaryAction(context, ref, action),
                      trailingSections: [
                        _AnnouncementsSection(communityId: communityId),
                        const SizedBox(height: 20),
                        _DiscussionsSection(communityId: communityId, isMember: isMember),
                        const SizedBox(height: 20),
                        _PreJoinQASection(communityId: communityId, isMember: isMember, myId: myId),
                        if (isMember) ...[
                          const SizedBox(height: 20),
                          _MembersEntryCard(communityId: communityId),
                          const SizedBox(height: 20),
                          _EventsSection(communityId: communityId),
                          const SizedBox(height: 20),
                          _ChatEntryCard(communityId: communityId, communityName: community.name),
                        ],
                      ],
                      organizerControls: isOwner
                          ? _OwnerManageSection(communityId: communityId)
                          : (isMember ? _MemberManageSection(isBusy: isBusy, onLeave: () => _leave(context, ref)) : null),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _RoundIconButton(icon: Icons.arrow_back_rounded, onTap: () => context.pop()),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      if (isOwner)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _RoundIconButton(
                            icon: Icons.edit_outlined,
                            onTap: () => context.push(RoutePaths.editCommunityOf(communityId)),
                          ),
                        ),
                      _RoundIconButton(
                        icon: Icons.flag_outlined,
                        onTap: () {},
                        wrap: ReportActionButton(targetType: ReportTargetType.community, targetId: communityId),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.wrap});

  final IconData icon;
  final VoidCallback onTap;
  final Widget? wrap;

  @override
  Widget build(BuildContext context) {
    if (wrap != null) {
      return Container(
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
        child: IconTheme(data: const IconThemeData(color: Colors.white), child: wrap!),
      );
    }
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, color: Colors.white, size: 20)),
      ),
    );
  }
}

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection({required this.communityId});
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(communityAnnouncementsProvider(communityId));
    final announcements = announcementsAsync.valueOrNull ?? const [];
    if (announcements.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Announcements', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
        const SizedBox(height: 10),
        for (final post in announcements.take(3))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HomeStyle.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HomeStyle.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📢', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(post.content, style: const TextStyle(color: HomeStyle.textPrimary, fontSize: 13, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

class _DiscussionsSection extends ConsumerWidget {
  const _DiscussionsSection({required this.communityId, required this.isMember});
  final String communityId;
  final bool isMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(communityPostsProvider(communityId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Discussions', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
            if (isMember)
              TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: HomeStyle.cardBase,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _NewPostSheet(communityId: communityId),
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: HomeStyle.purple),
                label: const Text('New', style: TextStyle(color: HomeStyle.purple)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        postsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load discussions', style: TextStyle(color: HomeStyle.textSecondary)),
          data: (posts) {
            final regular = posts.where((p) => !p.isAnnouncement).toList();
            if (regular.isEmpty) {
              return const Text('No discussions yet — be the first to start one.',
                  style: TextStyle(color: HomeStyle.textSecondary, fontSize: 13));
            }
            return Column(
              children: [for (final post in regular.take(5)) _DiscussionTile(post: post)],
            );
          },
        ),
      ],
    );
  }
}

class _DiscussionTile extends StatelessWidget {
  const _DiscussionTile({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(avatarUrl: post.authorAvatar, name: post.authorName ?? '?', radius: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(post.authorName ?? 'Community member',
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600, fontSize: 12.5)),
              ),
              Text(timeago.format(post.createdAt, locale: 'en_short'),
                  style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 8),
          Text(post.content, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 13, height: 1.4)),
          const SizedBox(height: 6),
          Text('${post.commentCount} repl${post.commentCount == 1 ? 'y' : 'ies'}',
              style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _PreJoinQASection extends ConsumerWidget {
  const _PreJoinQASection({required this.communityId, required this.isMember, required this.myId});
  final String communityId;
  final bool isMember;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(communityQuestionsProvider(communityId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Have a question before joining?',
                  style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
            ),
            if (myId != null)
              TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: HomeStyle.cardBase,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _AskQuestionSheet(communityId: communityId),
                ),
                icon: const Icon(Icons.add_rounded, size: 16, color: HomeStyle.cyan),
                label: const Text('Ask', style: TextStyle(color: HomeStyle.cyan)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        questionsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Could not load questions', style: TextStyle(color: HomeStyle.textSecondary)),
          data: (questions) {
            if (questions.isEmpty) {
              return const Text('No questions yet.', style: TextStyle(color: HomeStyle.textSecondary, fontSize: 13));
            }
            return Column(
              children: [for (final q in questions) _QuestionTile(question: q, communityId: communityId, canAnswer: isMember)],
            );
          },
        ),
      ],
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question, required this.communityId, required this.canAnswer});
  final CommunityQuestion question;
  final String communityId;
  final bool canAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('❓', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(question.questionText,
                    style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text('Asked by ${question.askerName ?? 'Community member'}',
                style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
          ),
          if (question.answers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in question.answers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12.5, color: HomeStyle.textSecondary, height: 1.4),
                          children: [
                            TextSpan(
                                text: '${a.responderName ?? 'Member'}: ',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
                            TextSpan(text: a.answerText),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (canAnswer) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: HomeStyle.cardBase,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => _AnswerSheet(question: question, communityId: communityId),
                ),
                child: const Text('Answer', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MembersEntryCard extends ConsumerWidget {
  const _MembersEntryCard({required this.communityId});
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(communityMembersProvider(communityId));
    final count = membersAsync.valueOrNull?.length;
    return _EntryCard(
      icon: Icons.groups_2_outlined,
      title: 'Members',
      subtitle: count != null ? '$count member${count == 1 ? '' : 's'}' : 'View community members',
      onTap: () => context.push(RoutePaths.communityMembersOf(communityId)),
    );
  }
}

class _EventsSection extends ConsumerWidget {
  const _EventsSection({required this.communityId});
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(communityEventsProvider(communityId));
    final events = eventsAsync.valueOrNull ?? const [];
    if (events.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upcoming events', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
        const SizedBox(height: 10),
        for (final event in events.take(3))
          Padding(padding: const EdgeInsets.only(bottom: 10), child: EventCard(event: event)),
      ],
    );
  }
}

class _ChatEntryCard extends ConsumerWidget {
  const _ChatEntryCard({required this.communityId, required this.communityName});
  final String communityId;
  final String communityName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EntryCard(
      icon: Icons.forum_outlined,
      title: 'Community chat',
      subtitle: 'Message your fellow members',
      onTap: () => context.push(RoutePaths.communityChatOf(communityId), extra: communityName),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Icon(icon, color: HomeStyle.purple, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(subtitle, style: const TextStyle(color: HomeStyle.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: HomeStyle.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberManageSection extends StatelessWidget {
  const _MemberManageSection({required this.isBusy, required this.onLeave});
  final bool isBusy;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout, size: 16),
        label: const Text('Leave community'),
        onPressed: isBusy ? null : onLeave,
      ),
    );
  }
}

class _OwnerManageSection extends ConsumerWidget {
  const _OwnerManageSection({required this.communityId});
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(communityJoinRequestsProvider(communityId));
    final requests = requestsAsync.valueOrNull ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Manage this community', style: TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.editCommunityOf(communityId)),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit community'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HomeStyle.purple,
                  side: BorderSide(color: HomeStyle.purple.withValues(alpha: 0.5)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.communityMembersOf(communityId)),
                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                label: const Text('Members'),
              ),
            ),
          ],
        ),
        if (requests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('${requests.length} pending join request${requests.length == 1 ? '' : 's'}',
              style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 8),
          for (final r in requests) _JoinRequestTile(request: r, communityId: communityId),
        ],
      ],
    );
  }
}

class _JoinRequestTile extends ConsumerWidget {
  const _JoinRequestTile({required this.request, required this.communityId});
  final CommunityJoinRequest request;
  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          UserAvatar(avatarUrl: request.requesterAvatarUrl, name: request.requesterName ?? '?', radius: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(request.requesterName ?? 'Community member',
                style: const TextStyle(color: HomeStyle.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Color(0xFF22D98A)),
            onPressed: () => ref
                .read(communityControllerProvider.notifier)
                .respondToJoinRequest(request.id, communityId, accept: true),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: Color(0xFFFB7185)),
            onPressed: () => ref
                .read(communityControllerProvider.notifier)
                .respondToJoinRequest(request.id, communityId, accept: false),
          ),
        ],
      ),
    );
  }
}

class _NewPostSheet extends ConsumerStatefulWidget {
  const _NewPostSheet({required this.communityId});
  final String communityId;

  @override
  ConsumerState<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends ConsumerState<_NewPostSheet> {
  final _controller = TextEditingController();
  bool _isAnnouncement = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final success = await ref
        .read(communityControllerProvider.notifier)
        .createPost(widget.communityId, _controller.text.trim(), isAnnouncement: _isAnnouncement);
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New discussion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Share something with the community'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Post as announcement', style: TextStyle(color: HomeStyle.textPrimary, fontSize: 13)),
            subtitle: const Text('Only moderators/admins can post announcements',
                style: TextStyle(color: HomeStyle.textSecondary, fontSize: 11.5)),
            value: _isAnnouncement,
            onChanged: (v) => setState(() => _isAnnouncement = v),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Post'))),
        ],
      ),
    );
  }
}

class _AskQuestionSheet extends ConsumerStatefulWidget {
  const _AskQuestionSheet({required this.communityId});
  final String communityId;

  @override
  ConsumerState<_AskQuestionSheet> createState() => _AskQuestionSheetState();
}

class _AskQuestionSheetState extends ConsumerState<_AskQuestionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final success =
        await ref.read(communityControllerProvider.notifier).askQuestion(widget.communityId, _controller.text.trim());
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ask before joining', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('e.g. Is this community suitable for beginners?'),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Ask'))),
        ],
      ),
    );
  }
}

class _AnswerSheet extends ConsumerStatefulWidget {
  const _AnswerSheet({required this.question, required this.communityId});
  final CommunityQuestion question;
  final String communityId;

  @override
  ConsumerState<_AnswerSheet> createState() => _AnswerSheetState();
}

class _AnswerSheetState extends ConsumerState<_AnswerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    final success = await ref
        .read(communityControllerProvider.notifier)
        .answerQuestion(widget.question.id, widget.communityId, _controller.text.trim());
    if (success && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Answer: ${widget.question.questionText}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: HomeStyle.textPrimary)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 3,
            style: const TextStyle(color: HomeStyle.textPrimary),
            decoration: darkInputDecoration('Your answer'),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Answer'))),
        ],
      ),
    );
  }
}
