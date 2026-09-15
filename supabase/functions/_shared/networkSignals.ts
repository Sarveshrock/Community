// Gathers cross-entity ("because you're compatible with X") recommendation
// candidates — communities, events, projects, posts a set of source people
// (the caller's already-computed top Intent matches) are visibly involved
// with. Every query here reads only what RLS already treats as public
// (private communities are explicitly filtered out; events/projects/posts
// have no private-row concept in this schema — see 0052's migration
// comment for the exact RLS this relies on) — this module never uses
// service-role access to reach past what a client could already see.
//
// One batched query per signal (`.in(...)`), never one query per source
// person — keeps this bounded regardless of how many top matches are fed
// in.

import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  overlapRatio,
  recencyScore,
  recommendationScore,
  socialProximityFromCount,
  type RecommendationSignals,
} from "./recommendationScoring.ts";

export interface SourcePerson {
  id: string;
  fullName: string;
  /// 0-1 — the source person's own Intent-match score / 100.
  compatibility: number;
  isDirectConnection: boolean;
}

export type RecommendationType = "community" | "event" | "project" | "post";

export interface RawRecommendation {
  recommendationType: RecommendationType;
  targetId: string;
  title: string;
  imageUrl: string | null;
  score: number;
  reasons: string[];
  /// Grounded, structured facts only — the exact input handed to the AI
  /// rationale generator downstream. Never text the LLM invented.
  factSummary: string;
  signalBreakdown: RecommendationSignals;
}

function bestSource(sources: SourcePerson[], involvedIds: Set<string>): SourcePerson | null {
  const involved = sources.filter((s) => involvedIds.has(s.id));
  if (involved.length === 0) return null;
  return involved.reduce((a, b) => (b.compatibility > a.compatibility ? b : a));
}

function namesList(sources: SourcePerson[], involvedIds: Set<string>): string {
  const names = sources.filter((s) => involvedIds.has(s.id)).map((s) => s.fullName);
  if (names.length === 0) return "";
  if (names.length === 1) return names[0];
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  return `${names[0]} and ${names.length - 1} others`;
}

export async function findCommunityRecommendations(
  db: SupabaseClient,
  sources: SourcePerson[],
  neededSkillNames: string[],
  callerConnectionIds: string[],
): Promise<RawRecommendation[]> {
  const sourceIds = sources.map((s) => s.id);
  if (sourceIds.length === 0) return [];

  const { data: memberRows } = await db
    .from("community_members")
    .select("community_id, profile_id")
    .in("profile_id", sourceIds);
  const communityIds = [...new Set((memberRows ?? []).map((r: any) => r.community_id as string))];
  if (communityIds.length === 0) return [];

  const { data: communities } = await db
    .from("communities")
    .select("id, name, cover_image_url, logo_url, is_private")
    .in("id", communityIds)
    .eq("is_private", false); // never recommend a private community's membership as a signal
  if (!communities || communities.length === 0) return [];
  const publicIds = communities.map((c: any) => c.id as string);

  const { data: topicRows } = await db
    .from("community_topics")
    .select("community_id, skills(name)")
    .in("community_id", publicIds);
  const skillsByCommunity = new Map<string, string[]>();
  for (const row of topicRows ?? []) {
    const cid = (row as any).community_id as string;
    const name = (row as any).skills?.name as string | undefined;
    if (name) skillsByCommunity.set(cid, [...(skillsByCommunity.get(cid) ?? []), name]);
  }

  const { data: connectionMemberRows } = callerConnectionIds.length > 0
    ? await db.from("community_members").select("community_id, profile_id").in("community_id", publicIds).in(
      "profile_id",
      callerConnectionIds,
    )
    : { data: [] as any[] };
  const connectionCountByCommunity = new Map<string, number>();
  for (const row of connectionMemberRows ?? []) {
    const cid = (row as any).community_id as string;
    connectionCountByCommunity.set(cid, (connectionCountByCommunity.get(cid) ?? 0) + 1);
  }

  const involvedByCommunity = new Map<string, Set<string>>();
  for (const row of memberRows ?? []) {
    const cid = (row as any).community_id as string;
    if (!publicIds.includes(cid)) continue;
    const set = involvedByCommunity.get(cid) ?? new Set<string>();
    set.add((row as any).profile_id as string);
    involvedByCommunity.set(cid, set);
  }

  const results: RawRecommendation[] = [];
  for (const community of communities) {
    const involvedIds = involvedByCommunity.get(community.id) ?? new Set<string>();
    const source = bestSource(sources, involvedIds);
    if (!source) continue;

    const intentRelevance = overlapRatio(neededSkillNames, skillsByCommunity.get(community.id) ?? []);
    const connectionCount = connectionCountByCommunity.get(community.id) ?? 0;
    const signals: RecommendationSignals = {
      compatibility: source.compatibility,
      intentRelevance,
      socialProximity: socialProximityFromCount(connectionCount),
      recency: 1, // membership has no natural "freshness" — treated as always-current
      relationshipStrength: source.isDirectConnection ? 1 : 0.5,
    };

    const who = namesList(sources, involvedIds);
    const reasons = [`${who} ${involvedIds.size === 1 ? "is" : "are"} a member.`];
    if (connectionCount > 0) {
      reasons.push(`${connectionCount} more of your connections ${connectionCount === 1 ? "is" : "are"} also a member.`);
    }
    if (intentRelevance > 0) reasons.push("Matches skills your current Intent needs.");

    results.push({
      recommendationType: "community",
      targetId: community.id,
      title: community.name,
      imageUrl: community.cover_image_url ?? community.logo_url ?? null,
      score: recommendationScore(signals),
      reasons,
      factSummary:
        `Community "${community.name}". Members from your matches: ${who || "none"}. ` +
        `${connectionCount} of your connections are also members. ` +
        `Intent-skill overlap: ${Math.round(intentRelevance * 100)}%.`,
      signalBreakdown: signals,
    });
  }
  return results;
}

