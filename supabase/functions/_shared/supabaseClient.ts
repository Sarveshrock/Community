import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Service-role client: full-privilege server-side access. NEVER expose this
// key or this client to the Flutter app. Used only inside Edge Functions.
export function serviceClient() {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

// User-scoped client: forwards the caller's JWT so RLS still applies.
// Use this whenever the function should act "as" the calling user rather
// than with elevated privileges.
export function userClient(req: Request) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function requireUserId(req: Request): Promise<string> {
  const client = userClient(req);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    throw new Error("not authenticated");
  }
  return data.user.id;
}
