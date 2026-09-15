// AI provider abstraction (spec section 78).
// Application logic must depend only on this interface, never directly on a
// specific vendor SDK, so the provider can be swapped via env var alone.

export interface AiProvider {
  generateText(prompt: string, maxTokens?: number): Promise<string>;
  generateEmbedding(text: string): Promise<number[] | null>;
  rankCandidates(
    query: string,
    candidates: { id: string; text: string }[],
  ): Promise<{ id: string; score: number }[]>;
  summarize(text: string): Promise<string>;
}

class AnthropicProvider implements AiProvider {
  private apiKey: string;
  private model: string;

  constructor(apiKey: string, model = "claude-sonnet-5") {
    this.apiKey = apiKey;
    this.model = model;
  }

  async generateText(prompt: string, maxTokens = 512): Promise<string> {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": this.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: this.model,
        max_tokens: maxTokens,
        messages: [{ role: "user", content: prompt }],
      }),
    });
    if (!res.ok) {
      throw new Error(`AI provider error: ${res.status} ${await res.text()}`);
    }
    const json = await res.json();
    return json.content?.[0]?.text ?? "";
  }

  async generateEmbedding(_text: string): Promise<number[] | null> {
    // No first-party embeddings endpoint wired up; return null so callers
    // fall back to deterministic (non-semantic) scoring.
    return null;
  }

  async rankCandidates(
    query: string,
    candidates: { id: string; text: string }[],
  ): Promise<{ id: string; score: number }[]> {
    if (candidates.length === 0) return [];
    const prompt =
      `Given the query: "${query}"\n\nRank these candidates by relevance from 0-100. ` +
      `Respond ONLY with JSON array like [{"id":"...","score":85}].\n\n` +
      candidates.map((c) => `id=${c.id}: ${c.text}`).join("\n");
    const text = await this.generateText(prompt, 1024);
    try {
      return JSON.parse(text);
    } catch {
      return candidates.map((c) => ({ id: c.id, score: 50 }));
    }
  }

  async summarize(text: string): Promise<string> {
    return this.generateText(
      `Summarize the following in 2-3 concise sentences for a developer audience:\n\n${text}`,
      300,
    );
  }
}

/// Strips a markdown code fence (```json ... ```) if present — Gemini often
/// wraps JSON output in one even when told to respond with JSON only.
export function stripCodeFence(text: string): string {
  const trimmed = text.trim();
  const match = trimmed.match(/^```(?:json)?\s*([\s\S]*?)\s*```$/i);
  return match ? match[1] : trimmed;
}

class GeminiProvider implements AiProvider {
  private apiKey: string;
  private model: string;

  constructor(apiKey: string, model = "gemini-flash-latest") {
    this.apiKey = apiKey;
    this.model = model;
  }

  async generateText(prompt: string, maxTokens = 512): Promise<string> {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${this.model}:generateContent?key=${this.apiKey}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: { maxOutputTokens: maxTokens },
        }),
      },
    );
    if (!res.ok) {
      throw new Error(`AI provider error: ${res.status} ${await res.text()}`);
    }
    const json = await res.json();
    return json.candidates?.[0]?.content?.parts?.[0]?.text ?? "";
  }

  async generateEmbedding(_text: string): Promise<number[] | null> {
    // Gemini does support embeddings (models/text-embedding-004 via
    // :embedContent) but nothing in this app consumes embeddings yet —
    // stays a no-op like the other providers until something needs it.
    return null;
  }

  async rankCandidates(
    query: string,
    candidates: { id: string; text: string }[],
  ): Promise<{ id: string; score: number }[]> {
    if (candidates.length === 0) return [];
    const prompt =
      `Given the query: "${query}"\n\nRank these candidates by relevance from 0-100. ` +
      `Respond ONLY with JSON array like [{"id":"...","score":85}].\n\n` +
      candidates.map((c) => `id=${c.id}: ${c.text}`).join("\n");
    const text = await this.generateText(prompt, 1024);
    try {
      return JSON.parse(stripCodeFence(text));
    } catch {
      return candidates.map((c) => ({ id: c.id, score: 50 }));
    }
  }

  async summarize(text: string): Promise<string> {
    return this.generateText(
      `Summarize the following in 2-3 concise sentences for a developer audience:\n\n${text}`,
      300,
    );
  }
}

class NoopProvider implements AiProvider {
  async generateText(): Promise<string> {
    return "";
  }
  async generateEmbedding(): Promise<number[] | null> {
    return null;
  }
  async rankCandidates(
    _query: string,
    candidates: { id: string; text: string }[],
  ): Promise<{ id: string; score: number }[]> {
    return candidates.map((c) => ({ id: c.id, score: 50 }));
  }
  async summarize(text: string): Promise<string> {
    return text.slice(0, 240);
  }
}

const CONFIGURABLE_PROVIDERS = new Set(["anthropic", "gemini"]);

// Provider selection is entirely server-side (env var), never client input.
export function getAiProvider(): AiProvider {
  const providerName = Deno.env.get("AI_PROVIDER") ?? "none";
  const apiKey = Deno.env.get("AI_PROVIDER_API_KEY");
  const model = Deno.env.get("AI_MODEL") ?? undefined;

  if (apiKey && providerName === "gemini") {
    return new GeminiProvider(apiKey, model);
  }
  if (apiKey && providerName === "anthropic") {
    return new AnthropicProvider(apiKey, model);
  }
  return new NoopProvider();
}

/// Whether a real (non-Noop) provider is configured — callers use this to
/// decide whether a semantic re-ranking pass is worth the extra latency/cost
/// on top of the deterministic score (spec section 43's "Optional Semantic
/// Ranking" pipeline step).
export function isAiConfigured(): boolean {
  const providerName = Deno.env.get("AI_PROVIDER") ?? "none";
  return CONFIGURABLE_PROVIDERS.has(providerName) && !!Deno.env.get("AI_PROVIDER_API_KEY");
}

/// Tags stored `ai_recommendations.model_version` rows so it's visible
/// after the fact whether a given recommendation got a semantic pass.
export function matchModelVersion(): string {
  return isAiConfigured() ? "semantic-v1" : "deterministic-v1";
}
