import '../entities/referral.dart';

abstract class ReferralRepository {
  Future<List<ReferralOffer>> listOffers({int limit = 20, int offset = 0});
  Future<ReferralOffer> getOffer(String id);
  Future<List<ReferralOffer>> myOffers();
  Future<ReferralOffer> createOffer(Map<String, dynamic> data);
  Future<void> setOfferActive(String offerId, bool isActive);

  Future<List<ReferralRequest>> listReceivedRequests(String offerId);
  Future<List<ReferralRequest>> listSentRequests();

  Future<String> requestReferral(String offerId,
      {required String jobTitle, String? jobUrl, String? message});
  Future<void> respondToRequest(String requestId, {required bool accept});
  Future<void> submitResume(String requestId, String resumeUrl);
  Future<void> markSubmitted(String requestId);
  Future<void> updateOutcome(String requestId, String status);
  Future<void> cancelRequest(String requestId);
}
