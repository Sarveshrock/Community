# Communeo — Community App (Flutter + Supabase)

A community platform for students, developers, job seekers, and founders to
find the right people, teams, opportunities, and information — combining
professional networking, hackathon team formation, project collaboration,
jobs, startup opportunities, mentorship, a privacy-safe 1-to-1 "Local"
discovery feature, communities, events, tech news, and AI-assisted matching.

Platform folders and dependencies are already generated in this checkout —
`flutter analyze`, `flutter test`, and `flutter build apk --debug` all pass
as-is. Follow the steps below to point the app at your own Supabase project.

## 1. Prerequisites

- Flutter SDK (stable channel, 3.22+) — https://docs.flutter.dev/get-started/install
- A Supabase account and project — https://supabase.com
- Supabase CLI — https://supabase.com/docs/guides/cli
- Xcode (for iOS) / Android Studio (for Android) as usual for Flutter development

## 2. Platform folders

`android/`, `ios/`, `web/`, `linux/`, `macos/`, and `windows/` are already
generated. If you ever need to regenerate them for a different package name,
run `flutter create --org com.yourcompany --project-name community_app .`
from the project root — it preserves `lib/` and `pubspec.yaml` and only
touches platform scaffolding.

## 3. Configure environment variables

```bash
cp .env.example .env
```

Fill in `SUPABASE_URL` and `SUPABASE_ANON_KEY` from your Supabase project's
API settings (Project Settings → API). These are public client values — see
`lib/core/network/supabase_config.dart`. Never put service-role keys or AI
provider keys here; those belong only in Edge Function secrets (step 5).

## 4. Set up the database

```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

This applies all 25 migrations in `supabase/migrations/` in order: extensions,
enums, every domain table, RLS policies on every user-data table (including
the `is_admin()` helper and admin/moderator authorization), indexes,
triggers, the privacy-safe local-discovery function, the analytics events
table, the hackathon-hosting simplification, Realtime enablement for chat,
and the automated tech-intelligence pipeline's schema (see the News section
below) — including a `pg_cron` job that refreshes news automatically. Then
seed reference data (skills, interests, storage buckets, AI scoring
weights):

```bash
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2)" -f supabase/seed.sql
```

(or paste `supabase/seed.sql` into the Supabase SQL Editor in the dashboard).

For local development instead of a hosted project:

```bash
supabase start
supabase db reset   # applies migrations + seed.sql together
```

## 5. Deploy Edge Functions

```bash
supabase functions deploy ai-match-people ai-match-team ai-match-job \
  ai-match-project ai-match-startup ai-match-mentor ai-match-local \
  get-news send-notification natural-language-search
```

Set the server-only secrets these functions need (never shipped in the app):

```bash
cp supabase/functions/.env.example supabase/functions/.env
# edit supabase/functions/.env with real values, then:
supabase secrets set --env-file supabase/functions/.env
```

`AI_PROVIDER`/`AI_PROVIDER_API_KEY` are optional — the matching functions
fall back to deterministic (non-AI) scoring if unset, and add a semantic
re-ranking pass on top of it when set (see `supabase/functions/_shared/semanticRerank.ts`).
`GITHUB_TOKEN`/`SEMANTIC_SCHOLAR_API_KEY`/`X_BEARER_TOKEN` are all optional —
`get-news`'s other sources (Hacker News, arXiv, tech RSS feeds, Show HN)
need no key at all; each of these three just degrades gracefully without
its key (lower rate limit, or that source skipped) rather than breaking
anything. `SERVICE_FUNCTION_SECRET` gates `send-notification` and the
pg_cron news-refresh job (both called by the service role, never a client)
— set it to a random value, then also run this once, directly against your
project (never as part of a migration, so it's never in git):

```sql
select vault.create_secret('<your SERVICE_FUNCTION_SECRET value>', 'service_function_secret');
```

and update the `refresh-tech-news` cron job (`supabase/migrations/0025_tech_intelligence_pipeline.sql`
seeds it with placeholder URL/key values, since those are project-specific)
with your real project URL and anon key:

```sql
select cron.schedule('refresh-tech-news', '*/30 * * * *', $$
  select net.http_post(
    url := 'https://<your-project-ref>.supabase.co/functions/v1/get-news',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <your SUPABASE_ANON_KEY>',
      'x-service-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'service_function_secret')
    ),
    body := jsonb_build_object('mode', 'refresh')
  );
