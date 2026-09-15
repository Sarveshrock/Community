// Every enum extension in this codebase maps a Dart enum to/from the exact
// string stored in Postgres (see the matching `create type ... as enum`
// statements in supabase/migrations/0002_enums.sql). A mismatch here means
// writes silently fail a check constraint or reads silently fall back to a
// default value — worth locking down with a round-trip test per enum.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/models/user_type.dart';
import 'package:community_app/core/models/skill.dart';
import 'package:community_app/features/profile/domain/entities/experience.dart';
import 'package:community_app/features/profile/domain/entities/optional_proof.dart';
import 'package:community_app/features/jobs/domain/entities/job.dart';
import 'package:community_app/features/projects/domain/entities/project.dart';
import 'package:community_app/features/moderation/domain/report_target.dart';
import 'package:community_app/features/referrals/domain/entities/referral.dart';
import 'package:community_app/features/interview_practice/domain/entities/interview_practice.dart';
import 'package:community_app/features/intents/domain/entities/intent.dart';

void main() {
  test('UserType round-trips through its Postgres enum value', () {
    for (final type in UserType.values) {
      expect(UserTypeX.fromValue(type.value), type);
    }
    expect(UserType.jobSeeker.value, 'job_seeker');
    expect(UserTypeX.fromValue('unknown_value'), UserType.other);
  });

  test('ExperienceLevel round-trips through its Postgres enum value', () {
    for (final level in ExperienceLevel.values) {
      expect(ExperienceLevelX.fromValue(level.value), level);
    }
  });

  test('EmploymentType round-trips through its Postgres enum value', () {
    for (final type in EmploymentType.values) {
      expect(EmploymentTypeX.fromValue(type.value), type);
    }
    expect(EmploymentType.fullTime.value, 'full_time');
  });

  test('ProofType round-trips through its Postgres enum value', () {
    for (final type in ProofType.values) {
      expect(ProofTypeX.fromValue(type.value), type);
    }
  });

  test('JobEmploymentType round-trips through its Postgres enum value', () {
    for (final type in JobEmploymentType.values) {
      expect(JobEmploymentTypeX.fromValue(type.value), type);
    }
    expect(JobEmploymentType.fullTime.value, 'full_time');
    expect(JobEmploymentType.partTime.value, 'part_time');
  });

  test('WorkMode round-trips through its Postgres enum value', () {
    for (final mode in WorkMode.values) {
      expect(WorkModeX.fromValue(mode.value), mode);
    }
  });

  test('CollaborationType round-trips through its Postgres enum value', () {
    for (final type in CollaborationType.values) {
      expect(CollaborationTypeX.fromValue(type.value), type);
    }
    expect(CollaborationType.openSource.value, 'open_source');
  });

  test('CompensationType round-trips through its Postgres enum value', () {
    for (final type in CompensationType.values) {
      expect(CompensationTypeX.fromValue(type.value), type);
    }
  });

  test('ReportTargetType round-trips through its Postgres enum value', () {
    for (final type in ReportTargetType.values) {
      expect(ReportTargetTypeX.fromValue(type.value), type);
    }
  });

  test('ReportCategory round-trips through its Postgres enum value', () {
    for (final category in ReportCategory.values) {
      expect(ReportCategoryX.fromValue(category.value), category);
    }
    expect(ReportCategory.fakeProfile.value, 'fake_profile');
    expect(ReportCategory.inappropriateContent.value, 'inappropriate_content');
    expect(ReportCategory.unsafeBehavior.value, 'unsafe_behavior');
  });

  test('ReportStatus round-trips through its Postgres enum value', () {
    for (final status in ReportStatus.values) {
      expect(ReportStatusX.fromValue(status.value), status);
    }
    expect(ReportStatusX.fromValue('unknown_value'), ReportStatus.open);
  });

  test('ReferralRequestStatus round-trips through its Postgres enum value', () {
    for (final status in ReferralRequestStatus.values) {
      expect(ReferralRequestStatusX.fromValue(status.value), status);
    }
    expect(ReferralRequestStatus.resumeSubmitted.value, 'resume_submitted');
    expect(ReferralRequestStatus.referralSubmitted.value, 'referral_submitted');
  });

  test('InterviewPracticeStatus round-trips through its Postgres enum value', () {
    for (final status in InterviewPracticeStatus.values) {
      expect(InterviewPracticeStatusX.fromValue(status.value), status);
    }
  });

  test('IntentType round-trips through its Postgres enum value', () {
    for (final type in IntentType.values) {
      expect(IntentTypeX.fromValue(type.value), type);
    }
    expect(IntentType.findHackathonTeam.value, 'find_hackathon_team');
    expect(IntentType.offerCollaboration.value, 'offer_collaboration');
  });

  test('IntentVisibility round-trips through its Postgres enum value', () {
    for (final visibility in IntentVisibility.values) {
      expect(IntentVisibilityX.fromValue(visibility.value), visibility);
    }
    expect(IntentVisibility.connectionsOnly.value, 'connections_only');
  });

  test('IntentStatus round-trips through its Postgres enum value', () {
    for (final status in IntentStatus.values) {
      expect(IntentStatusX.fromValue(status.value), status);
    }
  });
}
