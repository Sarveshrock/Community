// Cheap, rule-based technology-relevance scoring (spec section 5 & 12) —
// runs on every item before anything touches the AI provider. Category
// keyword hits both score AND categorize/tag an item in one pass, so
// filtering and categorization never disagree with each other.

import { RawNewsItem } from "../utils/types.ts";
import { clampScore } from "../utils/normalization.ts";

const CATEGORY_KEYWORDS: Record<string, string[]> = {
  "AI": ["artificial intelligence", "neural network", "deep learning", "generative ai", "chatbot", "ai model", "ai agent"],
  "Machine Learning": ["machine learning", "ml model", "training data", "gradient descent", "supervised learning", "transformer model"],
  "LLM": ["llm", "large language model", "gpt-", "gpt4", "gpt-4", "chatgpt", "claude ai", "gemini ai", "prompt engineering", "fine-tun"],
  "Research": ["arxiv", "research paper", "researchers found", "study shows", "novel approach", "preprint"],
  "GitHub": ["github", "repository", " repo ", "pull request", "open source project", "github.com"],
  "Open Source": ["open source", "open-source", " oss ", "apache license", "mit license", "foss", "open-sourced"],
  "Startups": ["startup", "funding round", "seed round", "series a", "series b", "series c", "raises $", "raises a", " raises ", "y combinator", "venture capital", "vc funding", "in funding", "in a round", "led by", "valuation", "backed by", "unicorn"],
  "Programming": ["programming", "coding", "software developer", "software engineer", "codebase"],
  "Web Development": ["react.js", " react ", "vue.js", "angular", "next.js", "web framework", "css framework", "frontend framework", "web development"],
  "Mobile Development": ["ios app", "android app", "flutter", "react native", "swiftui", "kotlin", "mobile app", "app store", "google play"],
  "Cloud": ["aws ", "amazon web services", "azure ", "google cloud", "cloud native", "serverless", "cloud infrastructure", "cloud computing"],
  "DevOps": ["devops", "ci/cd", "docker", "kubernetes", "terraform", "infrastructure as code", "deployment pipeline", "container orchestration"],
  "Cybersecurity": ["vulnerability", "security flaw", "exploit", "cve-", "data breach", "ransomware", "zero-day", "malware", "cybersecurity", "phishing"],
  "Databases": ["database", "postgresql", "postgres", "mysql", " sql ", "nosql", "mongodb", "redis", "vector database", "sqlite"],
  "Backend": ["backend", "api design", "microservices", "server-side", "rest api", "graphql"],
  "Frontend": ["frontend", "ui framework", "user interface design", "css framework"],
  "Developer Tools": ["developer tool", " ide ", "cli tool", " sdk ", "dev tool", "debugger", "linter", "build tool"],
  "Frameworks": ["framework release", "new framework", "library release"],
  "Programming Languages": ["programming language", "rust language", "golang", " go 1.", "python 3.", "typescript", "javascript engine", "language specification"],
  "Robotics": ["robot", "robotics", "autonomous vehicle", "self-driving", "humanoid robot", "drone"],
  "Blockchain/Web3": ["blockchain", "web3", "cryptocurrency", "ethereum", "smart contract", " nft ", "defi"],
  "Hardware": ["semiconductor", "processor chip", " gpu ", " cpu ", "silicon chip", "nvidia", "chip design", "quantum comput"],
  "Operating Systems": ["operating system", "linux kernel", "windows update", "macos ", "os release"],
  "Infrastructure": ["data center", "distributed system", "system scalability", "developer infrastructure"],
};

// Off-topic domains the feed must not become (spec section: "should NOT
// become a generic news feed"). A hit here strongly suppresses the score
// unless the item also carries strong tech signal.
const NEGATIVE_KEYWORDS = [
  "celebrity", "kardashian", "box office", "movie review", "album release", "grammy", "academy award",
  "football match", "basketball game", "soccer match", "olympics", "world cup", " nba ", " nfl ", "premier league",
  "senator", "congress votes", "president trump", "president biden", "prime minister", "general election",
  "royal family", "celebrity wedding", "celebrity divorce", "diet plan", "recipe for", "horoscope",
  "stock market rally", "dow jones", "s&p 500", "nasdaq closes", "interest rate hike", "federal reserve",
  "inflation report", "housing market", "unemployment rate", "consumer spending",
];

/// Baseline score by source type. GitHub/research items are tech-scoped by
/// construction (nothing off-topic can come from the GitHub search API or
/// arXiv), so they start high. "news" here means the curated tech-outlet
/// RSS feeds (TechCrunch/The Verge/Ars Technica/VentureBeat) — their whole
/// beat is the tech industry, so a "generic business/politics" story is the
/// rare exception rather than the norm; they start moderate rather than
/// low, with the negative-keyword list still catching the exceptions.
/// "social" (X) has no such editorial scoping and starts low.
const SOURCE_TYPE_BASE: Record<string, number> = {
  github: 55,
  research: 55,
  startup: 35,
  community: 30,
  news: 35,
  social: 15,
};

export interface RelevanceResult {
  score: number;
  category: string;
  tags: string[];
}

export function scoreRelevance(item: RawNewsItem): RelevanceResult {
  const text = ` ${item.title} ${item.description ?? ""} `.toLowerCase();

  const matched: { category: string; hits: number }[] = [];
  for (const [category, keywords] of Object.entries(CATEGORY_KEYWORDS)) {
    let hits = 0;
    for (const kw of keywords) if (text.includes(kw)) hits++;
    if (hits > 0) matched.push({ category, hits });
  }
  matched.sort((a, b) => b.hits - a.hits);

  const base = SOURCE_TYPE_BASE[item.source_type] ?? 15;
  const keywordBoost = Math.min(
    matched.reduce((sum, m) => sum + m.hits, 0) * 8,
    45,
  );

  let negativeHits = 0;
  for (const kw of NEGATIVE_KEYWORDS) if (text.includes(kw)) negativeHits++;
  const negativePenalty = negativeHits * 35;

  const score = clampScore(base + keywordBoost - negativePenalty);

  const fallbackCategory = item.source_type === "github" ? "GitHub" : item.source_type === "research" ? "Research" : "Other Tech";
  const category = matched[0]?.category ?? fallbackCategory;
  const tags = Array.from(new Set([...(item.tags ?? []), ...matched.slice(0, 3).map((m) => m.category)]));

  return { score, category, tags };
}
