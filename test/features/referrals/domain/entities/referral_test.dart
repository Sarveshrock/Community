// Locks down ReferralOffer/ReferralRequest.fromJson's nested-relation
// parsing (offer owner profile, requester/referrer aliases) — a mismatch
// here means names/avatars silently go blank in the referral pipeline UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/referrals/domain/entities/referral.dart';

void main() {
  test('ReferralOffer.fromJson parses the joined owner profile', () {
    final offer = ReferralOffer.fromJson({
      'id': 'offer-1',
      'profile_id': 'user-1',
      'company_name': 'Acme Corp',
      'role_title': 'Software Engineer',
      'notes': 'Only SDE roles',
      'is_active': true,
      'created_at': '2026-01-01T00:00:00Z',
      'profiles': {
        'full_name': 'Ada',
        'avatar_url': 'https://x.test/a.png',
        'current_role': 'Staff Engineer',
      },
    });

    expect(offer.companyName, 'Acme Corp');
    expect(offer.fullName, 'Ada');
    expect(offer.currentRole, 'Staff Engineer');
    expect(offer.isActive, true);
  });

  test('ReferralOffer.fromJson tolerates a missing joined profile', () {
    final offer = ReferralOffer.fromJson({
      'id': 'offer-2',
      'profile_id': 'user-1',
      'company_name': 'Acme Corp',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(offer.fullName, isNull);
    expect(offer.isActive, true);
    expect(offer.roleTitle, isNull);
  });

  test('ReferralRequest.fromJson parses requester/referrer aliases and status', () {
    final request = ReferralRequest.fromJson({
      'id': 'req-1',
      'offer_id': 'offer-1',
      'referrer_id': 'user-1',
      'requester_id': 'user-2',
      'job_title': 'Frontend Engineer',
      'status': 'resume_submitted',
      'created_at': '2026-01-01T00:00:00Z',
      'referral_offers': {'company_name': 'Acme Corp'},
      'requester': {'full_name': 'Ben', 'avatar_url': null},
      'referrer': {'full_name': 'Ada', 'avatar_url': 'https://x.test/a.png'},
    });

    expect(request.companyName, 'Acme Corp');
    expect(request.requesterName, 'Ben');
    expect(request.referrerName, 'Ada');
    expect(request.status, ReferralRequestStatus.resumeSubmitted);
  });

  test('ReferralRequest.fromJson defaults status to pending when absent', () {
    final request = ReferralRequest.fromJson({
      'id': 'req-2',
      'offer_id': 'offer-1',
      'referrer_id': 'user-1',
      'requester_id': 'user-2',
      'job_title': 'Backend Engineer',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(request.status, ReferralRequestStatus.pending);
    expect(request.companyName, isNull);
  });
}
