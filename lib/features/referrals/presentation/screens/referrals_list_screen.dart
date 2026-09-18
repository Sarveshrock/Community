import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../home/presentation/widgets/home_style.dart';
import '../providers/referral_providers.dart';

/// Browse active referral offers (spec-extension: Referral Marketplace).
/// "Offering a referral" is content you create, so it also lives in the
/// Create menu — this screen's app-bar actions are for managing what you've
/// already posted/sent, mirroring the Jobs feature's shape.
class ReferralsListScreen extends ConsumerWidget {
  const ReferralsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offersAsync = ref.watch(referralOffersListProvider);

    return Scaffold(
      backgroundColor: HomeStyle.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GlowBackdrop()),
          SafeArea(
            child: ResponsiveCenter(
              child: Column(
                children: [
                  _Header(
                    onCreate: () => context.push(RoutePaths.newReferralOffer),
                    onMyRequests: () =>
                        context.push(RoutePaths.myReferralRequests),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      backgroundColor: HomeStyle.cardBase,
                      color: HomeStyle.purple,
                      onRefresh: () async =>
                          ref.invalidate(referralOffersListProvider),
                      child: offersAsync.when(
                        loading: () => const SkeletonList(),
                        error: (e, _) => ErrorState(
                            message: e.toString(),
                            onRetry: () =>
                                ref.invalidate(referralOffersListProvider)),
                        data: (offers) {
                          if (offers.isEmpty) {
                            return const EmptyState(
                              icon: Icons.badge_outlined,
                              title: 'No referral offers yet',
                              message:
                                  'Be the first to offer a referral at your company.',
                            );
                          }
                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            itemCount: offers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final o = offers[i];
                              return Material(
                                color: HomeStyle.cardBase,
                                borderRadius: BorderRadius.circular(16),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => context.push(
                                      RoutePaths.referralOfferDetailOf(o.id)),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.06)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        UserAvatar(
                                            avatarUrl: o.avatarUrl,
                                            name: o.fullName ?? '?',
                                            radius: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(o.companyName,
                                                  style: const TextStyle(
                                                      fontSize: 14.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: HomeStyle
                                                          .textPrimary)),
                                              const SizedBox(height: 2),
                                              Text(
                                                [
                                                  if (o.fullName != null)
                                                    o.fullName!,
                                                  if (o.roleTitle != null)
                                                    o.roleTitle!,
                                                ].join(' · '),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontSize: 12.5,
                                                    color: HomeStyle
                                                        .textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded,
                                            color: HomeStyle.textSecondary),
                                      ],
                                    ),
                                  ),
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
  const _Header({required this.onCreate, required this.onMyRequests});

  final VoidCallback onCreate;
  final VoidCallback onMyRequests;

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
            child: Text('Referrals',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: HomeStyle.textPrimary)),
          ),
          _IconButton(
              icon: Icons.assignment_outlined,
              tooltip: 'My requests',
              onTap: onMyRequests),
          const SizedBox(width: 8),
          _IconButton(
              icon: Icons.add_rounded,
              tooltip: 'Offer a referral',
              highlighted: true,
              onTap: onCreate),
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
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: highlighted ? HomeStyle.brandGradient : null,
          color: highlighted ? null : HomeStyle.cardBase,
          borderRadius: BorderRadius.circular(13),
          border: highlighted
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Icon(icon,
                color: highlighted ? Colors.white : HomeStyle.textPrimary,
                size: 21),
          ),
        ),
      ),
    );
  }
}