export async function findEventRecommendations(
  db: SupabaseClient,
  sources: SourcePerson[],
  neededSkillNames: string[],
  callerConnectionIds: string[],
): Promise<RawRecommendation[]> {
  const sourceIds = sources.map((s) => s.id);
  if (sourceIds.length === 0) return [];

  const { data: attendeeRows } = await db
    .from("event_attendees")
    .select("event_id, profile_id")
    .in("profile_id", sourceIds);
  const eventIds = [...new Set((attendeeRows ?? []).map((r: any) => r.event_id as string))];
  if (eventIds.length === 0) return [];

  const { data: events } = await db
    .from("events")
    .select("id, title, cover_image_url, starts_at, status")
    .in("id", eventIds)
    .eq("status", "published")
    .gt("starts_at", new Date().toISOString()); // only ever recommend upcoming events
  if (!events || events.length === 0) return [];
  const upcomingIds = events.map((e: any) => e.id as string);

  const { data: tagRows } = await db.from("event_tags").select("event_id, skills(name)").in("event_id", upcomingIds);
  const skillsByEvent = new Map<string, string[]>();
  for (const row of tagRows ?? []) {
    const eid = (row as any).event_id as string;
    const name = (row as any).skills?.name as string | undefined;
    if (name) skillsByEvent.set(eid, [...(skillsByEvent.get(eid) ?? []), name]);
  }

  const { data: connectionAttendeeRows } = callerConnectionIds.length > 0
    ? await db.from("event_attendees").select("event_id, profile_id").in("event_id", upcomingIds).in(
      "profile_id",
      callerConnectionIds,
    )
    : { data: [] as any[] };
  const connectionCountByEvent = new Map<string, number>();
  for (const row of connectionAttendeeRows ?? []) {
    const eid = (row as any).event_id as string;
    connectionCountByEvent.set(eid, (connectionCountByEvent.get(eid) ?? 0) + 1);
  }

  const involvedByEvent = new Map<string, Set<string>>();
  for (const row of attendeeRows ?? []) {
    const eid = (row as any).event_id as string;
    if (!upcomingIds.includes(eid)) continue;
    const set = involvedByEvent.get(eid) ?? new Set<string>();
    set.add((row as any).profile_id as string);
    involvedByEvent.set(eid, set);
  }

  const results: RawRecommendation[] = [];
  for (const event of events) {
    const involvedIds = involvedByEvent.get(event.id) ?? new Set<string>();
    const source = bestSource(sources, involvedIds);
    if (!source) continue;

    const intentRelevance = overlapRatio(neededSkillNames, skillsByEvent.get(event.id) ?? []);
    const connectionCount = connectionCountByEvent.get(event.id) ?? 0;
    const signals: RecommendationSignals = {
      compatibility: source.compatibility,
      intentRelevance,
      socialProximity: socialProximityFromCount(connectionCount),
      recency: 1,
      relationshipStrength: source.isDirectConnection ? 1 : 0.5,
    };

    const who = namesList(sources, involvedIds);
    const reasons = [`${who} ${involvedIds.size === 1 ? "is" : "are"} attending.`];
    if (connectionCount > 0) {
      reasons.push(`${connectionCount} more of your connections ${connectionCount === 1 ? "is" : "are"} attending too.`);
    }
    if (intentRelevance > 0) reasons.push("Matches skills your current Intent needs.");

    results.push({
      recommendationType: "event",
      targetId: event.id,
      title: event.title,
      imageUrl: event.cover_image_url ?? null,
      score: recommendationScore(signals),
      reasons,
      factSummary:
        `Event "${event.title}" (upcoming). Attendees from your matches: ${who || "none"}. ` +
        `${connectionCount} of your connections are also attending. Intent-skill overlap: ${
          Math.round(intentRelevance * 100)
        }%.`,
      signalBreakdown: signals,
    });
  }
  return results;
}

