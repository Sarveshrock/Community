// Locks down resolveJobActionState — the single source of truth for what
// the job detail page's primary CTA shows, mirroring
// event_action_state_test (events feature)'s precedent for this kind of
// pure state-resolution function.

import 'package:flutter_test/flutter_test.dart';
import 'package:community_app/features/jobs/domain/entities/job.dart';
import 'package:community_app/features/jobs/domain/job_action_state.dart';

Job _job({
  String posterId = 'poster-1',
  String status = 'open',
  DateTime? deadline,
  JobApplicationMethod applicationMethod = JobApplicationMethod.communeo,
}) {
  return Job(
    id: 'job-1',
    posterId: posterId,
    companyName: 'Acme',
    title: 'Engineer',
    status: status,
    deadline: deadline,
    applicationMethod: applicationMethod,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('signed-out viewer sees none', () {
    expect(resolveJobActionState(job: _job(), myId: null, hasApplied: false), JobActionState.none);
  });

  test('the poster sees owner, never an apply CTA', () {
    expect(
      resolveJobActionState(job: _job(posterId: 'me'), myId: 'me', hasApplied: false),
      JobActionState.owner,
    );
  });

  test('an internal application already submitted shows alreadyApplied', () {
    expect(
      resolveJobActionState(job: _job(), myId: 'me', hasApplied: true),
      JobActionState.alreadyApplied,
    );
  });

  test('a closed job shows closed, even if not yet applied', () {
    expect(
      resolveJobActionState(job: _job(status: 'closed'), myId: 'me', hasApplied: false),
      JobActionState.closed,
    );
  });

  test('a filled job shows filled', () {
    expect(
      resolveJobActionState(job: _job(status: 'filled'), myId: 'me', hasApplied: false),
      JobActionState.filled,
    );
  });

  test('a passed deadline shows deadlinePassed, even on an open job', () {
    final job = _job(deadline: DateTime.now().subtract(const Duration(days: 1)));
    expect(
      resolveJobActionState(job: job, myId: 'me', hasApplied: false),
      JobActionState.deadlinePassed,
    );
  });

  test('an open internal-application job with no deadline shows applyInternal', () {
    expect(
      resolveJobActionState(job: _job(), myId: 'me', hasApplied: false),
      JobActionState.applyInternal,
    );
  });

  test('an open external-application job shows applyExternal, never writes an application', () {
    expect(
      resolveJobActionState(
        job: _job(applicationMethod: JobApplicationMethod.external),
        myId: 'me',
        hasApplied: false,
      ),
      JobActionState.applyExternal,
    );
  });

  test('external jobs ignore hasApplied — there is no internal application to have submitted', () {
    expect(
      resolveJobActionState(
        job: _job(applicationMethod: JobApplicationMethod.external),
        myId: 'me',
        hasApplied: true,
      ),
      JobActionState.applyExternal,
    );
  });

  test('applyInternal and applyExternal are actionable; every terminal/blocked state is not', () {
    expect(JobActionState.applyInternal.isActionable, isTrue);
    expect(JobActionState.applyExternal.isActionable, isTrue);
    for (final state in [
      JobActionState.none,
      JobActionState.owner,
      JobActionState.alreadyApplied,
      JobActionState.closed,
      JobActionState.filled,
      JobActionState.deadlinePassed,
    ]) {
      expect(state.isActionable, isFalse, reason: '$state should not be actionable');
    }
  });
}
