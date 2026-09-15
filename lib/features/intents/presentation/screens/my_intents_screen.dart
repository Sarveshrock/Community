import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/intent_providers.dart';
import '../widgets/intent_card.dart';

/// Active / Fulfilled / Expired are pure client-side filters derived from
/// [UserIntent.isExpired]/[UserIntent.isFulfilled] — mirrors how the RLS
/// policy in 0036_intents.sql derives the same thing, so there's no separate
/// status-sync job to keep correct. Fulfilled intents are never deleted (see
/// [IntentController.markFulfilled]) — they just move to their own tab, so
/// the user's history is preserved per spec.
class MyIntentsScreen extends StatelessWidget {
  const MyIntentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: HomeStyle.background,
        appBar: AppBar(
          backgroundColor: HomeStyle.background,
          title: const Text('My Intents', style: TextStyle(color: HomeStyle.textPrimary)),
          bottom: const TabBar(
            labelColor: HomeStyle.textPrimary,
            unselectedLabelColor: HomeStyle.textSecondary,
            indicatorColor: HomeStyle.purple,
            tabs: [Tab(text: 'Active'), Tab(text: 'Fulfilled'), Tab(text: 'Expired')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push(RoutePaths.newIntent),
          icon: const Icon(Icons.add),
          label: const Text('New intent'),
        ),
        body: const ResponsiveCenter(
          child: TabBarView(children: [
            _IntentList(filter: _Filter.active),
            _IntentList(filter: _Filter.fulfilled),
            _IntentList(filter: _Filter.expired),
          ]),
        ),
      ),
    );
  }
}

enum _Filter { active, fulfilled, expired }

class _IntentList extends ConsumerWidget {
  const _IntentList({required this.filter});

  final _Filter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intentsAsync = ref.watch(myIntentsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(myIntentsProvider),
      child: intentsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) =>
            ErrorState(message: e.toString(), onRetry: () => ref.invalidate(myIntentsProvider)),
        data: (all) {
          final intents = all.where((i) {
            if (i.status == IntentStatus.cancelled) return false;
            return switch (filter) {
              _Filter.fulfilled => i.isFulfilled,
              _Filter.expired => i.isExpired && !i.isFulfilled,
              _Filter.active => !i.isExpired && !i.isFulfilled,
            };
          }).toList();
          if (intents.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              title: switch (filter) {
                _Filter.fulfilled => 'No fulfilled intents yet',
                _Filter.expired => 'No expired intents',
                _Filter.active => 'No active intents yet',
              },
              message: filter == _Filter.active ? 'Declare what you want to accomplish.' : null,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: intents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _MyIntentCard(intent: intents[i]),
          );
        },
      ),
    );
  }
}

class _MyIntentCard extends ConsumerWidget {
  const _MyIntentCard({required this.intent});

  final UserIntent intent;

  Future<void> _renew(BuildContext context, WidgetRef ref, int days) async {
    final ok = await ref
        .read(intentControllerProvider.notifier)
        .renew(intent.id, DateTime.now().add(Duration(days: days)));
    if (context.mounted) {
      context.showSnack(ok ? 'Renewed for $days days' : 'Could not renew', isError: !ok);
    }
  }

  Future<void> _markFulfilled(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Mark as fulfilled?',
      message: 'This intent will move to your Fulfilled history and stop appearing in discovery.',
      confirmLabel: 'Mark fulfilled',
    );
    if (!confirmed) return;
    final ok = await ref.read(intentControllerProvider.notifier).markFulfilled(intent.id);
    if (context.mounted) {
      context.showSnack(ok ? 'Marked as fulfilled 🎉' : 'Could not update', isError: !ok);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(intentControllerProvider.notifier);
    final isLoading = ref.watch(intentControllerProvider).isLoading;
    final canManage = !intent.isFulfilled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntentCard(intent: intent, onTap: () => context.push(RoutePaths.intentDetailOf(intent.id))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push(RoutePaths.intentMatchesOf(intent.id)),
              icon: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: const Text('Matches'),
            ),
            if (canManage)
              OutlinedButton.icon(
                onPressed: () => context.push(RoutePaths.editIntentOf(intent.id)),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit'),
              ),
            if (canManage && !intent.isExpired && intent.status == IntentStatus.active)
              OutlinedButton(
                onPressed: isLoading ? null : () => controller.setStatus(intent.id, 'paused'),
                child: const Text('Pause'),
              ),
            if (canManage && !intent.isExpired && intent.status == IntentStatus.paused)
              OutlinedButton(
                onPressed: isLoading ? null : () => controller.setStatus(intent.id, 'active'),
                child: const Text('Resume'),
              ),
            if (canManage)
              PopupMenuButton<int>(
                tooltip: 'Renew',
                onSelected: (days) => _renew(context, ref, days),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 7, child: Text('Renew 7 days')),
                  PopupMenuItem(value: 14, child: Text('Renew 14 days')),
                  PopupMenuItem(value: 30, child: Text('Renew 30 days')),
                ],
                child: const OutlinedButton(onPressed: null, child: Text('Renew')),
              ),
            if (canManage)
              OutlinedButton.icon(
                onPressed: isLoading ? null : () => _markFulfilled(context, ref),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark fulfilled'),
              ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Delete intent?',
                        message: 'This cannot be undone.',
                        confirmLabel: 'Delete',
                      );
                      if (confirmed) await controller.deleteIntent(intent.id);
                    },
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }
}
