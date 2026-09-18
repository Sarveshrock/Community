import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/connection.dart';
import '../providers/connection_providers.dart';

/// Every profile the caller has blocked, each with an Unblock action —
/// previously the only fix for an accidental block was a raw SQL delete,
/// since `unblockUser` existed in the repository but nothing in the app
/// ever called it and there was no UI path to it at all.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  Future<void> _unblock(
      BuildContext context, WidgetRef ref, BlockedUser user) async {
    final ok = await ref
        .read(connectionControllerProvider.notifier)
        .unblockUser(user.profileId);
    if (!context.mounted) return;
    context.showSnack(
      ok ? '${user.displayName} unblocked' : 'Could not unblock',
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedAsync = ref.watch(blockedUsersProvider);
    final isLoading = ref.watch(connectionControllerProvider).isLoading;

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
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(blockedUsersProvider),
                      child: blockedAsync.when(
                        loading: () => const LoadingState(),
                        error: (e, _) => ErrorState(
                          message: e.toString(),
                          onRetry: () => ref.invalidate(blockedUsersProvider),
                        ),
                        data: (users) {
                          if (users.isEmpty) {
                            return const EmptyState(
                              icon: Icons.block_outlined,
                              title: 'No blocked users',
                              message:
                                  "People you've blocked will show up here.",
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: users.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final user = users[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: HomeStyle.cardBase,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.06)),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    UserAvatar(
                                        avatarUrl: user.avatarUrl,
                                        name: user.displayName),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(user.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      HomeStyle.textPrimary)),
                                          if (user.headline != null) ...[
                                            const SizedBox(height: 2),
                                            Text(user.headline!,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: HomeStyle
                                                        .textSecondary)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () => _unblock(context, ref, user),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: HomeStyle.textPrimary,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.16)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Unblock'),
                                    ),
                                  ],
                                ),
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
            child: Text('Blocked users',
                style: TextStyle(
                    fontSize: 20,
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
