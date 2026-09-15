# Community App — Flutter + Supabase Master Architecture & Claude Code Prompt

## 1. ROLE

You are Claude Code acting as a senior Flutter architect, Supabase architect, backend engineer, database engineer, UI/UX engineer, security engineer, and QA engineer.

Build this application using:

- Flutter
- Dart
- Android
- iOS
- Supabase as the complete backend
- PostgreSQL database through Supabase
- Supabase Auth
- Supabase Realtime
- Supabase Storage
- Supabase Edge Functions
- Riverpod for state management
- go_router for navigation

The application must be production-ready, scalable, responsive, secure, and maintainable.

Do not create a fake prototype with hardcoded data.

---

# 2. PRODUCT VISION

Build a centralized community platform for:

- Students
- Developers
- IT professionals
- Job seekers
- Startup founders
- Researchers
- Technology enthusiasts

The central idea is:

> **Tell the app what you want to do, and it helps you find the right people, opportunities, communities, and information.**

The product combines:

1. Professional networking
2. Hackathon team formation
3. Project collaboration
4. Jobs and internships
5. Startup opportunities
6. Co-founder discovery
7. Mentorship
8. AI-powered people matching
9. Technology intelligence/news
10. Local 1-to-1 social discovery
11. Communities
12. Events
13. Real-time messaging

This is NOT a LinkedIn clone.

---

# 3. CRITICAL PRODUCT RULES

## 3.1 Local feature MUST be 1-to-1

The Local feature is NOT a group-meetup system.

Its purpose is:

> Help people who live away from home or are new to an area discover another compatible person nearby for a casual 1-to-1 interaction.

Flow:

```text
Discover person
       ↓
View profile
       ↓
Send local connection request
       ↓
Request accepted
       ↓
1-to-1 chat
       ↓
Both become comfortable
       ↓
Suggest meetup
       ↓
Other person accepts
       ↓
1-to-1 meetup
```

Possible activities:

- Coffee
- Walk
- Dinner
- Gaming
- Movie
- City exploration
- Casual conversation
- Shared hobbies

The Local feature should be clearly separated from professional networking.

Do not automatically treat a local connection as a professional connection.

---

# 4. PROFESSIONAL PROFILE

Professional users should NOT be forced to provide GitHub, LeetCode, Kaggle, Hugging Face, portfolio, or certifications.

The primary professional profile should contain:

- Full name
- Profile photo
- Location
- Current company
- Current role
- Total IT experience
- Years of experience
- Previous companies
- Previous roles
- Domain/industry
- Skills
- Interests
- Career goals
- Availability
- About

Optional education:

- College/university
- Degree
- Field
- Graduation year

---

# 5. OPTIONAL PROOF OF SKILLS

Create a separate optional section:

```text
Proof of Skills
```

Supported:

- GitHub
- LeetCode
- Kaggle
- Hugging Face
- Portfolio
- Certifications
- Projects

This entire section must be optional.

The user must be able to skip it.

Do not make these links required for profile completion.

---

# 6. USER TYPES

Use an enum/table-backed role system.

Possible types:

```text
student
developer
professional
job_seeker
founder
researcher
other
```

A user may later have multiple interests/intentions without changing their primary profile type.

---

# 7. SUPABASE BACKEND

Supabase is the primary backend.

Use:

```text
Supabase Auth
        ↓
PostgreSQL
        ↓
Row Level Security
        ↓
Supabase Storage
        ↓
Supabase Realtime
        ↓
Supabase Edge Functions
        ↓
External AI / News APIs
```

The Flutter app must communicate through Supabase client APIs and secure Edge Functions.

NEVER put private API keys inside Flutter.

---

# 8. SUPABASE PROJECT STRUCTURE

Create:

```text
supabase/
├── config.toml
├── migrations/
│   ├── 0001_extensions.sql
│   ├── 0002_enums.sql
│   ├── 0003_profiles.sql
│   ├── 0004_skills_interests.sql
│   ├── 0005_connections.sql
│   ├── 0006_messaging.sql
│   ├── 0007_hackathons.sql
│   ├── 0008_projects.sql
│   ├── 0009_jobs.sql
│   ├── 0010_startups.sql
│   ├── 0011_mentorship.sql
│   ├── 0012_local.sql
│   ├── 0013_communities.sql
│   ├── 0014_events.sql
│   ├── 0015_news.sql
│   ├── 0016_notifications.sql
│   ├── 0017_ai.sql
│   ├── 0018_reports_moderation.sql
│   ├── 0019_rls.sql
│   └── 0020_indexes_functions_triggers.sql
│
├── functions/
│   ├── ai/
│   ├── recommendations/
│   ├── news/
│   ├── notifications/
│   └── moderation/
│
└── seed.sql
```

Keep schema changes in migrations.

Do not manually create production schema from the Flutter application.

---

# 9. POSTGRESQL EXTENSIONS

Use only required extensions.

