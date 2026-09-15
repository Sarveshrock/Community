// Locks down InterviewPracticeProfile/Request.fromJson's nested-relation
// parsing (pool member profile, requester/partner aliases) — a mismatch
// here means names/topics silently go blank in the practice-pool UI.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/models/skill.dart';
import 'package:community_app/features/interview_practice/domain/entities/interview_practice.dart';

void main() {
  test('InterviewPracticeProfile.fromJson parses topics and joined profile', () {
    final profile = InterviewPracticeProfile.fromJson({
      'profile_id': 'user-1',
      'target_role': 'Frontend Engineer',
      'topics': ['React', 'System Design'],
      'experience_level': 'advanced',
      'is_active': true,
      'profiles': {'full_name': 'Ada', 'avatar_url': 'https://x.test/a.png'},
    });

    expect(profile.targetRole, 'Frontend Engineer');
    expect(profile.topics, ['React', 'System Design']);
    expect(profile.experienceLevel, ExperienceLevel.advanced);
    expect(profile.fullName, 'Ada');
  });

  test('InterviewPracticeProfile.fromJson defaults topics/level when absent', () {
    final profile = InterviewPracticeProfile.fromJson({
      'profile_id': 'user-1',
      'target_role': 'Backend Engineer',
    });

    expect(profile.topics, isEmpty);
    expect(profile.experienceLevel, ExperienceLevel.intermediate);
    expect(profile.isActive, true);
  });

  test('InterviewPracticeRequest.fromJson parses requester/partner aliases', () {
    final request = InterviewPracticeRequest.fromJson({
      'id': 'req-1',
      'requester_id': 'user-1',
      'partner_id': 'user-2',
      'target_role': 'Frontend Engineer',
      'status': 'accepted',
      'created_at': '2026-01-01T00:00:00Z',
      'requester': {'full_name': 'Ada', 'avatar_url': null},
      'partner': {'full_name': 'Ben', 'avatar_url': 'https://x.test/b.png'},
    });

    expect(request.requesterName, 'Ada');
    expect(request.partnerName, 'Ben');
    expect(request.status, InterviewPracticeStatus.accepted);
  });

  test('InterviewPracticeRequest.fromJson defaults status to pending when absent', () {
    final request = InterviewPracticeRequest.fromJson({
      'id': 'req-2',
      'requester_id': 'user-1',
      'partner_id': 'user-2',
      'target_role': 'Backend Engineer',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(request.status, InterviewPracticeStatus.pending);
  });
}
