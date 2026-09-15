-- 0034_interview_practice.sql
-- Peer mock-interview matching: a member opts into a practice pool with a
-- target role/topics, another member finds them and requests a pairing.
-- Once accepted, the pair coordinates and practices over the existing
-- direct-messaging system (get_or_create_direct_conversation, 0006) rather
-- than a new chat mechanism. Same SECURITY DEFINER convention as 0026/0033.

create type interview_practice_status as enum (
  'pending', 'accepted', 'declined', 'cancelled', 'completed'
);

-- ============================================================================
-- Pool: a member's standing "available to practice with" listing
-- ============================================================================

create table interview_practice_profiles (
  profile_id uuid primary key references profiles(id) on delete cascade,
  target_role text not null,
  topics text[] not null default '{}',
  experience_level experience_level not null default 'intermediate',
  availability_notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index interview_practice_profiles_role_idx on interview_practice_profiles(target_role);

alter table interview_practice_profiles enable row level security;
create policy interview_practice_profiles_select on interview_practice_profiles for select
  using (is_active or profile_id = auth.uid());
create policy interview_practice_profiles_insert on interview_practice_profiles for insert
  with check (profile_id = auth.uid());
create policy interview_practice_profiles_update on interview_practice_profiles for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy interview_practice_profiles_delete on interview_practice_profiles for delete
  using (profile_id = auth.uid());

create trigger set_updated_at before update on interview_practice_profiles
  for each row execute function handle_updated_at();

-- ============================================================================
-- Requests: requester -> partner, pairing up for a practice session
-- ============================================================================

create table interview_practice_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  partner_id uuid not null references profiles(id) on delete cascade,
  target_role text not null,
  message text,
  status interview_practice_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint interview_practice_requests_no_self check (requester_id <> partner_id)
);

create index interview_practice_requests_requester_idx on interview_practice_requests(requester_id);
create index interview_practice_requests_partner_idx on interview_practice_requests(partner_id);

-- Only one active (pending/accepted) request per direction between a pair.
create unique index interview_practice_requests_active_unique
  on interview_practice_requests(requester_id, partner_id)
  where status in ('pending', 'accepted');

alter table interview_practice_requests enable row level security;
create policy interview_practice_requests_select on interview_practice_requests for select
  using (requester_id = auth.uid() or partner_id = auth.uid());
-- No client insert/update — every transition goes through a function below.

create trigger set_updated_at before update on interview_practice_requests
  for each row execute function handle_updated_at();

-- ============================================================================
-- Functions
-- ============================================================================

create or replace function request_interview_practice(
  p_partner_id uuid,
  p_target_role text,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partner interview_practice_profiles%rowtype;
  v_requester_name text;
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_partner_id = auth.uid() then
    raise exception 'you cannot request practice with yourself';
  end if;
  if p_target_role is null or trim(p_target_role) = '' then
    raise exception 'target role is required';
  end if;

  select * into v_partner from interview_practice_profiles where profile_id = p_partner_id;
  if v_partner is null or not v_partner.is_active then
    raise exception 'this person is not currently open to practice requests';
  end if;
  if is_blocked(auth.uid(), p_partner_id) then
    raise exception 'you cannot contact this person';
  end if;
  if exists (
    select 1 from interview_practice_requests
    where requester_id = auth.uid() and partner_id = p_partner_id
      and status in ('pending', 'accepted')
  ) then
    raise exception 'you already have an active request with this person';
  end if;

  insert into interview_practice_requests (requester_id, partner_id, target_role, message)
  values (auth.uid(), p_partner_id, p_target_role, p_message)
  returning id into v_request_id;

  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    p_partner_id,
    'interview_practice_requested',
    'New practice request',
    coalesce(v_requester_name, 'Someone') || ' wants to practice mock interviews with you for "' || p_target_role || '".',
    jsonb_build_object('request_id', v_request_id, 'requester_id', auth.uid(), 'target_role', p_target_role)
  );

  return v_request_id;
end;
$$;

create or replace function respond_to_interview_practice_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request interview_practice_requests%rowtype;
  v_partner_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from interview_practice_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'practice request not found';
  end if;
  if v_request.partner_id <> auth.uid() then
    raise exception 'only the requested partner can respond to this request';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'this request has already been responded to';
  end if;

  select full_name into v_partner_name from profiles where id = auth.uid();

  if not p_accept then
    update interview_practice_requests set status = 'declined' where id = p_request_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_request.requester_id,
      'interview_practice_declined',
      'Practice request declined',
      coalesce(v_partner_name, 'They') || ' declined your mock-interview practice request.',
      jsonb_build_object('request_id', v_request.id)
    );
    return;
  end if;

  update interview_practice_requests set status = 'accepted' where id = p_request_id;
  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'interview_practice_accepted',
    'Practice request accepted',
    coalesce(v_partner_name, 'They') || ' accepted your mock-interview practice request — message them to set a time.',
    jsonb_build_object('request_id', v_request.id, 'partner_id', auth.uid())
  );
end;
$$;

create or replace function cancel_interview_practice_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request interview_practice_requests%rowtype;
  v_other_id uuid;
  v_canceller_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from interview_practice_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'practice request not found';
  end if;
  if auth.uid() not in (v_request.requester_id, v_request.partner_id) then
    raise exception 'not your request to cancel';
  end if;
  if v_request.status not in ('pending', 'accepted') then
    raise exception 'this request can no longer be cancelled';
  end if;

  update interview_practice_requests set status = 'cancelled' where id = p_request_id;

  v_other_id := case when auth.uid() = v_request.requester_id then v_request.partner_id else v_request.requester_id end;
  select full_name into v_canceller_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_other_id,
    'interview_practice_cancelled',
    'Practice request cancelled',
    coalesce(v_canceller_name, 'The other person') || ' cancelled the mock-interview practice request.',
    jsonb_build_object('request_id', v_request.id)
  );
end;
$$;

create or replace function mark_interview_practice_completed(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request interview_practice_requests%rowtype;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from interview_practice_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'practice request not found';
  end if;
  if auth.uid() not in (v_request.requester_id, v_request.partner_id) then
    raise exception 'not your request to complete';
  end if;
  if v_request.status <> 'accepted' then
    raise exception 'only an accepted request can be marked completed';
  end if;

  update interview_practice_requests set status = 'completed' where id = p_request_id;
end;
$$;

-- ============================================================================
-- Realtime: status changes push live to both parties (spec section 7)
-- ============================================================================

alter publication supabase_realtime add table interview_practice_requests;
