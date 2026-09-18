import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/form_section_card.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/referral_providers.dart';

/// The requester's-eye view of the referral pipeline: what's been requested,
/// where each is in the stage sequence, and the action available next
/// (submit a resume once accepted, or cancel while still open).
class MyReferralRequestsScreen extends StatelessWidget {
  const MyReferralRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(),
                  Expanded(child: _SentRequestsList()),
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
            child: Text('My Referral Requests',
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

class _SentRequestsList extends ConsumerWidget {
  const _SentRequestsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(sentReferralRequestsProvider);

    return RefreshIndicator(
      backgroundColor: HomeStyle.cardBase,
      color: HomeStyle.purple,
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomeStyle.cardBase,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () =>
                  context.push(RoutePaths.referralOfferDetailOf(r.offerId)),
              child: Row(
                children: [
                  UserAvatar(
                      avatarUrl: r.referrerAvatarUrl,
                      name: r.referrerName ?? '?'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.companyName ?? 'Referral',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: HomeStyle.textPrimary)),
                        const SizedBox(height: 2),
                        Text(r.jobTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: HomeStyle.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HomeChip(r.status.label, accent: HomeStyle.blue),
                ],
              ),
            ),
          ),
          if (r.status == ReferralRequestStatus.accepted) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _resumeUrlController,
              style: const TextStyle(color: HomeStyle.textPrimary),
              decoration:
                  darkInputDecoration('Resume link (Drive, portfolio, etc.)'),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: isLoading
                    ? null
                    : () async {
                        final url = _resumeUrlController.text.trim();
                        if (url.isEmpty) {
                          context.showSnack('Add a resume link first',
                              isError: true);
                          return;
                        }
                        final ok = await controller.submitResume(r.id, url);
                        if (context.mounted) {
                          context.showSnack(
                              ok ? 'Resume submitted' : 'Could not submit',
                              isError: !ok);
                        }
                      },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isLoading ? null : HomeStyle.brandGradient,
                    color: isLoading ? HomeStyle.cardBase : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Submit resume',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
          if (canCancel) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : () => controller.cancelRequest(r.id),
                style: TextButton.styleFrom(
                    foregroundColor: HomeStyle.textSecondary),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
