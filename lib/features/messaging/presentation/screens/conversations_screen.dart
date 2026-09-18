import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/message_providers.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(myConversationsProvider);

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
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Messages',
                            style: TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              color: HomeStyle.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(myConversationsProvider),
                      child: conversationsAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(myConversationsProvider)),
                        data: (conversations) {
                          if (conversations.isEmpty) {
                            return const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'No conversations yet',
                              message: 'Connect with someone to start chatting.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: conversations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final c = conversations[i];
                              return _ConversationTile(
                                name: getDisplayName(ref,
                                    profileId: c.otherProfileId,
                                    mainName: c.otherName),
                                avatarUrl: c.otherAvatarUrl,
                                fallbackName: c.otherName,
                                lastMessage: c.lastMessage,
                                lastMessageAt: c.lastMessageAt,
                                onTap: () => context
                                    .push(RoutePaths.chatOf(c.conversationId)),
                              );
                            },
                          );
                        },
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.name,
    required this.avatarUrl,
    required this.fallbackName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final String fallbackName;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeStyle.cardBase,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              UserAvatar(avatarUrl: avatarUrl, name: fallbackName, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: HomeStyle.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastMessage ?? 'Say hello 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: HomeStyle.textSecondary),
                    ),
                  ],
                ),
              ),
              if (lastMessageAt != null) ...[
                const SizedBox(width: 8),
                Text(
                  timeago.format(lastMessageAt!, locale: 'en_short'),
                  style: const TextStyle(
                      fontSize: 11, color: HomeStyle.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