Recommended:

```sql
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";
```

For semantic search/recommendation architecture, evaluate:

```sql
create extension if not exists vector;
```

Use vector search only where genuinely useful.

---

# 10. DATABASE DESIGN

Use UUID primary keys.

General pattern:

```sql
id uuid primary key default gen_random_uuid(),
created_at timestamptz not null default now(),
updated_at timestamptz not null default now()
```

Use foreign keys with appropriate delete behavior.

Avoid storing arrays for relationships when a normalized join table is more appropriate.

---

# 11. PROFILES TABLE

Create:

```sql
profiles
```

Suggested columns:

```text
id uuid PK references auth.users(id)
username
full_name
avatar_url
bio
city
country
latitude_approx
longitude_approx
primary_user_type
current_company
current_role
total_it_experience_months
is_open_to_work
is_open_to_internship
is_open_to_freelance
is_open_to_mentorship
professional_discoverable
local_discoverable
profile_completed
created_at
updated_at
```

IMPORTANT:

Do NOT store exact home address.

Do NOT expose exact GPS coordinates.

If geographic matching is required, store privacy-safe approximate location or use a controlled geographic representation.

---

# 12. PROFILE EXPERIENCE

Create:

```text
experiences
```

Columns:

```text
id
profile_id
company_name
role
employment_type
start_date
end_date
is_current
description
created_at
updated_at
```

Employment types:

```text
full_time
part_time
internship
contract
freelance
other
```

---

# 13. EDUCATION

Create:

```text
education
```

Columns:

```text
id
profile_id
institution
degree
field_of_study
start_year
end_year
is_current
created_at
updated_at
```

---

# 14. SKILLS

Create:

```text
skills
```

Columns:

```text
id
name
normalized_name
category
created_at
```

Relationship:

```text
profile_skills
```

Columns:

```text
profile_id
skill_id
experience_level
years_experience
```

Experience level:

```text
beginner
intermediate
advanced
expert
```

---

# 15. INTERESTS

Create:

```text
interests
```

and:

```text
profile_interests
```

Examples:

```text
AI
Machine Learning
Flutter
Startups
Hackathons
Open Source
Gaming
Movies
Running
Photography
Research
```

---

# 16. OPTIONAL PROOF OF SKILLS

Create:

```text
optional_proofs
```

Columns:

```text
id
profile_id
proof_type
url
title
description
verified
created_at
updated_at
```

proof_type:

```text
github
leetcode
kaggle
huggingface
portfolio
certification
project
```

No proof is required.

---

# 17. PROFESSIONAL CONNECTIONS

Create:

```text
connections
```

Columns:

```text
id
requester_id
receiver_id
status
created_at
updated_at
```

Status:

```text
pending
accepted
declined
cancelled
blocked
```

Constraints:

- Prevent duplicate active connection requests.
- Prevent self-connections.
- Respect block relationships.

---

# 18. BLOCKS

Create:

```text
blocks
```

Columns:

```text
id
blocker_id
blocked_id
created_at
```

A blocked user must not be able to:

- Send connection requests
- Send local requests
- Message
- View restricted profile data

---

# 19. MESSAGING

Create:

```text
conversations
conversation_members
messages
message_reactions
```

## conversations

```text
id
conversation_type
created_at
updated_at
```

conversation_type:

```text
direct
```

For MVP only support 1-to-1 direct conversations.

## conversation_members

```text
conversation_id
profile_id
joined_at
```

## messages

```text
id
conversation_id
sender_id
message_type
content
attachment_url
created_at
updated_at
deleted_at
```

message_type:

```text
text
image
file
system
```

Use Supabase Realtime for new messages.

RLS must ensure users can only read conversations they belong to.

---

# 20. HACKATHONS

Create:

```text
hackathons
```

Columns:

```text
id
host_id
name
description
organizer
start_at
end_at
registration_deadline
mode
location
team_min_size
team_max_size
prize_description
theme
rules
registration_url
team_formation_enabled
status
created_at
updated_at
```

Mode:

```text
online
offline
hybrid
```

---

# 21. HACKATHON PARTICIPANTS

Create:

```text
hackathon_participants
```

Columns:

```text
id
hackathon_id
profile_id
status
created_at
```

---

# 22. HACKATHON TEAM REQUIREMENTS

Create:

```text
hackathon_team_requirements
```

Columns:

```text
id
hackathon_id
creator_id
team_name
description
required_roles
required_skills
team_size
status
created_at
updated_at
```

Use normalized skill relationships where practical.

---

# 23. TEAM INVITATIONS

Create:

```text
team_invitations
```

Columns:

```text
id
team_requirement_id
sender_id
receiver_id
status
message
created_at
updated_at
```

Status:

```text
pending
accepted
rejected
cancelled
```

---

# 24. PROJECT COLLABORATION

Create:

```text
projects
```

Columns:

