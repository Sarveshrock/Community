import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/app_router.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_state.dart';
import '../../../../core/widgets/loading_state.dart';
import '../../../../core/widgets/user_avatar.dart';
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
      appBar: AppBar(
        title: const Text('Referrals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment_outlined),
            tooltip: 'My requests',
            onPressed: () => context.push(RoutePaths.myReferralRequests),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RoutePaths.newReferralOffer),
        icon: const Icon(Icons.add),
        label: const Text('Offer a referral'),
      ),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(referralOffersListProvider),
          child: offersAsync.when(
            loading: () => const SkeletonList(),
            error: (e, _) => ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(referralOffersListProvider)),
            data: (offers) {
              if (offers.isEmpty) {
                return const EmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No referral offers yet',
                  message: 'Be the first to offer a referral at your company.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final o = offers[i];
                  return Card(
                    child: ListTile(
                      onTap: () =>
                          context.push(RoutePaths.referralOfferDetailOf(o.id)),
                      leading: UserAvatar(
                          avatarUrl: o.avatarUrl,
                          name: o.fullName ?? '?',
                          radius: 24),
                      title: Text(o.companyName,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        [
                          if (o.fullName != null) o.fullName!,
                          if (o.roleTitle != null) o.roleTitle!,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
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