export async function findProjectRecommendations(
  db: SupabaseClient,
  sources: SourcePerson[],
  neededSkillNames: string[],
  callerConnectionIds: string[],
): Promise<RawRecommendation[]> {
  const sourceIds = sources.map((s) => s.id);
  if (sourceIds.length === 0) return [];

  // "Involved" = owns the project, or has an accepted collaboration interest.
  const [{ data: ownedProjects }, { data: interestRows }] = await Promise.all([
    db.from("projects").select("id, owner_id, status").in("owner_id", sourceIds).eq("status", "open"),
    db.from("project_interests").select("project_id, profile_id").in("profile_id", sourceIds).eq(
      "status",
      "accepted",
    ),
  ]);

  const projectIds = new Set<string>();
  const involvedByProject = new Map<string, Set<string>>();
  for (const p of ownedProjects ?? []) {
    projectIds.add(p.id);
    const set = involvedByProject.get(p.id) ?? new Set<string>();
    set.add(p.owner_id);
    involvedByProject.set(p.id, set);
  }
  for (const row of interestRows ?? []) {
    const pid = (row as any).project_id as string;
    projectIds.add(pid);
    const set = involvedByProject.get(pid) ?? new Set<string>();
    set.add((row as any).profile_id as string);
    involvedByProject.set(pid, set);
  }
  if (projectIds.size === 0) return [];

  const { data: projects } = await db
    .from("projects")
    .select("id, title, status")
    .in("id", [...projectIds])
    .eq("status", "open"); // never recommend a closed/completed project
  if (!projects || projects.length === 0) return [];
  const openIds = projects.map((p: any) => p.id as string);

  const { data: skillRows } = await db.from("project_required_skills").select("project_id, skills(name)").in(
    "project_id",
    openIds,
  );
  const skillsByProject = new Map<string, string[]>();
  for (const row of skillRows ?? []) {
    const pid = (row as any).project_id as string;
    const name = (row as any).skills?.name as string | undefined;
    if (name) skillsByProject.set(pid, [...(skillsByProject.get(pid) ?? []), name]);
  }

  const { data: connectionInterestRows } = callerConnectionIds.length > 0
    ? await db.from("project_interests").select("project_id, profile_id").in("project_id", openIds).in(
      "profile_id",
      callerConnectionIds,
    ).eq("status", "accepted")
    : { data: [] as any[] };
  const connectionCountByProject = new Map<string, number>();
  for (const row of connectionInterestRows ?? []) {
    const pid = (row as any).project_id as string;
    connectionCountByProject.set(pid, (connectionCountByProject.get(pid) ?? 0) + 1);
  }

  const results: RawRecommendation[] = [];
  for (const project of projects) {
    const involvedIds = involvedByProject.get(project.id) ?? new Set<string>();
    const source = bestSource(sources, involvedIds);
    if (!source) continue;

    const intentRelevance = overlapRatio(neededSkillNames, skillsByProject.get(project.id) ?? []);
    const connectionCount = connectionCountByProject.get(project.id) ?? 0;
    const signals: RecommendationSignals = {
      compatibility: source.compatibility,
      intentRelevance,
      socialProximity: socialProximityFromCount(connectionCount),
      recency: 1,
      relationshipStrength: source.isDirectConnection ? 1 : 0.5,
    };

    const who = namesList(sources, involvedIds);
    const reasons = [`${who} ${involvedIds.size === 1 ? "is" : "are"} working on this.`];
    if (intentRelevance > 0) reasons.push("Needs skills that match your current Intent.");

    results.push({
      recommendationType: "project",
      targetId: project.id,
      title: project.title,
      imageUrl: null,
      score: recommendationScore(signals),
      reasons,
      factSummary:
        `Project "${project.title}" (open). Involved from your matches: ${who || "none"}. ` +
        `Intent-skill overlap: ${Math.round(intentRelevance * 100)}%.`,
      signalBreakdown: signals,
    });
  }
  return results;
}

