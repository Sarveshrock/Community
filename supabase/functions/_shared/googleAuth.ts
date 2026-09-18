// Mints a short-lived Google OAuth2 access token from a Firebase service
// account (RS256-signed JWT bearer flow, RFC 7523) — used by
// send-notification for the FCM HTTP v1 API. The old `FCM_SERVER_KEY` /
// `fcm.googleapis.com/fcm/send` legacy API this replaced was shut down by
// Google in June 2024 and no longer delivers anything; v1 requires an
// OAuth2 bearer token minted from a service account instead of a static key.

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let cachedToken: { token: string; expiresAt: number } | null = null;

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    der.buffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/// Returns a valid FCM-scoped access token, reusing the cached one until it
/// is within 60s of expiring rather than minting a fresh one per call —
/// this function runs on every push send, so that would mean one RSA
/// signature and one network round-trip to Google per notification.
export async function getFcmAccessToken(
  serviceAccountJson: string,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && cachedToken.expiresAt - 60 > now) return cachedToken.token;

  const account: ServiceAccount = JSON.parse(serviceAccountJson);
  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };
  const unsigned = `${base64url(JSON.stringify(header))}.${
    base64url(JSON.stringify(claims))
  }`;
  const key = await importPrivateKey(account.private_key);
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`Google OAuth token exchange failed: ${await res.text()}`);
  }
  const json = await res.json();
  cachedToken = { token: json.access_token, expiresAt: now + json.expires_in };
  return cachedToken.token;
}

export function fcmProjectId(serviceAccountJson: string): string {
  return (JSON.parse(serviceAccountJson) as ServiceAccount).project_id;
}
