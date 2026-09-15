import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../../domain/entities/local_entities.dart';
import '../providers/local_providers.dart';

/// Local candidate detail (spec section 63). Only ever shows what the
/// privacy-safe `get_local_candidates()` function already exposed — no
/// direct query for another user's exact profile ever happens here.
class LocalProfileDetailScreen extends ConsumerWidget {
  const LocalProfileDetailScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(localCandidatesProvider).valueOrNull ??
        const <LocalCandidate>[];
    final connectionAsync = ref.watch(localConnectionWithProvider(profileId));
    final isLoading = ref.watch(localControllerProvider).isLoading;

    LocalCandidate? candidate;
    for (final c in candidates) {
      if (c.profileId == profileId) {
        candidate = c;
        break;
      }
    }

    final connection = connectionAsync.valueOrNull;
    final displayName =
        candidate?.displayName ?? connection?.otherName ?? 'Someone nearby';
    final avatarUrl = candidate?.avatarUrl ?? connection?.otherAvatarUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Local Profile')),
      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: UserAvatar(
                      avatarUrl: avatarUrl, name: displayName, radius: 48)),
              const SizedBox(height: 12),
              Center(
                  child: Text(displayName,
                      style: context.textStyles.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800))),
              if (candidate != null) ...[
                const SizedBox(height: 4),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me,
                          size: 14, color: AppColors.localAccent),
                      const SizedBox(width: 4),
                      Text(candidate.distanceBucket,
                          style: const TextStyle(
                              color: AppColors.localAccent,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (candidate?.bio != null && candidate!.bio!.isNotEmpty) ...[
                Text('About',
                    style: context.textStyles.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(candidate.bio!),
                const SizedBox(height: 24),
              ],
              connectionAsync.when(
                loading: () => const LoadingState(),
                error: (_, __) => const SizedBox.shrink(),
                data: (connection) {
                  if (connection == null) {
                    return SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.localAccent),
                        icon: const Icon(Icons.favorite_border),
                        label: const Text('Send local connection request'),
                        onPressed: isLoading
                            ? null
                            : () => ref
                                .read(localControllerProvider.notifier)
                                .sendRequest(profileId),
                      ),
                    );
                  }
                  switch (connection.status) {
                    case LocalConnectionStatus.pending:
                      return const OutlinedButton(
                          onPressed: null, child: Text('Request pending'));
                    case LocalConnectionStatus.accepted:
                      return Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.localAccent),
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text('Chat'),
                              onPressed: () => openDirectConversation(
                                  context, ref, profileId),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.event_available_outlined),
                              label: const Text('Suggest a meetup'),
                              onPressed: () => context
                                  .push(RoutePaths.meetupOf(connection.id)),
                            ),
                          ),
                        ],
                      );
                    default:
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.localAccent),
                          icon: const Icon(Icons.favorite_border),
                          label: const Text('Send local connection request'),
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(localControllerProvider.notifier)
                                  .sendRequest(profileId),
                        ),
                      );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