export async function findPostRecommendations(
  db: SupabaseClient,
  sources: SourcePerson[],
  neededSkillNames: string[],
  callerConnectionIds: string[],
): Promise<RawRecommendation[]> {
  const sourceIds = sources.map((s) => s.id);
  if (sourceIds.length === 0) return [];

  const since = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000).toISOString(); // only recent posts
  const [{ data: authoredPosts }, { data: likeRows }] = await Promise.all([
    db.from("posts").select("id, content, category, author_id, created_at").in("author_id", sourceIds).is(
      "deleted_at",
      null,
    ).gte("created_at", since),
    db.from("post_likes").select("post_id, profile_id").in("profile_id", sourceIds),
  ]);

  const postIds = new Set<string>((authoredPosts ?? []).map((p: any) => p.id as string));
  const likedPostIds = [...new Set((likeRows ?? []).map((r: any) => r.post_id as string))];
  for (const id of likedPostIds) postIds.add(id);
  if (postIds.size === 0) return [];

  const { data: posts } = await db
    .from("posts")
    .select("id, content, category, author_id, created_at")
    .in("id", [...postIds])
    .is("deleted_at", null)
    .gte("created_at", since);
  if (!posts || posts.length === 0) return [];

  const involvedByPost = new Map<string, Set<string>>();
  for (const p of authoredPosts ?? []) {
    const set = involvedByPost.get(p.id) ?? new Set<string>();
    set.add(p.author_id);
    involvedByPost.set(p.id, set);
  }
  for (const row of likeRows ?? []) {
    const pid = (row as any).post_id as string;
    const set = involvedByPost.get(pid) ?? new Set<string>();
    set.add((row as any).profile_id as string);
    involvedByPost.set(pid, set);
  }

  const postIdList = posts.map((p: any) => p.id as string);
  const { data: connectionLikeRows } = callerConnectionIds.length > 0
    ? await db.from("post_likes").select("post_id, profile_id").in("post_id", postIdList).in(
      "profile_id",
      callerConnectionIds,
    )
    : { data: [] as any[] };
  const connectionCountByPost = new Map<string, number>();
  for (const row of connectionLikeRows ?? []) {
    const pid = (row as any).post_id as string;
    connectionCountByPost.set(pid, (connectionCountByPost.get(pid) ?? 0) + 1);
  }

  const results: RawRecommendation[] = [];
  for (const post of posts) {
    const involvedIds = involvedByPost.get(post.id) ?? new Set<string>();
    const source = bestSource(sources, involvedIds);
    if (!source) continue;

    // Loose relevance: does the post's free-text category name appear among
    // the Intent's needed skills (or vice versa)? Weak but grounded — never
    // a fabricated "this post relates to your Intent" claim.
    const category = (post.category as string | null) ?? "";
    const intentRelevance = category && neededSkillNames.some((s) => category.toLowerCase().includes(s.toLowerCase()))
      ? 1
      : 0;
    const connectionCount = connectionCountByPost.get(post.id) ?? 0;
    const signals: RecommendationSignals = {
      compatibility: source.compatibility,
      intentRelevance,
      socialProximity: socialProximityFromCount(connectionCount),
      recency: recencyScore(post.created_at),
      relationshipStrength: source.isDirectConnection ? 1 : 0.5,
    };

    const authoredBy = involvedByPost.get(post.id)?.has(post.author_id) && sources.some((s) => s.id === post.author_id)
      ? sources.find((s) => s.id === post.author_id)?.fullName
      : null;
    const likerCount = involvedIds.size - (authoredBy ? 1 : 0) + connectionCount;
    const reasons: string[] = [];
    if (authoredBy) reasons.push(`${authoredBy} posted this.`);
    if (likerCount > 0) reasons.push(`${likerCount} ${likerCount === 1 ? "person" : "people"} in your network interacted with this.`);
    if (reasons.length === 0) reasons.push("Someone in your matches interacted with this.");

    results.push({
      recommendationType: "post",
      targetId: post.id,
      title: (post.content as string).slice(0, 80),
      imageUrl: null,
      score: recommendationScore(signals),
      reasons,
      factSummary:
        `Post (category: ${category || "none"}): "${(post.content as string).slice(0, 140)}". ` +
        `${authoredBy ? `Authored by ${authoredBy}.` : ""} ${connectionCount} of your connections engaged with it.`,
      signalBreakdown: signals,
    });
  }
  return results;
}
