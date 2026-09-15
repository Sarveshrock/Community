// Locks down the wire contract with communities + its Phase 1 columns
// (0047_community_rich_details.sql), and that an existing community row
// (only name/description/type/is_private) still parses cleanly with every
// new field defaulting sensibly.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/communities/domain/entities/community.dart';

void main() {
  group('Community.fromJson', () {
    test('a community posted before this migration still parses cleanly, new sections simply absent', () {
      final community = Community.fromJson({
        'id': 'c-old',
        'owner_id': 'owner-1',
        'name': 'Old Community',
        'slug': 'old-community',
        'description': 'An old community row.',
        'community_type': 'technology',
        'is_private': false,
        'community_members': [
          {'profile_id': 'owner-1'},
        ],
      });

      expect(community.tagline, isNull);
      expect(community.logoUrl, isNull);
      expect(community.activities, isEmpty);
      expect(community.audience, isEmpty);
      expect(community.rules, isNull);
      expect(community.accessType, 'public');
      expect(community.isPublic, isTrue);
      expect(community.topicNames, isEmpty);
      expect(community.memberCount, 1);
      // Old enum values still label correctly (backward compat).
      expect(communityTypeLabel('city'), 'Local');
      expect(communityTypeLabel('student'), 'College / University');
    });

    test('maps a fully populated row, including topics', () {
      final community = Community.fromJson({
        'id': 'c-new',
        'owner_id': 'owner-1',
        'name': 'Java Developers India',
        'slug': 'java-developers-india',
        'tagline': 'Learn, build and grow with Java developers.',
        'description': 'A community for Java developers of all levels.',
        'community_type': 'professional',
        'is_private': true,
        'logo_url': 'https://example.com/logo.png',
        'activities': ['Discussions', 'Learning'],
        'audience': ['Developers', 'Students'],
        'rules': '1. Be respectful\n2. No spam',
        'access_type': 'request_to_join',
        'community_topics': [
          {
            'skills': {'name': 'Java'}
          },
          {
            'skills': {'name': 'Spring Boot'}
          },
        ],
        'community_members': [
          {'profile_id': 'owner-1'},
          {'profile_id': 'member-2'},
        ],
      });

      expect(community.tagline, 'Learn, build and grow with Java developers.');
      expect(community.communityType, 'professional');
      expect(community.logoUrl, 'https://example.com/logo.png');
      expect(community.activities, ['Discussions', 'Learning']);
      expect(community.audience, ['Developers', 'Students']);
      expect(community.rules, '1. Be respectful\n2. No spam');
      expect(community.accessType, 'request_to_join');
      expect(community.isRequestToJoin, isTrue);
      expect(community.isPublic, isFalse);
      expect(community.topicNames, ['Java', 'Spring Boot']);
      expect(community.memberCount, 2);
      expect(community.isOwner('owner-1'), isTrue);
      expect(community.isOwner('member-2'), isFalse);
    });
  });

  test('CommunityMember.fromJson parses the joined profile and role', () {
    final member = CommunityMember.fromJson({
      'profile_id': 'member-1',
      'role': 'moderator',
      'joined_at': '2026-01-01T00:00:00Z',
      'profiles': {
        'full_name': 'Ada Lovelace',
        'avatar_url': 'https://example.com/a.png',
        'current_role': 'Engineer',
        'current_company': 'Analytical Co',
      },
    });

    expect(member.displayName, 'Ada Lovelace');
    expect(member.isModerator, isTrue);
    expect(member.isOwnerRole, isFalse);
    expect(member.headline, 'Engineer at Analytical Co');
  });

  test('CommunityQuestion.fromJson parses nested answers', () {
    final question = CommunityQuestion.fromJson({
      'id': 'q1',
      'community_id': 'c1',
      'asker_id': 'u1',
      'question_text': 'Is this beginner friendly?',
      'created_at': '2026-01-01T00:00:00Z',
      'profiles': {'full_name': 'Rahul'},
      'community_answers': [
        {
          'id': 'a1',
          'question_id': 'q1',
          'responder_id': 'u2',
          'answer_text': 'Yes, very much so.',
          'created_at': '2026-01-02T00:00:00Z',
          'profiles': {'full_name': 'Priya'},
        },
      ],
    });

    expect(question.askerName, 'Rahul');
    expect(question.answers, hasLength(1));
    expect(question.answers.first.responderName, 'Priya');
    expect(question.answers.first.answerText, 'Yes, very much so.');
  });

  test('CommunityPost.fromJson counts comments and flags announcements', () {
    final post = CommunityPost.fromJson({
      'id': 'p1',
      'community_id': 'c1',
      'author_id': 'u1',
      'content': 'Tomorrow\'s discussion starts at 8 PM.',
      'created_at': '2026-01-01T00:00:00Z',
      'is_announcement': true,
      'community_comments': [
        {'id': 'cm1'},
        {'id': 'cm2'},
      ],
    });

    expect(post.isAnnouncement, isTrue);
    expect(post.commentCount, 2);
  });

  test('an old post row without is_announcement/comments still parses cleanly', () {
    final post = CommunityPost.fromJson({
      'id': 'p2',
      'community_id': 'c1',
      'author_id': 'u1',
      'content': 'Hello!',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(post.isAnnouncement, isFalse);
    expect(post.commentCount, 0);
  });
}
