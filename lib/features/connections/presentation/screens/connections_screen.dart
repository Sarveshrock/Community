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
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            tooltip: 'Buddies',
            onPressed: () => context.push(RoutePaths.buddies),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Connected'),
            Tab(text: 'Team invites')
          ],
        ),
      ),
      body: ResponsiveCenter(
        child: TabBarView(
          controller: _tabController,
          children: const [
            _RequestsTab(),
            _ConnectedTab(),
            _TeamInvitesTab(),
          ],
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
            padding: const EdgeInsets.all(16),
            itemCount: invitations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final invite = invitations[i];
              final team = invite['hackathon_team_requirements']
                  as Map<String, dynamic>?;
              final hackathonId = team?['hackathon_id'] as String?;
              return Card(
                child: ListTile(
                  leading:
                      const CircleAvatar(child: Icon(Icons.groups_2_outlined)),
                  title: Text(team?['team_name'] as String? ?? 'Hackathon team',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(invite['message'] as String? ??
                      'Invited you to join their team'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
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
                        icon: Icon(Icons.cancel, color: context.colors.error),
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
          padding: const EdgeInsets.all(16),
          children: [
            if (incoming.isNotEmpty) ...[
              Text('Incoming',
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final c in incoming)
                _ConnectionTile(connection: c, myId: myId!, incoming: true),
              const SizedBox(height: 20),
            ],
            if (outgoing.isNotEmpty) ...[
              Text('Sent',
                  style: context.textStyles.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final c in outgoing)
                _ConnectionTile(connection: c, myId: myId!, incoming: false),
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
          padding: const EdgeInsets.all(16),
          itemCount: connections.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _ConnectionTile(
              connection: connections[i], myId: myId!, incoming: false),
        );
      },
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

    return Card(
      child: ListTile(
        onTap: () => context.push(RoutePaths.personDetailOf(otherId)),
        leading: UserAvatar(
            avatarUrl: connection.otherProfileAvatar,
            name: connection.otherProfileName ?? '?'),
        title: Text(connection.displayName(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Text(connection.otherProfileHeadline ?? connection.status.name),
        trailing: connection.status == ConnectionStatus.pending
            ? (incoming
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon:
                            const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: isLoading
                            ? null
                            : () => ref
                                .read(connectionControllerProvider.notifier)
                                .respond(connection.id, accept: true),
                      ),
                      IconButton(
                        icon: Icon(Icons.cancel, color: context.colors.error),
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
                    child: const Text('Cancel'),
                  ))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
