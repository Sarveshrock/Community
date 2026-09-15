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
import '../providers/referral_providers.dart';

/// The requester's-eye view of the referral pipeline: what's been requested,
/// where each is in the stage sequence, and the action available next
/// (submit a resume once accepted, or cancel while still open).
class MyReferralRequestsScreen extends StatelessWidget {
  const MyReferralRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Referral Requests'),
        ),
        body: const ResponsiveCenter(child: _SentRequestsList()),
      ),
    );
  }
}

class _SentRequestsList extends ConsumerWidget {
  const _SentRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(sentReferralRequestsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sentReferralRequestsProvider),
      child: requestsAsync.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(sentReferralRequestsProvider)),
        data: (requests) {
          if (requests.isEmpty) {
            return const EmptyState(
              icon: Icons.badge_outlined,
              title: 'No referral requests yet',
              message: 'Browse Referrals to request one.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SentRequestCard(request: requests[i]),
          );
        },
      ),
    );
  }
}

class _SentRequestCard extends ConsumerStatefulWidget {
  const _SentRequestCard({required this.request});

  final ReferralRequest request;

  @override
  ConsumerState<_SentRequestCard> createState() => _SentRequestCardState();
}

class _SentRequestCardState extends ConsumerState<_SentRequestCard> {
  final _resumeUrlController = TextEditingController();

  @override
  void dispose() {
    _resumeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final controller = ref.read(referralControllerProvider.notifier);
    final isLoading = ref.watch(referralControllerProvider).isLoading;
    final canCancel = {
      ReferralRequestStatus.pending,
      ReferralRequestStatus.accepted,
      ReferralRequestStatus.resumeSubmitted,
    }.contains(r.status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => context.push(RoutePaths.referralOfferDetailOf(r.offerId)),
              leading: UserAvatar(
                  avatarUrl: r.referrerAvatarUrl, name: r.referrerName ?? '?'),
              title: Text(r.companyName ?? 'Referral'),
              subtitle: Text(r.jobTitle),
              trailing: Chip(
                  label: Text(r.status.label),
                  visualDensity: VisualDensity.compact),
            ),
            if (r.status == ReferralRequestStatus.accepted) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _resumeUrlController,
                decoration: const InputDecoration(
                    labelText: 'Resume link (Drive, portfolio, etc.)'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final url = _resumeUrlController.text.trim();
                        if (url.isEmpty) {
                          context.showSnack('Add a resume link first', isError: true);
                          return;
                        }
                        final ok = await controller.submitResume(r.id, url);
                        if (mounted) {
                          context.showSnack(ok ? 'Resume submitted' : 'Could not submit',
                              isError: !ok);
                        }
                      },
                child: const Text('Submit resume'),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : () => controller.cancelRequest(r.id),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