```text
id
owner_id
title
description
category
collaboration_type
compensation_type
compensation_details
time_commitment_hours
duration_description
status
created_at
updated_at
```

collaboration_type:

```text
personal
startup
open_source
research
hackathon
other
```

compensation_type:

```text
paid
unpaid
equity
negotiable
```

---

# 25. PROJECT REQUIREMENTS

Create:

```text
project_requirements
```

Columns:

```text
id
project_id
role
description
required_experience
created_at
updated_at
```

Create:

```text
project_required_skills
```

Columns:

```text
project_id
skill_id
```

---

# 26. PROJECT INTEREST

Create:

```text
project_interests
```

Columns:

```text
id
project_id
profile_id
message
status
created_at
updated_at
```

Status:

```text
pending
accepted
rejected
```

---

# 27. JOBS

Create:

```text
jobs
```

Columns:

```text
id
poster_id
company_name
title
description
employment_type
work_mode
location
experience_min_months
experience_max_months
salary_min
salary_max
currency
application_url
deadline
status
created_at
updated_at
```

employment_type:

```text
full_time
internship
freelance
contract
part_time
research
volunteer
```

work_mode:

```text
remote
hybrid
onsite
```

---

# 28. JOB APPLICATIONS

Create:

```text
job_applications
```

Columns:

```text
id
job_id
profile_id
status
cover_message
created_at
updated_at
```

Status:

```text
submitted
reviewing
shortlisted
rejected
accepted
withdrawn
```

---

# 29. STARTUPS

Create:

```text
startups
```

Columns:

```text
id
owner_id
name
logo_url
description
industry
stage
location
website
team_size
created_at
updated_at
```

Stage:

```text
idea
mvp
early_revenue
growth
funded
```

---

# 30. STARTUP MEMBERS

Create:

```text
startup_members
```

Columns:

```text
startup_id
profile_id
role
is_founder
created_at
```

---

# 31. STARTUP OPPORTUNITIES

Create:

```text
startup_opportunities
```

Columns:

```text
id
startup_id
title
description
role
compensation_type
is_remote
status
created_at
updated_at
```

Use cases:

- Co-founder
- Developer
- Designer
- ML engineer
- Intern
- Advisor
- Marketing
- Other

---

# 32. MENTORSHIP

Create:

```text
mentor_profiles
```

Columns:

```text
profile_id
available
expertise
topics
session_duration_minutes
pricing_type
price
currency
bio
created_at
updated_at
```

pricing_type:

```text
free
paid
```

Create:

```text
mentor_requests
```

and:

```text
mentor_sessions
```

---

# 33. LOCAL 1-TO-1 DISCOVERY

Create:

```text
local_profiles
```

Columns:

```text
profile_id
enabled
approximate_city
approximate_area
preferred_radius_km
bio
created_at
updated_at
```

Create:

```text
local_preferences
```

Columns:

```text
profile_id
activity_preferences
interest_preferences
availability_preferences
age_range_preference
created_at
updated_at
```

Use careful privacy rules around age and location.

Do not expose exact location.

---

# 34. LOCAL CONNECTIONS

Create:

```text
local_connections
```

Columns:

```text
id
requester_id
receiver_id
status
created_at
updated_at
```

Status:

```text
pending
accepted
declined
cancelled
blocked
```

A local connection is separate from a professional connection.

---

# 35. LOCAL MEETUP SUGGESTIONS

Create:

```text
meetup_suggestions
```

Columns:

```text
id
local_connection_id
suggested_by
activity_type
suggested_area
suggested_place_name
suggested_at
message
status
created_at
updated_at
```

Status:

```text
pending
accepted
declined
cancelled
completed
```

Only create a meetup after a local connection exists.

The meetup is always 1-to-1.

---

# 36. COMMUNITIES

Create:

```text
communities
community_members
community_posts
community_comments
```

Communities can be:

- Technology
- City
- Student
- Startup
- Research
- Open source
- Interest based

Do not confuse Communities with Local 1-to-1.

---

# 37. EVENTS

Create:

```text
events
event_attendees
```

Events can be:

- Hackathons
- Workshops
- Conferences
- Tech talks
- Study sessions
- Community events

Group events are allowed in the Events feature.

But Local remains 1-to-1.

---

# 38. NEWS / TECH INTELLIGENCE

Create:

```text
news_sources
news_items
news_categories
news_item_categories
saved_news
```

News sources can include:

- Official company announcements
- Research feeds
- arXiv metadata
- GitHub trending
- Hugging Face trending
- Developer ecosystem sources

Store metadata and summaries.

Do NOT copy complete copyrighted articles.

---

# 39. NEWS ITEM

Suggested fields:

```text
id
source_id
title
summary
url
published_at
image_url
external_id
source_author
category
ai_summary
why_it_matters
technical_impact
created_at
updated_at
```

Use unique external IDs where available to avoid duplicates.

---

# 40. PERSONALIZED NEWS

Use profile interests to rank news.

Example:

User interests:

```text
AI
Flutter
Startups
Open Source
```

The feed prioritizes related news.

Allow:

```text
Save
Hide
Not Interested
Share
```

---

# 41. AI NEWS SUMMARIZATION

Use Supabase Edge Functions for private AI API calls.

Architecture:

```text
News Source
    ↓
Edge Function
    ↓
Normalize article metadata
    ↓
AI summarization
    ↓
Store summary
    ↓
Flutter
```

Do not call private AI APIs directly from Flutter.

---

# 42. AI MATCHING

Create:

```text
ai_recommendations
ai_match_scores
ai_feedback
```

Example recommendation types:

```text
person
hackathon_team
project
job
startup
mentor
local_person
news
```

Store:

```text
candidate_id
recommendation_type
score
reason
model_version
created_at
```

Do not present AI scores as objective truth.

Use language such as:

```text
92% recommended match
```

and show reasons.

---

# 43. MATCHING ENGINE

Create a backend matching service.

Architecture:

```text
Flutter
   ↓
Supabase Edge Function
   ↓
Candidate Retrieval
   ↓
Deterministic Scoring
   ↓
Optional Semantic Ranking
   ↓
Privacy Filtering
   ↓
Final Recommendations
```

Initial scoring can use:

```text
Skills            35%
Interests         20%
Goals             15%
Experience        10%
Availability      10%
Location           5%
Activity           5%
```

Make weights configurable.

Do not permanently hardcode these weights in Flutter.

---

# 44. LOCAL MATCHING

For Local matching prioritize:

```text
Shared interests
Shared activities
Compatible availability
Approximate location
Conversation intent
User preferences
```

Do not prioritize professional ranking too heavily.

The purpose is casual compatibility.

---

# 45. AI ASSISTANT

Create an AI assistant abstraction:

```text
AIService
├── recommendPeople()
├── matchHackathonTeam()
├── matchProjectMembers()
├── matchJobs()
├── matchMentors()
├── matchLocalPeople()
├── summarizeNews()
├── explainNews()
├── careerRecommendations()
└── naturalLanguageSearch()
```

The AI provider must be replaceable.

Use Edge Functions.

---

# 46. NATURAL LANGUAGE SEARCH

Future functionality:

User:

> Find Flutter developers in Bangalore with 2+ years experience.

Convert to structured filters:

```text
skill = Flutter
city = Bangalore
experience >= 24 months
```

Another:

> Find someone nearby who likes AI and coffee and wants casual conversation.

Search:

```text
local_discoverable = true
interest = AI
activity = coffee
intent = casual
```

Never expose private location data.

---

# 47. NOTIFICATIONS

Create:

```text
notifications
device_tokens
notification_preferences
```

Notify for:

- Connection request
- Connection accepted
- New message
- Team invitation
- Project interest
- Job application
- Mentor request
- Local connection request
- Meetup suggestion
- Meetup acceptance
- Community event
- Relevant news

Use Edge Functions for secure server-triggered notifications.

---

# 48. STORAGE

Use Supabase Storage buckets.

Suggested:

```text
avatars
project-images
startup-logos
chat-attachments
community-media
```

Bucket access must be controlled.

Do not make private user content publicly accessible unless intentionally designed.

---

# 49. RLS SECURITY

Enable RLS on ALL user-data tables.

Example:

```sql
alter table profiles enable row level security;
```

Policies must ensure:

## Profiles

Public profile fields can be viewed according to discoverability.

Private fields only accessible to the owner or authorized contexts.

## Messages

Only conversation members can:

- Select messages
- Insert messages
- Update/delete their own messages where permitted

## Connections

Users can only manage their own requests/connections.

## Local

Only users with Local discovery enabled can appear in Local search.

Exact location must never be queryable by other users.

## Projects

Only owner/admin can modify project.

## Jobs

Only authorized poster can modify job.

## Startups

Only startup members with appropriate role can modify startup.

## Communities

Membership determines private content access.

## Reports

Reporter identity must never be visible to the reported user.

---

# 50. SECURITY DEFINER FUNCTIONS

Where appropriate, use PostgreSQL functions with SECURITY DEFINER for controlled operations such as:

- Privacy-safe local discovery
- Connection creation
- Block-aware messaging access
- Recommendation candidate retrieval

SECURITY DEFINER functions must:

- Set a safe search_path
- Validate auth.uid()
- Validate all inputs
- Never bypass intended authorization

---

# 51. PRIVACY-SAFE LOCAL SEARCH

Do NOT run:

```sql
select latitude, longitude from profiles;
```

for other users.

Instead expose a database function such as:

```text
get_local_candidates()
```

which returns only:

```text
profile_id
display_name
avatar
approximate_distance_bucket
city
area
interests
activities
bio
```

Example distance:

```text
<1 km
1–3 km
3–5 km
5–10 km
```

Never exact coordinates.

---

# 52. AUTHENTICATION

