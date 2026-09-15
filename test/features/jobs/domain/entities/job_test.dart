// Locks down the wire contract with the jobs table + its richer Phase 1
// columns (0043_jobs_rich_details.sql), and — critically — that a job row
// posted before this migration (only the original 9 fields ever set) still
// parses cleanly with every new field defaulting sensibly, never crashing
// and never showing a literal "null".

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/core/models/skill.dart';
import 'package:community_app/features/jobs/domain/entities/job.dart';

void main() {
  group('Job.fromJson', () {
    test('maps a fully populated row, including nested skill embeds', () {
      final job = Job.fromJson({
        'id': 'job-1',
        'poster_id': 'poster-1',
        'company_name': 'Acme Corp',
        'company_logo_url': 'https://example.com/logo.png',
        'company_website': 'https://acme.example',
        'company_description': 'We build things.',
        'title': 'Senior Backend Engineer',
        'job_category': 'Software Engineering',
        'description': 'Build and scale our backend.',
        'employment_type': 'full_time',
        'work_mode': 'hybrid',
        'location': 'Bengaluru, India',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'country': 'India',
        'expected_office_days': '3 days/week',
        'responsibilities': ['Own the API', 'Mentor juniors'],
        'experience_level': 'advanced',
        'experience_min_months': 36,
        'experience_max_months': 60,
        'education': "Bachelor's in CS",
        'prerequisites': 'Strong SQL',
        'salary_min': 150000,
        'salary_max': 200000,
        'currency': 'USD',
        'pay_period': 'yearly',
        'salary_visible': true,
        'salary_negotiable': true,
        'bonus_info': '10% annual bonus',
        'equity_info': '0.1% vested over 4 years',
        'benefits': ['Health insurance', 'Remote work'],
        'internship_duration_months': null,
        'stipend': null,
        'potential_conversion': false,
        'notice_period_days': 30,
        'application_method': 'communeo',
        'application_url': null,
        'application_instructions': 'Apply with your GitHub profile',
        'resume_required': true,
        'portfolio_required': false,
        'cover_letter_required': false,
        'contact_info': 'hr@acme.example',
        'deadline': '2026-12-01T00:00:00Z',
        'status': 'open',
        'created_at': '2026-01-01T00:00:00Z',
        'job_required_skills': [
          {
            'skills': {'name': 'Dart'}
          },
          {
            'skills': {'name': 'PostgreSQL'}
          },
        ],
        'job_preferred_skills': [
          {
            'skills': {'name': 'Kubernetes'}
          },
        ],
      });

      expect(job.id, 'job-1');
      expect(job.companyName, 'Acme Corp');
      expect(job.companyLogoUrl, 'https://example.com/logo.png');
      expect(job.title, 'Senior Backend Engineer');
      expect(job.jobCategory, 'Software Engineering');
      expect(job.employmentType, JobEmploymentType.fullTime);
      expect(job.workMode, WorkMode.hybrid);
      expect(job.city, 'Bengaluru');
      expect(job.expectedOfficeDays, '3 days/week');
      expect(job.responsibilities, ['Own the API', 'Mentor juniors']);
      expect(job.experienceLevel, ExperienceLevel.advanced);
      expect(job.education, "Bachelor's in CS");
      expect(job.payPeriod, PayPeriod.yearly);
      expect(job.salaryNegotiable, isTrue);
      expect(job.benefits, ['Health insurance', 'Remote work']);
      expect(job.applicationMethod, JobApplicationMethod.communeo);
      expect(job.isInternalApplication, isTrue);
      expect(job.resumeRequired, isTrue);
      expect(job.contactInfo, 'hr@acme.example');
      expect(job.requiredSkillNames, ['Dart', 'PostgreSQL']);
      expect(job.preferredSkillNames, ['Kubernetes']);
      expect(job.hasCompensationInfo, isTrue);
      expect(job.isInternship, isFalse);
    });

    test('a job posted before this migration (only the original 9 fields) '
        'still parses cleanly with every new field defaulting sensibly', () {
      final job = Job.fromJson({
        'id': 'job-old',
        'poster_id': 'poster-1',
        'company_name': 'Old Co',
        'title': 'Legacy role',
        'description': 'An old job row.',
        'employment_type': 'full_time',
        'work_mode': 'remote',
        'location': 'Remote',
        'created_at': '2024-01-01T00:00:00Z',
      });

      expect(job.companyLogoUrl, isNull);
      expect(job.companyWebsite, isNull);
      expect(job.jobCategory, isNull);
      expect(job.responsibilities, isEmpty);
      expect(job.experienceLevel, isNull);
      expect(job.education, isNull);
      expect(job.payPeriod, isNull);
      expect(job.salaryVisible, isTrue);
      expect(job.salaryNegotiable, isFalse);
      expect(job.benefits, isEmpty);
      expect(job.potentialConversion, isFalse);
      // Backward-compat default: every existing row only ever had
      // application_url, never an application_method — must default to
      // external so old jobs keep behaving exactly as before.
      expect(job.applicationMethod, JobApplicationMethod.external);
      expect(job.isInternalApplication, isFalse);
      expect(job.resumeRequired, isFalse);
      expect(job.portfolioRequired, isFalse);
      expect(job.coverLetterRequired, isFalse);
      expect(job.contactInfo, isNull);
      expect(job.requiredSkillNames, isEmpty);
      expect(job.preferredSkillNames, isEmpty);
      expect(job.status, 'open');
      // 0044_job_employment_type_fields.sql columns — also new, also absent
      // on this old row, must default cleanly.
      expect(job.engagementDuration, isNull);
      expect(job.hoursPerWeek, isNull);
      expect(job.workSchedule, isNull);
      expect(job.contractStartDate, isNull);
      expect(job.contractEndDate, isNull);
      expect(job.renewable, isFalse);
    });

    test('maps the Employment-Type-specific columns from 0044_job_employment_type_fields.sql', () {
      final job = Job.fromJson({
        'id': 'job-2',
        'poster_id': 'poster-1',
        'company_name': 'Acme Corp',
        'title': 'Contract Engineer',
        'employment_type': 'contract',
        'work_mode': 'remote',
        'created_at': '2026-01-01T00:00:00Z',
        'pay_period': 'fixed',
        'engagement_duration': '6 months',
        'hours_per_week': 20,
        'work_schedule': 'Mon-Fri mornings',
        'contract_start_date': '2026-02-01',
        'contract_end_date': '2026-08-01',
        'renewable': true,
      });

      expect(job.payPeriod, PayPeriod.fixed);
      expect(job.engagementDuration, '6 months');
      expect(job.hoursPerWeek, 20);
      expect(job.workSchedule, 'Mon-Fri mornings');
      expect(job.contractStartDate, DateTime.parse('2026-02-01'));
      expect(job.contractEndDate, DateTime.parse('2026-08-01'));
      expect(job.renewable, isTrue);
    });
  });

  group('Job computed state', () {
    Job baseJob({
      String status = 'open',
      DateTime? deadline,
      JobEmploymentType employmentType = JobEmploymentType.fullTime,
      num? salaryMin,
      num? salaryMax,
      bool salaryVisible = true,
      JobApplicationMethod applicationMethod = JobApplicationMethod.external,
    }) {
      return Job(
        id: 'job-1',
        posterId: 'poster-1',
        companyName: 'Acme',
        title: 'Engineer',
        status: status,
        deadline: deadline,
        employmentType: employmentType,
        salaryMin: salaryMin,
        salaryMax: salaryMax,
        salaryVisible: salaryVisible,
        applicationMethod: applicationMethod,
        createdAt: DateTime(2026, 1, 1),
      );
    }

    test('isOpen/isClosed/isFilled reflect status exactly', () {
      expect(baseJob(status: 'open').isOpen, isTrue);
      expect(baseJob(status: 'closed').isClosed, isTrue);
      expect(baseJob(status: 'filled').isFilled, isTrue);
    });

    test('deadlinePassed is true only once the deadline is in the past', () {
      expect(baseJob(deadline: DateTime.now().add(const Duration(days: 1))).deadlinePassed, isFalse);
      expect(baseJob(deadline: DateTime.now().subtract(const Duration(days: 1))).deadlinePassed, isTrue);
      expect(baseJob().deadlinePassed, isFalse);
    });

    test('hasCompensationInfo is false when salary is hidden, even if set', () {
      final job = baseJob(salaryMin: 1000, salaryMax: 2000, salaryVisible: false);
      expect(job.hasCompensationInfo, isFalse);
    });

    test('isInternship reflects employment type', () {
      expect(baseJob(employmentType: JobEmploymentType.internship).isInternship, isTrue);
      expect(baseJob(employmentType: JobEmploymentType.fullTime).isInternship, isFalse);
    });

    test('isInternalApplication reflects application method', () {
      expect(baseJob(applicationMethod: JobApplicationMethod.communeo).isInternalApplication, isTrue);
      expect(baseJob(applicationMethod: JobApplicationMethod.external).isInternalApplication, isFalse);
    });
  });
}
