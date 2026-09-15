// Locks down the wire contract with mentor_profiles + its Phase 1 columns
// (0045_mentor_profile_details.sql), and that an existing mentor row
// (posted before this migration) still parses cleanly with every new
// field defaulting sensibly.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/mentorship/domain/entities/mentor.dart';

void main() {
  group('Mentor.fromJson', () {
    test('maps a fully populated row, including the nested profile embed', () {
      final mentor = Mentor.fromJson({
        'profile_id': 'user-1',
        'available': true,
        'expertise': ['Java', 'System Design'],
        'topics': ['Interview preparation', 'Resume review'],
        'session_duration_minutes': 45,
        'pricing_type': 'paid',
        'price': 500,
        'currency': 'INR',
        'bio': 'I help developers prepare for backend interviews.',
        'headline': 'Helping developers become better backend engineers',
        'mentorship_type': '1:1',
        'communication_modes': ['video_call', 'chat'],
        'availability_note': 'Mon & Wed 7-9 PM IST',
        'profiles': {'full_name': 'Ada Lovelace', 'avatar_url': 'https://a.png', 'current_role': 'Backend Engineer'},
      });

      expect(mentor.profileId, 'user-1');
      expect(mentor.available, isTrue);
      expect(mentor.expertise, ['Java', 'System Design']);
      expect(mentor.topics, ['Interview preparation', 'Resume review']);
      expect(mentor.sessionDurationMinutes, 45);
      expect(mentor.pricingType, 'paid');
      expect(mentor.isFree, isFalse);
      expect(mentor.price, 500);
      expect(mentor.currency, 'INR');
      expect(mentor.headline, 'Helping developers become better backend engineers');
      expect(mentor.mentorshipType, '1:1');
      expect(mentor.communicationModes, ['video_call', 'chat']);
      expect(mentor.availabilityNote, 'Mon & Wed 7-9 PM IST');
      expect(mentor.fullName, 'Ada Lovelace');
      expect(mentor.avatarUrl, 'https://a.png');
      expect(mentor.currentRole, 'Backend Engineer');
    });

    test('a mentor row posted before 0045_mentor_profile_details.sql still parses cleanly', () {
      final mentor = Mentor.fromJson({
        'profile_id': 'user-2',
        'available': true,
        'expertise': ['Python'],
        'topics': <String>[],
        'session_duration_minutes': 30,
        'pricing_type': 'free',
        'bio': 'Happy to help.',
      });

      expect(mentor.headline, isNull);
      expect(mentor.mentorshipType, isNull);
      expect(mentor.communicationModes, isEmpty);
      expect(mentor.availabilityNote, isNull);
      expect(mentor.isFree, isTrue);
      expect(mentor.isAccepting, isTrue);
    });
  });

  test('CommunicationMode.label maps every known value and falls back for unknown ones', () {
    expect(CommunicationMode.label(CommunicationMode.chat), 'Chat');
    expect(CommunicationMode.label(CommunicationMode.videoCall), 'Video call');
    expect(CommunicationMode.label(CommunicationMode.voiceCall), 'Voice call');
    expect(CommunicationMode.label(CommunicationMode.inPerson), 'In-person');
    expect(CommunicationMode.label('carrier_pigeon'), 'carrier_pigeon');
  });
}