Use Supabase Auth.

Support:

- Email/password
- Email OTP if useful
- Google
- Apple Sign-In

Auth flow:

```text
Splash
 ↓
Auth
 ↓
Check profile
 ↓
Onboarding if incomplete
 ↓
Home
```

Use auth.uid() everywhere in RLS.

---

# 53. FLUTTER ARCHITECTURE

Use Clean Architecture.

```text
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── network/
│   ├── routing/
│   ├── theme/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── home/
│   ├── profile/
│   ├── people/
│   ├── connections/
│   ├── messaging/
│   ├── hackathons/
│   ├── projects/
│   ├── jobs/
│   ├── startups/
│   ├── mentorship/
│   ├── local/
│   ├── communities/
│   ├── events/
│   ├── news/
│   ├── ai/
│   ├── notifications/
│   └── settings/
│
└── main.dart
```

Each major feature:

```text
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
└── presentation/
    ├── providers/
    ├── screens/
    └── widgets/
```

---

# 54. FLUTTER DEPENDENCIES

Prefer:

```text
flutter_riverpod
go_router
supabase_flutter
freezed
json_serializable
build_runner
cached_network_image
image_picker
intl
connectivity_plus
```

Use packages only when they provide real value.

Do not add unnecessary dependencies.

---

# 55. REPOSITORIES

Create interfaces:

```text
AuthRepository
ProfileRepository
PeopleRepository
ConnectionRepository
MessageRepository
HackathonRepository
ProjectRepository
JobRepository
StartupRepository
MentorRepository
LocalRepository
CommunityRepository
EventRepository
NewsRepository
NotificationRepository
AIRepository
```

Do not access Supabase directly from UI widgets.

---

# 56. DATA FLOW

Recommended:

```text
UI
 ↓
Riverpod Provider / Notifier
 ↓
Use Case
 ↓
Repository
 ↓
Supabase Data Source
 ↓
PostgreSQL / Realtime / Storage
```

For realtime chat:

```text
Supabase Realtime
 ↓
Message Data Source
 ↓
Repository
 ↓
Riverpod state
 ↓
Chat UI
```

---

# 57. STATE MANAGEMENT

Use Riverpod.

Do not place business logic in widgets.

Use:

```text
AsyncNotifier
Notifier
FutureProvider
StreamProvider
Provider
```

where appropriate.

Every screen must properly handle:

```text
Loading
Success
Empty
Error
```

---

# 58. NAVIGATION

Use go_router.

Mobile bottom navigation:

```text
Home
Discover
Create
Messages
Profile
```

Discover categories:

```text
People
Jobs
Hackathons
Projects
Startups
Mentors
Local
Communities
News
```

---

# 59. HOME

Home should be personalized.

Sections:

```text
Recommended for You

Opportunities
Hackathons
Projects
Jobs
Startups
Mentors

People You May Know

Local 1-to-1

Tech Intelligence

Continue:
Chats
Saved items
Pending requests
```

Do not make it only a chronological social feed.

---

# 60. CREATE MENU

Create:

```text
Hackathon
Hackathon Team Requirement
Project
Job
Startup Opportunity
Mentorship
Community
Event
```

Local connections should generally be initiated from Local discovery rather than generic content creation.

---

# 61. PEOPLE DISCOVERY

Support filters:

```text
Role
Skills
Experience
Company
Industry
Student/Professional
Location
Availability
Interests
Goals
```

Cards should show:

```text
Name
Role
Company
Experience
Skills
Interests
Match
```

Do not overload cards.

---

# 62. PROFESSIONAL PROFILE UI

Example:

```text
Name
Software Engineer at Company

5 years IT experience

Current Role
Software Engineer

Experience
5 years

Previous:
Company A
Company B

Skills
Flutter
Dart
Firebase
AI

Interests
Startups
Hackathons
AI

Looking for
Projects
Networking
Startup opportunities

Proof of Skills
Optional
```

---

# 63. LOCAL PROFILE UI

Separate from professional profile.

Example:

```text
Name
Software Engineer

~2–3 km away

Interested in:
Coffee
Movies
AI
Running

Looking for:
Casual conversation
New people in the city

[Connect]
```

Do not show exact location.

Do not make professional details the focus.

---

# 64. LOCAL FLOW UI

```text
Local
 ↓
Discover people
 ↓
Profile
 ↓
Connect
 ↓
Request accepted
 ↓
Chat
 ↓
Suggest Meetup
 ↓
Choose activity
 ↓
Choose approximate area
 ↓
Suggest date/time
 ↓
Accept
```

Both users must explicitly agree.

---

# 65. CHAT UI

Support:

- Text
- Emoji
- Images
- Attachments where appropriate
- Typing indicator
- Read state
- Message timestamps
- Reactions
- Delete own message
- Block
- Report

Do not expose phone numbers automatically.

---

# 66. RESPONSIVE UI

Must support:

