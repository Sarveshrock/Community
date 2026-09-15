// Small shared helper so any AI-provider call (or other best-effort async
// step) can be bounded without blocking a response — used by both
// ai-match-intent and get-network-recommendations rather than each
// duplicating its own copy.

export async function withTimeout<T>(promise: Promise<T>, ms: number, fallback: T): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((resolve) => setTimeout(() => resolve(fallback), ms)),
  ]);
}
