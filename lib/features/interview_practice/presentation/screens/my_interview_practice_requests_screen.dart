import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../messaging/presentation/providers/message_providers.dart';
import '../providers/interview_practice_providers.dart';

/// Tabs mirror the two directions a pairing can start from: requests I sent
/// out and requests other pool members sent to me.
class MyInterviewPracticeRequestsScreen extends StatefulWidget {
  const MyInterviewPracticeRequestsScreen({super.key});

  @override
  State<MyInterviewPracticeRequestsScreen> createState() =>
      _MyInterviewPracticeRequestsScreenState();
}

class _MyInterviewPracticeRequestsScreenState
    extends State<MyInterviewPracticeRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  const _Header(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.label,
                      indicatorColor: HomeStyle.purple,
                      indicatorWeight: 3,
                      labelColor: HomeStyle.purple,
                      unselectedLabelColor: HomeStyle.textSecondary,
                      labelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500),
                      tabs: const [Tab(text: 'Sent'), Tab(text: 'Received')],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        _RequestsList(mode: _Mode.sent),
                        _RequestsList(mode: _Mode.received),
                      ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          _IconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Back',
              onTap: () => context.pop()),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('My Practice Requests',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Mode { sent, received }

class _RequestsList extends ConsumerWidget {
  const _RequestsList({required this.mode});

  final _Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = mode == _Mode.sent
        ? sentInterviewPracticeRequestsProvider
        : receivedInterviewPracticeRequestsProvider;
    final requestsAsync = ref.watch(provider);

    return RefreshIndicator(
      backgroundColor: HomeStyle.cardBase,
      color: HomeStyle.purple,
      onRefresh: () async => ref.invalidate(provider),
      child: requestsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) =>
            ErrorState(message: e.toString(), onRetry: () => ref.invalidate(provider)),
        data: (requests) {
          if (requests.isEmpty) {
            return EmptyState(
              icon: Icons.record_voice_over_outlined,
              title: mode == _Mode.sent
                  ? 'No practice requests sent yet'
                  : 'No practice requests received yet',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) =>
                _RequestCard(request: requests[i], mode: mode),
          );
        },
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({this.icon, required this.label, required this.onTap});

  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: HomeStyle.brandGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: HomeStyle.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ),
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.request, required this.mode});

  final InterviewPracticeRequest request;
  final _Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(interviewPracticeControllerProvider.notifier);
    final isLoading = ref.watch(interviewPracticeControllerProvider).isLoading;
    final otherId = mode == _Mode.sent ? request.partnerId : request.requesterId;
    final otherName = mode == _Mode.sent ? request.partnerName : request.requesterName;
    final otherAvatar =
        mode == _Mode.sent ? request.partnerAvatarUrl : request.requesterAvatarUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(avatarUrl: otherAvatar, name: otherName ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherName ?? 'Community member',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.textPrimary)),
                    const SizedBox(height: 2),
                    Text(request.targetRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: HomeStyle.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HomeChip(request.status.label, accent: HomeStyle.cyan),
            ],
          ),
          if (request.message != null) ...[
            const SizedBox(height: 8),
            Text(request.message!,
                style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: HomeStyle.textPrimary)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (mode == _Mode.received &&
                  request.status == InterviewPracticeStatus.pending) ...[
                _GradientButton(
                  label: 'Accept',
                  onTap: isLoading
                      ? null
                      : () => controller.respondToRequest(request.id, accept: true),
                ),
                _OutlineActionButton(
                  label: 'Decline',
                  onTap: isLoading
                      ? null
                      : () => controller.respondToRequest(request.id, accept: false),
                ),
              ],
              if (request.status == InterviewPracticeStatus.accepted) ...[
                _GradientButton(
                  icon: Icons.chat_bubble_outline,
                  label: 'Open chat',
                  onTap: () async {
                    final conversationId =
                        await ref.read(directConversationIdProvider(otherId).future);
                    if (context.mounted) {
                      context.push(RoutePaths.chatOf(conversationId));
                    }
                  },
                ),
                _OutlineActionButton(
                  label: 'Mark completed',
                  onTap:
                      isLoading ? null : () => controller.markCompleted(request.id),
                ),
              ],
              if ({InterviewPracticeStatus.pending, InterviewPracticeStatus.accepted}
                  .contains(request.status))
                TextButton(
                  onPressed: isLoading ? null : () => controller.cancelRequest(request.id),
                  style: TextButton.styleFrom(
                      foregroundColor: HomeStyle.textSecondary),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
