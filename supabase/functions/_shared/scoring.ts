// Deterministic scoring engine (spec section 43).
// Weights come from ai_scoring_weights so they stay configurable server-side
// instead of being hardcoded into the Flutter client.

export interface ScoringWeights {
  skills_weight: number;
  interests_weight: number;
  goals_weight: number;
  experience_weight: number;
  availability_weight: number;
  location_weight: number;
  activity_weight: number;
}

export interface ScoreComponents {
  skills: number;
  interests: number;
  goals: number;
  experience: number;
  availability: number;
  location: number;
  activity: number;
}

export function jaccard(a: string[], b: string[]): number {
  const setA = new Set(a.map((x) => x.toLowerCase()));
  const setB = new Set(b.map((x) => x.toLowerCase()));
  if (setA.size === 0 || setB.size === 0) return 0;
  let intersection = 0;
  for (const x of setA) if (setB.has(x)) intersection++;
  const union = new Set([...setA, ...setB]).size;
  return union === 0 ? 0 : intersection / union;
}

export function weightedScore(
  components: ScoreComponents,
  weights: ScoringWeights,
): number {
  const total =
    components.skills * weights.skills_weight +
    components.interests * weights.interests_weight +
    components.goals * weights.goals_weight +
    components.experience * weights.experience_weight +
    components.availability * weights.availability_weight +
    components.location * weights.location_weight +
    components.activity * weights.activity_weight;
  return Math.round(Math.min(100, Math.max(0, total * 100)) * 100) / 100;
}

export function reasonFromComponents(components: ScoreComponents): string {
  const entries = Object.entries(components) as [string, number][];
  entries.sort((a, b) => b[1] - a[1]);
  const top = entries.filter(([, v]) => v > 0).slice(0, 2);
  if (top.length === 0) return "Broad match based on your profile.";
  const labels: Record<string, string> = {
    skills: "shared skills",
    interests: "shared interests",
    goals: "aligned goals",
    experience: "comparable experience",
    availability: "compatible availability",
    location: "nearby location",
    activity: "recent activity",
  };
  return `Recommended for ${top.map(([k]) => labels[k]).join(" and ")}.`;
}
