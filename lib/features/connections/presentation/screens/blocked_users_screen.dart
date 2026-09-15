import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
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
      appBar: AppBar(title: const Text('Blocked users')),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(blockedUsersProvider),
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
                  message: "People you've blocked will show up here.",
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final user = users[i];
                  return Card(
                    child: ListTile(
                      leading: UserAvatar(
                          avatarUrl: user.avatarUrl, name: user.displayName),
                      title: Text(user.displayName),
                      subtitle:
                          user.headline != null ? Text(user.headline!) : null,
                      trailing: OutlinedButton(
                        onPressed: isLoading
                            ? null
                            : () => _unblock(context, ref, user),
                        child: const Text('Unblock'),
                      ),
                    ),
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