$$);
```

(re-running `cron.schedule` with the same job name updates it rather than
creating a duplicate). The `Authorization` header is required by Supabase's
own Edge Function gateway — it's checked before your code ever runs; the
`x-service-secret` header is this app's own check on top of that. Neither
the URL nor the anon key is secret — both already ship in the app's own
`.env` — the Vault secret only exists to protect `SERVICE_FUNCTION_SECRET`.

`FCM_SERVER_KEY` is optional — `send-notification` always writes the in-app
notification row, and additionally pushes to every device token on file via
Firebase Cloud Messaging when this is set. Getting real tokens onto those
rows needs one more piece this repo doesn't include: a Firebase project of
your own (`google-services.json` / `GoogleService-Info.plist`) wired up with
the `firebase_messaging` package, calling
`NotificationController.registerDeviceToken()` — in
`lib/features/notifications/presentation/providers/notification_providers.dart` —
with the token it obtains. That's left to you rather than faked here, since
it needs credentials only you can generate.

## 6. Run the app

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Fix any analyzer warnings specific to your Flutter/Dart SDK version before
shipping — this was written against the current stable Material 3 /
go_router 14 / supabase_flutter 2 APIs, but exact lint output depends on the
SDK version you build with.

## What's fully implemented end-to-end

(database → RLS → repository interface + impl → state → UI → navigation, per
the project's "Definition of Done"): splash screen, email/Google/Apple auth,
onboarding, professional profile (with optional Proof of Skills), People
discovery + AI-recommended matches, professional connections + blocking,
realtime 1-to-1 chat, Hackathons + team formation + invitations, Projects +
interest requests, Jobs + applications, Local 1-to-1 discovery (privacy-safe
distance buckets, connect → chat → suggest meetup → accept — never a group
feature), hackathon team-finding (no in-app "hosting" — see below), Startups,
Mentorship, Communities, Events, live News/Tech Intelligence, Notifications,
unified Search (People/Jobs/Projects/Hackathons/Startups/Mentors/Communities),
and Moderation/Reporting — every feature that owns data uses the same
`domain/repositories` interface + `data/repositories/*_repository_impl.dart`
split, not just the original MVP set.

## Hackathons: team-finding only, never hosting

The app never lets anyone "host" a hackathon (no dates/prizes/rules/
registration/location inside the app) — a hackathon here is just a
lightweight named reference to an external event (e.g. "Smart India
Hackathon 2026") that people post team requirements against; registering
for the real event happens on the organizer's own site.
`get_or_create_hackathon()` (`supabase/migrations/0022_simplify_hackathons.sql`)
resolves a typed name to an existing hackathon (case-insensitive) or creates
one — that's the only way a hackathon row comes to exist, from
**Create → "Find a Team"** or the FAB on the Hackathons list.

## News: an automated tech-intelligence pipeline, never a manual push

`get-news` (`supabase/functions/get-news/`) is the *only* writer to
`news_items` — never a human, never Flutter. On a `pg_cron` schedule (every
30 minutes, see migration `0025`) or on demand, it runs the full pipeline:

```
supabase/functions/get-news/
├── index.ts              orchestrator
├── sources/               one file per source, each independent — a
│   ├── hackernews.ts       failure in one never takes the others down
│   ├── github.ts           (spec: fetch -> normalize -> dedupe -> filter
│   ├── arxiv.ts             -> categorize -> rank -> store)
│   ├── semanticscholar.ts
│   ├── huggingface.ts
│   ├── technews.ts        RSS: TechCrunch, The Verge, Ars Technica, VentureBeat
│   ├── startups.ts        Show HN
│   └── x.ts                optional — inert unless X_BEARER_TOKEN is set
├── filters/
│   ├── deduplication.ts   canonical URL + normalized-title hash
│   ├── relevance.ts       cheap rule-based tech-relevance scoring/categorizing
│   ├── aiRelevance.ts     optional AI refinement, borderline items only
│   └── ranking.ts         freshness/relevance/importance/trending/source-quality
└── utils/                 normalization, RSS parsing, logging, shared types
```

Flutter never calls `get-news` to read the feed — it reads `news_items`
directly via PostgREST (paginated, server-filtered by category/`is_trending`;
see `NewsRepositoryImpl.listNews`), the same pattern every other feature in
this app uses. `get-news` is purely the ingestion pipeline.

**GitHub trending is self-calculated, not GitHub's** (they don't expose
one): `github_repo_snapshots` records each repo's star count on every run,
so once a repo's been seen more than once, `github_trending_score` becomes
a real week-over-week velocity — not just "new and already popular," which
is only the fallback for a repo's first sighting.

**Filtering is deliberately aggressive** — `news_ranking_config` (one row,
editable via SQL, mirrors the `ai_scoring_weights` precedent) holds the
relevance threshold, trending threshold, and all five ranking weights, so
none of that is hardcoded. Rule-based scoring runs on every item; the AI
provider (whichever's configured — see `AI_PROVIDER` above) only reviews
items whose rule-based score landed within 15 points of the threshold, capped
at 15 per run, and any AI failure falls back to the rule-based score.

"Save"/"Hide" key off the article's own URL rather than `news_items.id` —
`saved_news` stores a denormalized snapshot so the Saved list never needs to
re-fetch, and both survive independently of whatever the pipeline does to
the underlying row. Unified Search still excludes News (a 30-minute-stale
table isn't a great match for live search-as-you-type; the feed itself is
already the discovery surface).

## Admin & moderation

`lib/features/admin/` is a moderation queue for admins/moderators: review
open reports, mark them reviewing/resolved/dismissed, and every mutation
records a `moderation_actions` row. Authorization is entirely server-side —
`is_admin()` in `supabase/migrations/0019_rls.sql` checks the `user_roles`
table (`admin`/`moderator`), which has no client write policy (role grants
are SQL-console-only, per spec section 73). The Flutter-side `isAdminProvider`
only decides whether to *show* the "Moderation queue" entry in Settings; RLS
is what actually enforces it. Grant a role with, e.g.:

```sql
insert into user_roles (profile_id, role) values ('<user-uuid>', 'admin');
```

## Analytics

`lib/core/analytics/` logs the privacy-conscious product events from spec
section 75 (`profile_completed`, `connection_sent`, `message_sent`,
`job_application`, `meetup_accepted`, etc.) to the `analytics_events` table
added in `supabase/migrations/0021_analytics.sql`. Writes are fire-and-forget
— a failed analytics call never blocks or surfaces an error for the action
it's attached to — and RLS only lets a user insert rows as themselves; only
admins can read them back.

## AI matching depth

Every `ai-match-*` Edge Function runs the deterministic weighted scoring from
spec section 43 (weights configurable per type via the `ai_scoring_weights`
table, not hardcoded in Flutter). On top of that, `_shared/semanticRerank.ts`
adds an optional semantic re-ranking pass — blending each candidate's
deterministic score with an AI relevance score (70/30) — the moment
`AI_PROVIDER`/`AI_PROVIDER_API_KEY` are configured; unset, every function is
purely deterministic with zero behavior change. `natural-language-search`
already parses free-text queries into structured filters this way too, with
a rule-based fallback when no AI provider is configured.

## Architecture

```
lib/
├── core/          # theme, routing (go_router + auth/onboarding redirect gating),
│                  # error mapping, responsive helpers, shared widgets
└── features/
    └── <feature>/
        ├── data/          # Supabase-backed repository implementations
        ├── domain/        # entities + repository interfaces
        └── presentation/
            ├── providers/ # Riverpod Notifier/AsyncNotifier + Future/StreamProviders
            ├── screens/
            └── widgets/
```

State management uses plain Riverpod (`Notifier`/`AsyncNotifier`/
`FutureProvider`/`StreamProvider`) without code generation — no
`build_runner` step is required for the Dart layer, since this environment
couldn't run codegen to verify generated output. If you'd prefer
`freezed`/`riverpod_generator`, they can be layered in later.

Realtime chat uses `supabase_flutter`'s `.stream()` API, which requires
`messages` to be in the `supabase_realtime` publication —
`supabase/migrations/0023_enable_realtime.sql` turns that on; it isn't a
default on a fresh Supabase project. Local discovery
never queries exact coordinates from the client — it always goes through the
`get_local_candidates()` SECURITY DEFINER database function, which returns
distance buckets only (see `supabase/migrations/0020_indexes_functions_triggers.sql`).
