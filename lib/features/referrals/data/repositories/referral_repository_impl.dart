import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../domain/entities/referral.dart';
import '../../domain/repositories/referral_repository.dart';

class ReferralRepositoryImpl implements ReferralRepository {
  ReferralRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const _offerSelect =
      '*, profiles!referral_offers_profile_id_fkey(full_name, avatar_url, current_role)';

  static const _requestSelect = '*, referral_offers(company_name), '
      'requester:profiles!referral_requests_requester_id_fkey(full_name, avatar_url), '
      'referrer:profiles!referral_requests_referrer_id_fkey(full_name, avatar_url)';

  @override
  Future<List<ReferralOffer>> listOffers({int limit = 20, int offset = 0}) async {
    try {
      final data = await _client
          .from(Tables.referralOffers)
          .select(_offerSelect)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => ReferralOffer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<ReferralOffer> getOffer(String id) async {
    try {
      final data = await _client
          .from(Tables.referralOffers)
          .select(_offerSelect)
          .eq('id', id)
          .single();
      return ReferralOffer.fromJson(data);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<ReferralOffer>> myOffers() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.referralOffers)
          .select(_offerSelect)
          .eq('profile_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => ReferralOffer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<ReferralOffer> createOffer(Map<String, dynamic> data) async {
    try {
      final myId = _client.auth.currentUser!.id;
      final inserted = await _client
          .from(Tables.referralOffers)
          .upsert({...data, 'profile_id': myId}, onConflict: 'profile_id,company_name')
          .select(_offerSelect)
          .single();
      return ReferralOffer.fromJson(inserted);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> setOfferActive(String offerId, bool isActive) async {
    try {
      await _client
          .from(Tables.referralOffers)
          .update({'is_active': isActive}).eq('id', offerId);
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<ReferralRequest>> listReceivedRequests(String offerId) async {
    try {
      final data = await _client
          .from(Tables.referralRequests)
          .select(_requestSelect)
          .eq('offer_id', offerId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => ReferralRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<List<ReferralRequest>> listSentRequests() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final data = await _client
          .from(Tables.referralRequests)
          .select(_requestSelect)
          .eq('requester_id', myId)
          .order('created_at', ascending: false);
      return (data as List)
          .map((e) => ReferralRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<String> requestReferral(String offerId,
      {required String jobTitle, String? jobUrl, String? message}) async {
    try {
      final id = await _client.rpc('request_referral', params: {
        'p_offer_id': offerId,
        'p_job_title': jobTitle,
        'p_job_url': jobUrl,
        'p_message': message,
      });
      return id as String;
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> respondToRequest(String requestId, {required bool accept}) async {
    try {
      await _client.rpc('respond_to_referral_request', params: {
        'p_request_id': requestId,
        'p_accept': accept,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> submitResume(String requestId, String resumeUrl) async {
    try {
      await _client.rpc('submit_referral_resume', params: {
        'p_request_id': requestId,
        'p_resume_url': resumeUrl,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> markSubmitted(String requestId) async {
    try {
      await _client.rpc('mark_referral_submitted',
          params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> updateOutcome(String requestId, String status) async {
    try {
      await _client.rpc('update_referral_outcome', params: {
        'p_request_id': requestId,
        'p_status': status,
      });
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }

  @override
  Future<void> cancelRequest(String requestId) async {
    try {
      await _client
          .rpc('cancel_referral_request', params: {'p_request_id': requestId});
    } catch (e) {
      throw mapExceptionToFailure(e);
    }
  }
}
