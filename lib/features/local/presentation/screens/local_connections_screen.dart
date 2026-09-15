import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/local_entities.dart';
import '../providers/local_providers.dart';

/// Browse existing Local connections (spec sections 33-35). Without this,
/// a person you already connected with on Local becomes unreachable once
/// get_local_candidates() stops surfacing them as a new discovery result.
class LocalConnectionsScreen extends ConsumerStatefulWidget {
  const LocalConnectionsScreen({super.key});

  @override
  ConsumerState<LocalConnectionsScreen> createState() =>
      _LocalConnectionsScreenState();
}

class _LocalConnectionsScreenState extends ConsumerState<LocalConnectionsScreen>
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
      appBar: AppBar(
        title: const Text('My Local Connections'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.localAccent,
          labelColor: AppColors.localAccent,
          tabs: const [Tab(text: 'Requests'), Tab(text: 'Connected')],
        ),
      ),
      body: ResponsiveCenter(
        child: TabBarView(
          controller: _tabController,
          children: const [
            _LocalRequestsTab(),
            _LocalConnectedTab(),
          ],
        ),
      ),
    );
  }
}

class _LocalRequestsTab extends ConsumerWidget {
  const _LocalRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final requestsAsync =
        ref.watch(myLocalConnectionsProvider(LocalConnectionStatus.pending));

    return requestsAsync.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myLocalConnectionsProvider)),
      data: (requests) {
        if (requests.isEmpty || myId == null) {
          return const EmptyState(
            icon: Icons.favorite_border,
            title: 'No pending local requests',
          );
        }
        final incoming = requests.where((c) => c.receiverId == myId).toList();
        final outgoing = requests.where((c) => c.receiverId != myId).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (incoming.isNotEmpty) ...[
              Text('Incoming',
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final c in incoming)
                _LocalConnectionTile(connection: c, myId: myId, incoming: true),
              const SizedBox(height: 20),
            ],
            if (outgoing.isNotEmpty) ...[
              Text('Sent',
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final c in outgoing)
                _LocalConnectionTile(
                    connection: c, myId: myId, incoming: false),
            ],
          ],
        );
      },
    );
  }
}

class _LocalConnectedTab extends ConsumerWidget {
  const _LocalConnectedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final connectedAsync =
        ref.watch(myLocalConnectionsProvider(LocalConnectionStatus.accepted));

    return connectedAsync.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myLocalConnectionsProvider)),
      data: (connections) {
        if (connections.isEmpty || myId == null) {
          return const EmptyState(
              icon: Icons.groups_outlined, title: 'No local connections yet');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _LocalConnectionTile(
              connection: connections[i], myId: myId, incoming: false),
        );
      },
    );
  }
}

class _LocalConnectionTile extends ConsumerWidget {
  const _LocalConnectionTile(
      {required this.connection, required this.myId, required this.incoming});

  final LocalConnection connection;
  final String myId;
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(localControllerProvider).isLoading;
    final otherId = connection.otherProfileId(myId);

    return Card(
      child: ListTile(
        onTap: () => context.push(RoutePaths.localProfileDetailOf(otherId)),
        leading: UserAvatar(
            avatarUrl: connection.otherAvatarUrl,
            name: connection.otherName ?? '?'),
        title: Text(connection.otherName ?? 'Someone nearby',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(connection.status.name),
        trailing: connection.status == LocalConnectionStatus.pending && incoming
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(localControllerProvider.notifier)
                            .respondToRequest(connection.id, accept: true),
                  ),
                  IconButton(
                    icon: Icon(Icons.cancel, color: context.colors.error),
                    onPressed: isLoading
                        ? null
                        : () => ref
                            .read(localControllerProvider.notifier)
                            .respondToRequest(connection.id, accept: false),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
