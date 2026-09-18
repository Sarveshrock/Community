// send-notification
// Server-triggered notification writer (spec section 47). Called from other
// Edge Functions or database webhooks with the service role — never
// callable with an arbitrary client-chosen recipient over the anon key,
// since the caller must present the CRON/SERVICE secret.

import { handleOptions, jsonResponse } from "../_shared/cors.ts";
import { fcmProjectId, getFcmAccessToken } from "../_shared/googleAuth.ts";
import { serviceClient } from "../_shared/supabaseClient.ts";

interface NotifyPayload {
  profile_id: string;
  type: string;
  title: string;
  body?: string;
  data?: Record<string, unknown>;
}

/// Best-effort FCM push delivery (HTTP v1 API) to every device token on file
/// for the recipient (spec section 47). FCM covers both Android and iOS
/// (bridging to APNs) once the app registers a token via
/// `notifications/registerDeviceToken`. Entirely optional: skipped silently
/// unless `FCM_SERVICE_ACCOUNT_JSON` is set, and a delivery failure never
/// fails the in-app notification write above it.
async function deliverPush(
  db: ReturnType<typeof serviceClient>,
  payload: NotifyPayload,
): Promise<
  { attempted: number; sent: number; staleRemoved: number } | {
    skipped: string;
  }
> {
  const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    return { skipped: "FCM_SERVICE_ACCOUNT_JSON not configured" };
  }

  const { data: tokens } = await db
    .from("device_tokens")
    .select("token")
    .eq("profile_id", payload.profile_id);
  if (!tokens || tokens.length === 0) return { attempted: 0, sent: 0, staleRemoved: 0 };

  let accessToken: string;
  let projectId: string;
  try {
    accessToken = await getFcmAccessToken(serviceAccountJson);
    projectId = fcmProjectId(serviceAccountJson);
  } catch (err) {
    return {
      skipped: `could not mint FCM access token: ${(err as Error).message}`,
    };
  }

  // FCM v1's `data` payload only accepts string values — every other field
  // here (type/data) gets coerced, same as the client reads them as JSON
  // either way. A null/undefined field (e.g. `notify_new_message`'s
  // team_requirement_id on a direct-message conversation) is omitted
  // rather than sent as the literal string "null", so client-side `!= null`
  // checks on it still mean what they say.
  const dataPayload: Record<string, string> = { type: payload.type };
  for (const [k, v] of Object.entries(payload.data ?? {})) {
    if (v === null || v === undefined) continue;
    dataPayload[k] = typeof v === "string" ? v : JSON.stringify(v);
  }

  let sent = 0;
  const staleTokens: string[] = [];
  await Promise.all(
    tokens.map(async (t: { token: string }) => {
      try {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: "POST",
            headers: {
              "content-type": "application/json",
              authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: t.token,
                notification: {
                  title: payload.title,
                  body: payload.body ?? "",
                },
                data: dataPayload,
              },
            }),
          },
        );
        if (res.ok) {
          sent += 1;
          return;
        }
        // A token FCM will never deliver to again (app uninstalled, token
        // rotated, etc.) — remove it so future sends don't keep retrying it.
        const body = await res.text();
        if (
          res.status === 404 || body.includes("UNREGISTERED") ||
          body.includes("INVALID_ARGUMENT")
        ) {
          staleTokens.push(t.token);
        }
      } catch {
        // Best-effort — one bad/expired token must not block the others.
      }
    }),
  );

  if (staleTokens.length > 0) {
    await db.from("device_tokens").delete().in("token", staleTokens);
  }

  return { attempted: tokens.length, sent, staleRemoved: staleTokens.length };
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