- Small Android
- Large Android
- iPhone
- Large iPhone
- iPad/tablets

Use:

```text
LayoutBuilder
MediaQuery
SafeArea
Flexible
Expanded
Wrap
SliverList
Custom breakpoints
```

Avoid fixed widths.

Test:

- Long names
- Long company names
- Long job titles
- Large accessibility font
- Empty data
- Offline mode

---

# 67. UI STYLE

Use Material 3 with a customized visual system.

Desired:

- Premium
- Modern
- Clean
- Friendly
- Professional
- Community oriented

Use:

- Rounded cards
- Good spacing
- Bottom sheets
- Chips
- Avatars
- Skeleton loaders
- Empty states
- Subtle animations

Do NOT copy LinkedIn.

---

# 68. SEARCH

Create unified search:

```text
People
Jobs
Projects
Hackathons
Startups
Mentors
Communities
News
```

Use debouncing.

Paginate results.

Future natural-language search should use Edge Functions.

---

# 69. PAGINATION

Every potentially large list must be paginated:

- People
- Jobs
- Projects
- Hackathons
- Messages
- News
- Communities
- Notifications

Do not download thousands of rows.

Use cursor-based pagination where practical.

---

# 70. OFFLINE

At minimum:

- Detect connectivity
- Show offline state
- Cache non-sensitive content
- Handle temporary realtime disconnects
- Retry failed requests

Do not cache secrets insecurely.

---

# 71. ERROR HANDLING

Create centralized errors:

```text
NetworkFailure
AuthenticationFailure
PermissionFailure
ValidationFailure
ServerFailure
NotFoundFailure
RateLimitFailure
UnknownFailure
```

Every feature needs:

```text
Loading
Empty
Error
Retry
```

---

# 72. MODERATION

Create:

```text
reports
moderation_actions
```

Report categories:

```text
spam
harassment
fake_profile
scam
inappropriate_content
unsafe_behavior
fraud
other
```

Users can report:

- Profiles
- Messages
- Jobs
- Projects
- Hackathons
- Communities
- Startups
- Events

---

# 73. ADMIN

Build backend-ready admin authorization.

Admin capabilities:

- Manage users
- Review reports
- Moderate content
- Manage news sources
- Manage communities
- Moderate jobs
- Moderate projects
- Moderate hackathons

Admin role must never be trusted from Flutter input.

Use server-side authorization.

---

# 74. NOTIFICATION PREFERENCES

Allow users to control:

```text
Messages
Connections
Jobs
Hackathons
Projects
Mentorship
Local requests
Meetups
News
Community events
```

---

# 75. ANALYTICS

Create privacy-conscious events:

```text
profile_completed
connection_sent
connection_accepted
message_sent
hackathon_viewed
team_request
project_interest
job_application
mentor_request
local_connection_request
meetup_suggested
meetup_accepted
news_opened
```

Do not collect unnecessary personal data.

---

# 76. ENVIRONMENT VARIABLES

Flutter public configuration:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

These are public client configuration values, but still keep environment management clean.

Private secrets such as:

```text
AI_PROVIDER_API_KEY
NEWS_API_KEY
OTHER_SERVER_SECRET
```

must ONLY exist in Supabase Edge Function secrets.

Never:

```text
NEXT_PUBLIC_...
```

or equivalent client-exposed private secrets.

---

# 77. SUPABASE EDGE FUNCTIONS

Use Edge Functions for:

```text
ai-match-people
ai-match-team
ai-match-job
ai-match-project
ai-match-startup
ai-match-mentor
ai-match-local
summarize-news
fetch-news
sync-github-trending
sync-huggingface-trending
send-notification
natural-language-search
```

Names may be adjusted to actual implementation.

---

# 78. AI PROVIDER ABSTRACTION

Do not directly couple application logic to one AI provider.

Use:

```text
AiProvider
```

with methods:

```text
generateText()
generateEmbedding()
rankCandidates()
summarize()
```

Possible provider implementations can later include:

```text
OpenAI
Anthropic
Google
Local model
Other provider
```

The initial provider should be configured through server-side environment variables.

---

# 79. VECTOR SEARCH

If using pgvector:

Create embeddings only for appropriate entities such as:

- User interests/about
- Projects
- Jobs
- Hackathons
- Startup opportunities
- News

Do not blindly embed every database column.

Example:

```text
profile_embedding
project_embedding
job_embedding
hackathon_embedding
startup_embedding
news_embedding
```

Use vector search for semantic candidate retrieval, followed by privacy filtering and deterministic ranking.

---

# 80. NEWS INGESTION

News ingestion must run server-side.

Pipeline:

```text
Scheduled Edge Function
       ↓
Fetch source metadata
       ↓
Normalize
       ↓
Deduplicate
       ↓
Categorize
       ↓
Generate summary
       ↓
Store
       ↓
Update personalized feeds
```

Do not scrape sources in the Flutter client.

Respect API terms and robots/copyright requirements.

