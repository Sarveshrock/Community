import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/analytics_events.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../core/network/supabase_config.dart';
import '../../data/repositories/referral_repository_impl.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/referral_repository.dart';

export '../../domain/entities/referral.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepositoryImpl(supabase);
});

final referralOffersListProvider = FutureProvider<List<ReferralOffer>>((ref) {
  return ref.watch(referralRepositoryProvider).listOffers();
});

final referralOfferDetailProvider =
    FutureProvider.family<ReferralOffer, String>((ref, id) {
  return ref.watch(referralRepositoryProvider).getOffer(id);
});

final myReferralOffersProvider = FutureProvider<List<ReferralOffer>>((ref) {
  return ref.watch(referralRepositoryProvider).myOffers();
});

final receivedReferralRequestsProvider =
    FutureProvider.family<List<ReferralRequest>, String>((ref, offerId) {
  return ref.watch(referralRepositoryProvider).listReceivedRequests(offerId);
});

final sentReferralRequestsProvider =
    FutureProvider<List<ReferralRequest>>((ref) {
  return ref.watch(referralRepositoryProvider).listSentRequests();
});

class ReferralController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createOffer(Map<String, dynamic> data) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(referralRepositoryProvider).createOffer(data));
    state = result;
    if (!result.hasError) {
      ref.invalidate(referralOffersListProvider);
      ref.invalidate(myReferralOffersProvider);
    }
    return !result.hasError;
  }

  Future<bool> setOfferActive(String offerId, bool isActive) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(referralRepositoryProvider).setOfferActive(offerId, isActive));
    state = result;
    if (!result.hasError) {
      ref.invalidate(referralOffersListProvider);
      ref.invalidate(myReferralOffersProvider);
      ref.invalidate(referralOfferDetailProvider(offerId));
    }
    return !result.hasError;
  }

  Future<bool> requestReferral(String offerId,
      {required String jobTitle, String? jobUrl, String? message}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(referralRepositoryProvider)
        .requestReferral(offerId, jobTitle: jobTitle, jobUrl: jobUrl, message: message));
    state = result;
    if (!result.hasError) {
      ref.invalidate(sentReferralRequestsProvider);
      ref
          .read(analyticsServiceProvider)
          .log(AnalyticsEvents.referralRequested, {'offer_id': offerId});
    }
    return !result.hasError;
  }

  Future<bool> respondToRequest(String requestId, String offerId,
      {required bool accept}) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() => ref
        .read(referralRepositoryProvider)
        .respondToRequest(requestId, accept: accept));
    state = result;
    if (!result.hasError) ref.invalidate(receivedReferralRequestsProvider(offerId));
    return !result.hasError;
  }

  Future<bool> submitResume(String requestId, String resumeUrl) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(referralRepositoryProvider).submitResume(requestId, resumeUrl));
    state = result;
    if (!result.hasError) ref.invalidate(sentReferralRequestsProvider);
    return !result.hasError;
  }

  Future<bool> markSubmitted(String requestId, String offerId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(referralRepositoryProvider).markSubmitted(requestId));
    state = result;
    if (!result.hasError) ref.invalidate(receivedReferralRequestsProvider(offerId));
    return !result.hasError;
  }

  Future<bool> updateOutcome(String requestId, String offerId, String status) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(() =>
        ref.read(referralRepositoryProvider).updateOutcome(requestId, status));
    state = result;
    if (!result.hasError) ref.invalidate(receivedReferralRequestsProvider(offerId));
    return !result.hasError;
  }

  Future<bool> cancelRequest(String requestId) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
        () => ref.read(referralRepositoryProvider).cancelRequest(requestId));
    state = result;
    if (!result.hasError) ref.invalidate(sentReferralRequestsProvider);
    return !result.hasError;
  }
}

final referralControllerProvider =
    AsyncNotifierProvider<ReferralController, void>(ReferralController.new);
