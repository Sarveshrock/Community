import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
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
                      indicatorColor: AppColors.localAccent,
                      indicatorWeight: 3,
                      labelColor: AppColors.localAccent,
                      unselectedLabelColor: HomeStyle.textSecondary,
                      labelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w500),
                      tabs: const [Tab(text: 'Requests'), Tab(text: 'Connected')],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        _LocalRequestsTab(),
                        _LocalConnectedTab(),
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
            child: Text('My Local Connections',
                style: TextStyle(
                    fontSize: 18,
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (incoming.isNotEmpty) ...[
              const Text('Incoming',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.textPrimary)),
              const SizedBox(height: 10),
              for (final c in incoming) ...[
                _LocalConnectionTile(connection: c, myId: myId, incoming: true),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 12),
            ],
            if (outgoing.isNotEmpty) ...[
              const Text('Sent',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: HomeStyle.textPrimary)),
              const SizedBox(height: 10),
              for (final c in outgoing) ...[
                _LocalConnectionTile(
                    connection: c, myId: myId, incoming: false),
                const SizedBox(height: 10),
              ],
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
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: connections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
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

    return Material(
      color: HomeStyle.cardBase,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.localProfileDetailOf(otherId)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              UserAvatar(
                  avatarUrl: connection.otherAvatarUrl,
                  name: connection.otherName ?? '?'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connection.otherName ?? 'Someone nearby',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.textPrimary)),
                    const SizedBox(height: 2),
                    Text(connection.status.name,
                        style: const TextStyle(
                            fontSize: 12.5, color: HomeStyle.textSecondary)),
                  ],
                ),
              ),
              connection.status == LocalConnectionStatus.pending && incoming
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle,
                              color: HomeStyle.green),
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(localControllerProvider.notifier)
                                  .respondToRequest(connection.id, accept: true),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: HomeStyle.pink),
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(localControllerProvider.notifier)
                                  .respondToRequest(connection.id, accept: false),
                        ),
                      ],
                    )
                  : const Icon(Icons.chevron_right_rounded,
                      color: HomeStyle.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