---

# 81. GITHUB / HUGGING FACE DATA

For trending repositories/models:

- Use official/public APIs where available.
- Store metadata.
- Store source URL.
- Do not copy repository/model content unnecessarily.
- Refresh through scheduled server-side jobs.

Example stored fields:

```text
name
description
url
stars
language
author
updated_at
source
```

---

# 82. DATABASE INDEXES

Create indexes for common queries.

Examples:

```text
profiles(city)
profiles(primary_user_type)
profiles(professional_discoverable)
profiles(local_discoverable)

profile_skills(skill_id)
profile_interests(interest_id)

connections(requester_id)
connections(receiver_id)

messages(conversation_id, created_at)

hackathons(start_at)
hackathons(registration_deadline)

jobs(status, deadline)
projects(status)
local_profiles(approximate_city)
news_items(published_at)
notifications(profile_id, created_at)
```

Add composite indexes based on actual query patterns.

---

# 83. DATABASE CONSTRAINTS

Use database-level constraints where possible.

Examples:

- Self-connection prohibited
- Self-block prohibited
- Duplicate profile-skill prohibited
- Duplicate profile-interest prohibited
- Duplicate community membership prohibited
- Duplicate event attendance prohibited
- Invalid date ranges prohibited where practical
- Negative experience prohibited
- Invalid salary range prohibited

Never rely only on Flutter validation.

---

# 84. UPDATED_AT TRIGGERS

Create a reusable PostgreSQL function:

```sql
handle_updated_at()
```

and apply it to mutable tables.

---

# 85. AUTH PROFILE TRIGGER

When a new Supabase Auth user is created, create the corresponding profile row safely.

Do not put sensitive application logic inside the auth trigger.

Use a minimal profile initialization trigger and complete onboarding from the application.

---

# 86. SEED DATA

Create safe development seed data for:

- Skills
- Interests
- News categories
- Demo communities
- Demo hackathons
- Demo jobs

Never use fake production credentials.

---

# 87. TESTING

## Flutter unit tests

Test:

- Matching calculations
- Validation
- Models
- Repositories
- Notifiers
- Search parsing

## Widget tests

Test:

- Auth
- Onboarding
- Profile
- People
- Chat
- Hackathon
- Project
- Job
- Local

## Integration tests

Test:

```text
Sign up
 ↓
Create profile
 ↓
Find person
 ↓
Send professional connection
 ↓
Accept
 ↓
Chat
```

And:

```text
Local discovery
 ↓
Local request
 ↓
Accept
 ↓
Chat
 ↓
Suggest meetup
 ↓
Accept
```

And:

```text
Hackathon
 ↓
Team requirement
 ↓
AI recommendations
 ↓
Invitation
 ↓
Accept
```

---

# 88. SUPABASE LOCAL DEVELOPMENT

The project should support Supabase CLI.

Recommended workflow:

```bash
supabase init
supabase start
supabase db reset
supabase migration new <migration_name>
supabase migration up
```

Before production deployment:

```bash
supabase db lint
supabase db push
```

Use the exact currently supported Supabase CLI commands if syntax changes.

---

# 89. FLUTTER COMMANDS

Use:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Android:

```bash
flutter build apk --debug
```

iOS on macOS:

```bash
flutter build ios --debug
```

Fix all analyzer errors and test failures.

---

# 90. IMPLEMENTATION ORDER

## Phase 1 — Backend foundation

1. Initialize Supabase
2. Create migrations
3. Create enums
4. Create profiles
5. Create skills/interests
6. Create RLS
7. Create storage buckets
8. Create auth flow

## Phase 2 — Flutter foundation

9. Flutter architecture
10. Riverpod
11. go_router
12. Theme
13. Responsive system
14. Supabase client
15. Error handling

## Phase 3 — User system

16. Authentication
17. Onboarding
18. Profile
19. Professional experience
20. Skills
21. Optional proof

## Phase 4 — Networking

22. People discovery
23. Professional connections
24. Blocking
25. Reporting
26. Notifications
27. Direct chat

## Phase 5 — Opportunities

28. Hackathons
29. Team formation
30. Projects
31. Jobs
32. Startups
33. Mentorship

## Phase 6 — Local

34. Local profile
35. Local discovery
36. 1-to-1 request
37. Chat
38. Meetup suggestion
39. Meetup acceptance
40. Privacy/safety

## Phase 7 — Knowledge

41. News
42. Research
43. GitHub trending
44. Hugging Face trending
45. Personalized feed

## Phase 8 — AI

46. AI abstraction
47. Candidate matching
48. Team matching
49. Job matching
50. Project matching
51. Startup matching
52. Mentor matching
53. Local matching
54. Natural-language search
55. AI assistant

---

# 91. MVP SCOPE

For the first working MVP prioritize:

```text
Authentication
Onboarding
Profile
People
Professional Connections
1-to-1 Chat
Hackathons
Team Formation
Projects
Jobs
Local 1-to-1 Discovery
```

