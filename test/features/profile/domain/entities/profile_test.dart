import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/models/user_type.dart';
import 'package:community_app/features/profile/domain/entities/profile.dart';

void main() {
  group('Profile.fromJson', () {
    test('maps a fully populated row, including nested skills/interests', () {
      final profile = Profile.fromJson({
        'id': 'user-1',
        'username': 'ada',
        'full_name': 'Ada Lovelace',
        'avatar_url': 'https://example.com/a.png',
        'bio': 'Building things.',
        'city': 'Bengaluru',
        'country': 'India',
        'primary_user_type': 'developer',
        'current_company': 'Analytical Engines Inc',
        'current_role': 'Software Engineer',
        'total_it_experience_months': 30,
        'is_open_to_work': true,
        'is_open_to_mentorship': true,
        'professional_discoverable': true,
        'local_discoverable': false,
        'profile_completed': true,
        'profile_skills': [
          {
            'experience_level': 'advanced',
            'years_experience': 3.5,
            'skills': {
              'id': 'skill-1',
              'name': 'Flutter',
              'category': 'mobile'
            },
          },
        ],
        'profile_interests': [
          {
            'interests': {'id': 'interest-1', 'name': 'AI'},
          },
        ],
      });

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Ada Lovelace');
      expect(profile.headline, 'Software Engineer at Analytical Engines Inc');
      expect(profile.primaryUserType, UserType.developer);
      expect(profile.skills, hasLength(1));
      expect(profile.skills.first.skill.name, 'Flutter');
      expect(profile.interests, hasLength(1));
      expect(profile.interests.first.name, 'AI');
    });

    test('falls back to sensible defaults for a minimal row', () {
      final profile = Profile.fromJson({'id': 'user-2'});

      expect(profile.displayName, 'Community member');
      expect(profile.primaryUserType, UserType.other);
      expect(profile.headline, 'Other');
      expect(profile.totalItExperienceMonths, 0);
      expect(profile.profileCompleted, false);
      expect(profile.skills, isEmpty);
      expect(profile.interests, isEmpty);
      expect(profile.updatedAt, isNull);
    });

    test('parses updated_at, reused elsewhere as a presence proxy', () {
      final profile = Profile.fromJson({
        'id': 'user-4',
        'updated_at': '2026-09-01T12:00:00Z',
      });

      expect(profile.updatedAt, DateTime.parse('2026-09-01T12:00:00Z'));
    });

    test(
        'headline prefers role-only over the primary user type when company is missing',
        () {
      final profile = Profile.fromJson({
        'id': 'user-3',
        'current_role': 'Researcher',
        'primary_user_type': 'researcher',
      });

      expect(profile.headline, 'Researcher');
    });

    test('a pre-0049 row with no photo_visibility/app_icon_style column defaults safely', () {
      final profile = Profile.fromJson({'id': 'user-5'});

      expect(profile.photoVisibility, ProfilePhotoVisibility.everyone);
      expect(profile.appIconStyle, 'classic');
    });

    test('parses every photo_visibility value', () {
      expect(Profile.fromJson({'id': 'a', 'photo_visibility': 'everyone'}).photoVisibility,
          ProfilePhotoVisibility.everyone);
      expect(Profile.fromJson({'id': 'a', 'photo_visibility': 'connections'}).photoVisibility,
          ProfilePhotoVisibility.connections);
      expect(Profile.fromJson({'id': 'a', 'photo_visibility': 'only_me'}).photoVisibility,
          ProfilePhotoVisibility.onlyMe);
    });

    test('an unrecognized photo_visibility value falls back to everyone, never crashes', () {
      final profile = Profile.fromJson({'id': 'a', 'photo_visibility': 'literally anything else'});
      expect(profile.photoVisibility, ProfilePhotoVisibility.everyone);
    });

    test('parses app_icon_style', () {
      final profile = Profile.fromJson({'id': 'a', 'app_icon_style': 'neon'});
      expect(profile.appIconStyle, 'neon');
    });
  });

  group('ProfilePhotoVisibilityX', () {
    test('value round-trips through fromValue for every enum member', () {
      for (final v in ProfilePhotoVisibility.values) {
        expect(ProfilePhotoVisibilityX.fromValue(v.value), v);
      }
    });
  });
}
