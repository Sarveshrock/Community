import 'entities/job.dart';

/// What the job detail page's primary CTA should show for the current
/// viewer — purely a function of job + viewer state, mirroring
/// `resolveEventActionState` (events feature) / `resolveTeamCardAction`
/// (hackathons feature)'s precedent.
enum JobActionState {
  /// Not signed in — nothing actionable.
  none,

  /// The viewer posted this job: organizer controls instead of an apply CTA.
  owner,

  /// Already has a submitted application (internal-application jobs only —
  /// external applications aren't tracked, so this can't apply there).
  alreadyApplied,

  closed,
  filled,
  deadlinePassed,

  /// Apply directly on Communeo.
  applyInternal,

  /// Apply on the poster's external site/ATS.
  applyExternal,
}

JobActionState resolveJobActionState({
  required Job job,
  required String? myId,
  required bool hasApplied,
}) {
  if (myId == null) return JobActionState.none;
  if (job.posterId == myId) return JobActionState.owner;
  if (job.isInternalApplication && hasApplied) return JobActionState.alreadyApplied;
  if (job.isClosed) return JobActionState.closed;
  if (job.isFilled) return JobActionState.filled;
  if (job.deadlinePassed) return JobActionState.deadlinePassed;
  return job.isInternalApplication ? JobActionState.applyInternal : JobActionState.applyExternal;
}

extension JobActionStateLabel on JobActionState {
  String get label => switch (this) {
        JobActionState.none => '',
        JobActionState.owner => '',
        JobActionState.alreadyApplied => 'Application submitted',
        JobActionState.closed => 'Applications closed',
        JobActionState.filled => 'Position filled',
        JobActionState.deadlinePassed => 'Application deadline passed',
        JobActionState.applyInternal => 'Apply now',
        JobActionState.applyExternal => 'Apply externally',
      };

  bool get isActionable =>
      this == JobActionState.applyInternal || this == JobActionState.applyExternal;
}
