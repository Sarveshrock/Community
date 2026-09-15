// send-notification
// Server-triggered notification writer (spec section 47). Called from other
// Edge Functions or database webhooks with the service role — never
// callable with an arbitrary client-chosen recipient over the anon key,
// since the caller must present the CRON/SERVICE secret.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabaseClient.ts";

interface NotifyPayload {
  profile_id: string;
  type: string;
  title: string;
  body?: string;
  data?: Record<string, unknown>;
}

/// Best-effort FCM push delivery to every device token on file for the
/// recipient (spec section 47). FCM covers both Android and iOS (bridging to
/// APNs) once the app registers a token via
/// `notifications/registerDeviceToken`. Entirely optional: skipped silently
/// unless `FCM_SERVER_KEY` is set, and a delivery failure never fails the
/// in-app notification write above it.
async function deliverPush(
  db: ReturnType<typeof serviceClient>,
  payload: NotifyPayload,
): Promise<{ attempted: number; sent: number } | { skipped: string }> {
  const serverKey = Deno.env.get("FCM_SERVER_KEY");
  if (!serverKey) return { skipped: "FCM_SERVER_KEY not configured" };

  const { data: tokens } = await db
    .from("device_tokens")
    .select("token")
    .eq("profile_id", payload.profile_id);
  if (!tokens || tokens.length === 0) return { attempted: 0, sent: 0 };

  let sent = 0;
  await Promise.all(
    tokens.map(async (t: { token: string }) => {
      try {
        const res = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            authorization: `key=${serverKey}`,
          },
          body: JSON.stringify({
            to: t.token,
            notification: { title: payload.title, body: payload.body ?? "" },
            data: payload.data ?? {},
          }),
        });
        if (res.ok) sent += 1;
      } catch {
        // Best-effort — one bad/expired token must not block the others.
      }
    }),
  );
  return { attempted: tokens.length, sent };
}

const PREFERENCE_KEY_BY_TYPE: Record<string, string> = {
  message: "messages",
  connection_request: "connections",
  connection_accepted: "connections",
  job: "jobs",
  hackathon: "hackathons",
  team_invitation: "hackathons",
  project_interest: "projects",
  mentor_request: "mentorship",
  local_connection_request: "local_requests",
  meetup_suggestion: "meetups",
  meetup_accepted: "meetups",
  news: "news",
  community_event: "community_events",
};

Deno.serve(async (req) => {
  const preflight = handleOptions(req);
  if (preflight) return preflight;

  const serviceSecret = req.headers.get("x-service-secret");
  if (serviceSecret !== Deno.env.get("SERVICE_FUNCTION_SECRET")) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  try {
    const payload: NotifyPayload = await req.json();
    if (!payload.profile_id || !payload.type || !payload.title) {
      throw new Error("profile_id, type and title are required");
    }

    const db = serviceClient();
    const prefKey = PREFERENCE_KEY_BY_TYPE[payload.type];
    if (prefKey) {
      const { data: prefs } = await db
        .from("notification_preferences")
        .select(prefKey)
        .eq("profile_id", payload.profile_id)
        .single();
      if (prefs && (prefs as any)[prefKey] === false) {
        return jsonResponse({ skipped: true, reason: "muted by preference" });
      }
    }

    const { error } = await db.from("notifications").insert({
      profile_id: payload.profile_id,
      type: payload.type,
      title: payload.title,
      body: payload.body ?? null,
      data: payload.data ?? {},
    });
    if (error) throw error;

    const pushResult = await deliverPush(db, payload);

    return jsonResponse({ sent: true, push: pushResult });
  } catch (err) {
    return jsonResponse({ error: (err as Error).message }, 400);
  }
});
