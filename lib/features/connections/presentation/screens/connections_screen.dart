import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../hackathons/presentation/providers/hackathon_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../domain/entities/connection.dart';
import '../providers/connection_providers.dart';

class ConnectionsScreen extends ConsumerStatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  ConsumerState<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends ConsumerState<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 3, vsync: this);

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
                  _Header(onBuddies: () => context.push(RoutePaths.buddies)),
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
                      labelStyle:
                          const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      unselectedLabelStyle:
                          const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Requests'),
                        Tab(text: 'Connected'),
                        Tab(text: 'Team invites'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        _RequestsTab(),
                        _ConnectedTab(),
                        _TeamInvitesTab(),
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
  const _Header({required this.onBuddies});

  final VoidCallback onBuddies;

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
            child: Text('Connections',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.favorite_border,
              tooltip: 'Buddies',
              highlighted: true,
              onTap: onBuddies),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap,
      this.highlighted = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: highlighted
              ? HomeStyle.purple.withValues(alpha: 0.16)
              : HomeStyle.cardBase,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
            side: BorderSide(
                color: highlighted
                    ? HomeStyle.purple.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon,
                  size: 21,
                  color: highlighted ? HomeStyle.purple : HomeStyle.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamInvitesTab extends ConsumerWidget {
  const _TeamInvitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitationsAsync = ref.watch(myTeamInvitationsProvider);
    final isLoading = ref.watch(hackathonControllerProvider).isLoading;

    return RefreshIndicator(
      backgroundColor: HomeStyle.cardBase,
      color: HomeStyle.purple,
      onRefresh: () async => ref.invalidate(myTeamInvitationsProvider),
      child: invitationsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(myTeamInvitationsProvider)),
        data: (invitations) {
          if (invitations.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_2_outlined,
              title: 'No team invitations',
              message:
                  'Invitations to join a hackathon team will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: invitations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final invite = invitations[i];
              final team = invite['hackathon_team_requirements']
                  as Map<String, dynamic>?;
              final hackathonId = team?['hackathon_id'] as String?;
              return _Tile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: HomeStyle.brandGradient,
                  ),
                  child: const Icon(Icons.groups_2_outlined,
                      color: Colors.white, size: 19),
                ),
                title: team?['team_name'] as String? ?? 'Hackathon team',
                subtitle: invite['message'] as String? ??
                    'Invited you to join their team',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.check_circle, color: HomeStyle.green),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final ok = await ref
                                  .read(hackathonControllerProvider.notifier)
                                  .respondToInvitation(
                                    invite['id'] as String,
                                    accept: true,
                                    hackathonId: hackathonId,
                                  );
                              if (context.mounted) {
                                context.showSnack(
                                    ok
                                        ? 'You joined the team'
                                        : 'Could not accept invitation',
                                    isError: !ok);
                              }
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: HomeStyle.pink),
                      onPressed: isLoading
                          ? null
                          : () async {
                              final ok = await ref
                                  .read(hackathonControllerProvider.notifier)
                                  .respondToInvitation(
                                    invite['id'] as String,
                                    accept: false,
                                    hackathonId: hackathonId,
                                  );
                              if (context.mounted && !ok) {
                                context.showSnack(
                                    'Could not decline invitation',
                                    isError: true);
                              }
                            },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final requestsAsync =
        ref.watch(myConnectionsProvider(ConnectionStatus.pending));

    return requestsAsync.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myConnectionsProvider)),
      data: (requests) {
        final incoming =
            requests.where((c) => myId != null && c.isIncoming(myId)).toList();
        final outgoing =
            requests.where((c) => myId != null && !c.isIncoming(myId)).toList();

        if (requests.isEmpty) {
          return const EmptyState(
            icon: Icons.person_add_alt_1_outlined,
            title: 'No pending requests',
            message:
                'Connection requests you send or receive will show up here.',
          );
        }

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
                _ConnectionTile(connection: c, myId: myId!, incoming: true),
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
                _ConnectionTile(connection: c, myId: myId!, incoming: false),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _ConnectedTab extends ConsumerWidget {
  const _ConnectedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authStateProvider).valueOrNull?.id;
    final connectedAsync =
        ref.watch(myConnectionsProvider(ConnectionStatus.accepted));

    return connectedAsync.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(myConnectionsProvider)),
      data: (connections) {
        if (connections.isEmpty) {
          return const EmptyState(
            icon: Icons.group_outlined,
            title: 'No connections yet',
            message: 'People you connect with will show up here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: connections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _ConnectionTile(
              connection: connections[i], myId: myId!, incoming: false),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

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
              leading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: HomeStyle.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: HomeStyle.textSecondary)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionTile extends ConsumerWidget {
  const _ConnectionTile(
      {required this.connection, required this.myId, required this.incoming});

  final Connection connection;
  final String myId;
  final bool incoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(connectionControllerProvider).isLoading;
    final otherId = connection.otherProfileId(myId);

    return _Tile(
      onTap: () => context.push(RoutePaths.personDetailOf(otherId)),
      leading: UserAvatar(
          avatarUrl: connection.otherProfileAvatar,
          name: connection.otherProfileName ?? '?'),
      title: connection.displayName(),
      subtitle: connection.otherProfileHeadline ?? connection.status.name,
      trailing: connection.status == ConnectionStatus.pending
          ? (incoming
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.check_circle, color: HomeStyle.green),
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(connectionControllerProvider.notifier)
                              .respond(connection.id, accept: true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: HomeStyle.pink),
                      onPressed: isLoading
                          ? null
                          : () => ref
                              .read(connectionControllerProvider.notifier)
                              .respond(connection.id, accept: false),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(connectionControllerProvider.notifier)
                          .cancel(connection.id),
                  style: TextButton.styleFrom(
                      foregroundColor: HomeStyle.textSecondary),
                  child: const Text('Cancel'),
                ))
          : const Icon(Icons.chevron_right_rounded,
              color: HomeStyle.textSecondary),
    );
  }
}
