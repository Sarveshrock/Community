// Structured, secret-safe logging for the pipeline (spec section 21).
// Every call here goes straight to console.log/warn/error, which lands in
// Supabase's Edge Function logs — never store logs in the database, and
// never pass a value that could be an API key/token through here.

export function logStep(tag: string, message: string): void {
  console.log(`[${tag}] ${message}`);
}

export function logWarn(tag: string, message: string): void {
  console.warn(`[${tag}] ${message}`);
}

export function logSourceResult(source: string, count: number, error?: unknown): void {
  if (error) {
    // Deliberately logs only the error message, never headers/request
    // details that might carry a key.
    console.warn(`[${source}] failed: ${(error as Error).message ?? String(error)}`);
    return;
  }
  console.log(`[${source}] fetched ${count} items`);
}
