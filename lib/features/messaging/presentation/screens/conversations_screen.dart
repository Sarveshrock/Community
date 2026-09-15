import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../providers/message_providers.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(myConversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(myConversationsProvider),
          child: conversationsAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(myConversationsProvider)),
            data: (conversations) {
              if (conversations.isEmpty) {
                return const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'No conversations yet',
                  message: 'Connect with someone to start chatting.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final c = conversations[i];
                  return ListTile(
                    onTap: () =>
                        context.push(RoutePaths.chatOf(c.conversationId)),
                    leading: UserAvatar(
                        avatarUrl: c.otherAvatarUrl, name: c.otherName),
                    title: Text(
                        getDisplayName(ref,
                            profileId: c.otherProfileId, mainName: c.otherName),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      c.lastMessage ?? 'Say hello 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: c.lastMessageAt != null
                        ? Text(
                            timeago.format(c.lastMessageAt!,
                                locale: 'en_short'),
                            style: context.textStyles.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant),
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
