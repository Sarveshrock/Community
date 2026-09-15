import 'entities/hackathon.dart';

/// A simple, deterministic compatibility score between a viewer's skills
/// and a team's needs — spec's "simple compatibility score", not the
/// unwired `ai-match-team` edge function (kept unused deliberately: no new
/// AI/API dependency for this task). Pure function, no I/O, so it's cheap
/// to compute on every Team Card render.
class TeamMatchResult {
  const TeamMatchResult({required this.percent, required this.matchedSkills, required this.missingSkills});

  /// 0-100.
  final int percent;
  final List<String> matchedSkills;
  final List<String> missingSkills;

  bool get hasAnyMatch => matchedSkills.isNotEmpty;
}

/// Compares [mySkillNames] (case-insensitive) against everything the team
/// is looking for — its general `requiredSkillNames` plus every structured
/// role's own skill list — deduplicated. Returns null when the team asks
/// for no skills at all (nothing to score against).
TeamMatchResult? computeTeamMatchScore({
  required TeamRequirement team,
  required List<String> mySkillNames,
}) {
  final wanted = <String>{
    ...team.requiredSkillNames,
    for (final role in team.roleRequirements) ...role.skillNames,
  };
  if (wanted.isEmpty) return null;

  final mine = mySkillNames.map((s) => s.toLowerCase()).toSet();
  final matched = wanted.where((s) => mine.contains(s.toLowerCase())).toList();
  final missing = wanted.where((s) => !mine.contains(s.toLowerCase())).toList();

  final percent = ((matched.length / wanted.length) * 100).round();
  return TeamMatchResult(percent: percent, matchedSkills: matched, missingSkills: missing);
}