The architecture must already support:

```text
Startups
Mentorship
Communities
Events
News
AI
```

but these can be implemented after the core flows are stable.

---

# 92. MOST IMPORTANT UX PRINCIPLE

The app should always answer:

> **What can I do here right now?**

Home should expose clear actions:

```text
Find a Person
Find a Team
Find a Project
Find a Job
Find a Mentor
Find a Startup Opportunity
Meet Someone Nearby
Read What's New
```

---

# 93. PRODUCT DIFFERENTIATION

Do not market the product simply as:

> A professional networking app.

The stronger positioning is:

> **One place to find the right person or opportunity for what you want to do.**

Examples:

```text
Need a hackathon team?
→ Find teammates.

Need help with a project?
→ Find collaborators.

Need a job?
→ Find opportunities.

Need a co-founder?
→ Find startup people.

Need mentorship?
→ Find a mentor.

New in a city?
→ Find one compatible person nearby.

Want to know what is happening in tech?
→ Tech Intelligence.

Don't know where to start?
→ Ask Community AI.
```

---

# 94. CLAUDE CODE EXECUTION RULES

Before coding:

1. Inspect repository.
2. Identify existing Flutter/Supabase setup.
3. Do not overwrite working code unnecessarily.
4. Create implementation plan.
5. Build database migrations first.
6. Build RLS policies.
7. Build domain models.
8. Build repositories.
9. Build state management.
10. Build UI.
11. Add tests.
12. Run analyzer.
13. Run tests.
14. Fix errors.
15. Only then move to next feature.

For every feature verify:

```text
Database
RLS
Repository
Domain
State
UI
Validation
Loading
Empty
Error
Responsive
Navigation
Tests
```

---

# 95. DEFINITION OF DONE

A feature is NOT complete merely because its screen exists.

It is complete only when:

- Database exists
- Migration exists
- RLS exists
- Repository exists
- Domain model exists
- State management exists
- UI exists
- Validation exists
- Loading state exists
- Empty state exists
- Error state exists
- Responsive layout exists
- Navigation exists
- Security is handled
- Tests exist where appropriate

---

# 96. FINAL ARCHITECTURE

```text
                         FLUTTER APP
                              │
                 ┌────────────┴────────────┐
                 │                         │
           Presentation                Riverpod
                 │                         │
                 └────────────┬────────────┘
                              │
                         Use Cases
                              │
                         Repositories
                              │
                    Supabase Data Layer
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   PostgreSQL              Realtime              Storage
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              │
                       Edge Functions
                              │
                ┌─────────────┼─────────────┐
                │             │             │
               AI           News         Notifications
                │             │             │
                └─────────────┼─────────────┘
                              │
                       External APIs
```

---

# 97. CORE DATABASE DOMAIN MAP

```text
AUTH
 │
 └── profiles
       ├── experiences
       ├── education
       ├── profile_skills
       ├── profile_interests
       └── optional_proofs

profiles
 ├── connections
 ├── conversations
 │     └── messages
 │
 ├── hackathons
 │     ├── participants
 │     ├── team_requirements
 │     └── invitations
 │
 ├── projects
 │     ├── requirements
 │     └── interests
 │
 ├── jobs
 │     └── applications
 │
 ├── startups
 │     ├── members
 │     └── opportunities
 │
 ├── mentorship
 │     ├── mentor_profiles
 │     ├── requests
 │     └── sessions
 │
 ├── local
 │     ├── local_profiles
 │     ├── local_preferences
 │     ├── local_connections
 │     └── meetup_suggestions
 │
 ├── communities
 │     ├── members
 │     ├── posts
 │     └── comments
 │
 ├── events
 │     └── attendees
 │
 └── notifications

NEWS
 ├── sources
 ├── categories
 ├── news_items
 └── saved_news

AI
 ├── recommendations
 ├── match_scores
 └── feedback
```

---

# 98. FINAL INSTRUCTION TO CLAUDE CODE

Build this as a real production-grade Flutter + Supabase application.

Do not reduce the requirements to a static UI prototype.

Do not hardcode data.

Do not expose secrets.

Do not bypass RLS.

Do not place business logic in widgets.

Do not make GitHub/LeetCode/etc. mandatory.

Do not turn Local into a group meetup feature.

Keep Professional Networking and Local 1-to-1 Social Discovery as separate intents.

The Local flow must remain:

```text
Discover
→ Connect
→ Chat
→ Optional Meetup
→ 1-to-1
```

The application must be responsive on both Android and iOS.

The database must be implemented through Supabase PostgreSQL migrations with proper RLS, indexes, constraints, triggers, and security.

The architecture must be modular enough that AI matching, news intelligence, startup matching, mentorship, communities, and future features can be added without rewriting the core application.

Start by inspecting the repository, then produce a concise implementation plan, then implement the Supabase database foundation first.
