import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../connections/domain/entities/connection.dart';
import '../../../connections/presentation/providers/connection_providers.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../../../messaging/presentation/utils/open_direct_conversation.dart';
import '../providers/intent_providers.dart';
import '../widgets/intent_detail_view.dart';

class IntentDetailScreen extends ConsumerWidget {
  const IntentDetailScreen({super.key, required this.intentId});

  final String intentId;

  Future<void> _markFulfilled(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark as fulfilled?',
      message: 'This intent will move to your Fulfilled history and stop appearing in discovery.',
      confirmLabel: 'Mark fulfilled',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(intentControllerProvider.notifier).markFulfilled(intentId);
    if (context.mounted) {
      context.showSnack(ok ? 'Marked as fulfilled 🎉' : 'Could not update', isError: !ok);
      if (ok) context.pop();
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this intent?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    final ok = await ref.read(intentControllerProvider.notifier).deleteIntent(intentId);
    if (!context.mounted) return;
    if (ok) {
      context.pop();
    } else {
      context.showSnack('Could not delete intent', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentAsync = ref.watch(intentDetailProvider(intentId));
    final myId = ref.watch(authStateProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: HomeStyle.background,
      appBar: AppBar(
        backgroundColor: HomeStyle.background,
        title: const Text('Intent', style: TextStyle(color: HomeStyle.textPrimary)),
      ),
      body: intentAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (intent) {
          final isOwner = intent.profileId == myId;
          return IntentDetailView(
            intent: intent,
            actions: isOwner ? null : _ConnectMessageRow(intent: intent),
            ownerControls: isOwner
                ? _OwnerControls(
                    intent: intent,
                    onEdit: () => context.push(RoutePaths.editIntentOf(intentId)),
                    onViewMatches: () => context.push(RoutePaths.intentMatchesOf(intentId)),
                    onMarkFulfilled: () => _markFulfilled(context, ref),
                    onDelete: () => _delete(context, ref),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Reuses the exact same connection-request and direct-conversation
/// infrastructure as every other "Connect"/"Message" affordance in the app
/// (Profile, People, ...) — no parallel messaging/connections system, per
/// spec. The chat opens pre-filled with context ("Connect regarding: Find
/// Collaborator — <title>") so the recipient knows why they were messaged.
class _ConnectMessageRow extends ConsumerWidget {
  const _ConnectMessageRow({required this.intent});

  final UserIntent intent;

  String get _contextLine => 'Hi! Connecting regarding your intent: ${intent.intentType.label} — ${intent.title}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionWithProvider(intent.profileId));
    final isLoading = ref.watch(connectionControllerProvider).isLoading;

    return Row(
      children: [
        Expanded(
          child: connectionAsync.when(
            loading: () => const SizedBox(height: 44),
            error: (_, __) => const SizedBox.shrink(),
            data: (connection) {
              final isConnected = connection?.status == ConnectionStatus.accepted;
              final isPending = connection?.status == ConnectionStatus.pending;
              return OutlinedButton.icon(
                onPressed: isLoading || isConnected || isPending
                    ? null
                    : () => ref.read(connectionControllerProvider.notifier).sendRequest(intent.profileId),
                icon: Icon(isConnected ? Icons.check_circle_outline : Icons.person_add_alt_1_outlined, size: 18),
                label: Text(isConnected ? 'Connected' : (isPending ? 'Pending' : 'Connect')),
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => openDirectConversation(context, ref, intent.profileId, prefillText: _contextLine),
            icon: const Icon(Icons.message_outlined, size: 18),
            label: const Text('Message'),
          ),
        ),
      ],
    );
  }
}

class _OwnerControls extends StatelessWidget {
  const _OwnerControls({
    required this.intent,
    required this.onEdit,
    required this.onViewMatches,
    required this.onMarkFulfilled,
    required this.onDelete,
  });

  final UserIntent intent;
  final VoidCallback onEdit;
  final VoidCallback onViewMatches;
  final VoidCallback onMarkFulfilled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final canManage = !intent.isFulfilled;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onViewMatches,
          icon: const Icon(Icons.auto_awesome_outlined, size: 16),
          label: const Text('View matches'),
        ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        if (canManage)
          OutlinedButton.icon(
            onPressed: onMarkFulfilled,
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Mark fulfilled'),
          ),
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Delete'),
        ),
      ],
    );
  }
}
