-- 0033_referrals.sql
-- Referral Marketplace: a member who works somewhere can offer to refer
-- people there; another member requests a referral and the request moves
-- through a visible pipeline instead of a plain "Connect" button. Follows
-- the same convention as 0026's team invitations/join requests: every state
-- transition goes through a SECURITY DEFINER function that validates,
-- mutates, and writes the matching notification atomically — never a raw
-- client update.

create type referral_request_status as enum (
  'pending', 'accepted', 'declined', 'resume_submitted',
  'referral_submitted', 'interviewing', 'hired', 'rejected', 'cancelled'
);

-- ============================================================================
-- Offers: a member advertising they can refer people at a company
-- ============================================================================

create table referral_offers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  company_name text not null,
  role_title text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referral_offers_unique unique (profile_id, company_name)
);

create index referral_offers_company_idx on referral_offers(company_name);
create index referral_offers_profile_idx on referral_offers(profile_id);

alter table referral_offers enable row level security;
create policy referral_offers_select on referral_offers for select using (true);
create policy referral_offers_insert on referral_offers for insert
  with check (profile_id = auth.uid());
create policy referral_offers_update on referral_offers for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy referral_offers_delete on referral_offers for delete
  using (profile_id = auth.uid());

create trigger set_updated_at before update on referral_offers
  for each row execute function handle_updated_at();

-- ============================================================================
-- Requests: requester -> referrer, moving through the referral pipeline
-- ============================================================================

create table referral_requests (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references referral_offers(id) on delete cascade,
  -- Denormalized from the offer at request time so RLS/queries don't need a
  -- join, and so the request stays addressable even if the offer is edited.
  referrer_id uuid not null references profiles(id) on delete cascade,
  requester_id uuid not null references profiles(id) on delete cascade,
  job_title text not null,
  job_url text,
  message text,
  resume_url text,
  status referral_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint referral_requests_no_self check (referrer_id <> requester_id)
);

create index referral_requests_referrer_idx on referral_requests(referrer_id);
create index referral_requests_requester_idx on referral_requests(requester_id);
create index referral_requests_offer_idx on referral_requests(offer_id);

-- Only one active (non-terminal) request per requester per offer.
create unique index referral_requests_active_unique
  on referral_requests(offer_id, requester_id)
  where status not in ('declined', 'rejected', 'cancelled', 'hired');

alter table referral_requests enable row level security;
create policy referral_requests_select on referral_requests for select
  using (requester_id = auth.uid() or referrer_id = auth.uid());
-- No client insert/update policies — every transition below goes through a
-- SECURITY DEFINER function so validation + notification stay atomic.

create trigger set_updated_at before update on referral_requests
  for each row execute function handle_updated_at();

-- ============================================================================
-- Functions
-- ============================================================================

create or replace function request_referral(
  p_offer_id uuid,
  p_job_title text,
  p_job_url text default null,
  p_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_offer referral_offers%rowtype;
  v_requester_name text;
  v_request_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_offer from referral_offers where id = p_offer_id for update;
  if v_offer is null then
    raise exception 'referral offer not found';
  end if;
  if v_offer.profile_id = auth.uid() then
    raise exception 'you cannot request a referral from yourself';
  end if;
  if not v_offer.is_active then
    raise exception 'this referral offer is not currently active';
  end if;
  if is_blocked(auth.uid(), v_offer.profile_id) then
    raise exception 'you cannot contact this person';
  end if;
  if exists (
    select 1 from referral_requests
    where offer_id = p_offer_id and requester_id = auth.uid()
      and status not in ('declined', 'rejected', 'cancelled', 'hired')
  ) then
    raise exception 'you already have an active request for this offer';
  end if;
  if p_job_title is null or trim(p_job_title) = '' then
    raise exception 'job title is required';
  end if;

  insert into referral_requests (offer_id, referrer_id, requester_id, job_title, job_url, message)
  values (p_offer_id, v_offer.profile_id, auth.uid(), p_job_title, p_job_url, p_message)
  returning id into v_request_id;

  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_offer.profile_id,
    'referral_requested',
    'New referral request',
    coalesce(v_requester_name, 'Someone') || ' asked for a referral at ' || v_offer.company_name || ' for "' || p_job_title || '".',
    jsonb_build_object('request_id', v_request_id, 'offer_id', p_offer_id, 'company_name', v_offer.company_name, 'requester_id', auth.uid())
  );

  return v_request_id;
end;
$$;

create or replace function respond_to_referral_request(p_request_id uuid, p_accept boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request referral_requests%rowtype;
  v_offer referral_offers%rowtype;
  v_referrer_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from referral_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'referral request not found';
  end if;
  if v_request.referrer_id <> auth.uid() then
    raise exception 'only the referrer can respond to this request';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'this request has already been responded to';
  end if;

  select * into v_offer from referral_offers where id = v_request.offer_id;
  select full_name into v_referrer_name from profiles where id = auth.uid();

  if not p_accept then
    update referral_requests set status = 'declined' where id = p_request_id;
    insert into notifications (profile_id, type, title, body, data)
    values (
      v_request.requester_id,
      'referral_declined',
      'Referral request declined',
      coalesce(v_referrer_name, 'The referrer') || ' declined your referral request at ' || coalesce(v_offer.company_name, 'their company') || '.',
      jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id)
    );
    return;
  end if;

  update referral_requests set status = 'accepted' where id = p_request_id;
  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'referral_accepted',
    'Referral request accepted',
    coalesce(v_referrer_name, 'The referrer') || ' accepted your request — submit your resume to move forward.',
    jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id)
  );
end;
$$;

create or replace function submit_referral_resume(p_request_id uuid, p_resume_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request referral_requests%rowtype;
  v_requester_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_resume_url is null or trim(p_resume_url) = '' then
    raise exception 'resume link is required';
  end if;

  select * into v_request from referral_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'referral request not found';
  end if;
  if v_request.requester_id <> auth.uid() then
    raise exception 'only the requester can submit a resume';
  end if;
  if v_request.status <> 'accepted' then
    raise exception 'this request is not awaiting a resume';
  end if;

  update referral_requests
  set resume_url = p_resume_url, status = 'resume_submitted'
  where id = p_request_id;

  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.referrer_id,
    'referral_resume_submitted',
    'Resume submitted',
    coalesce(v_requester_name, 'Someone') || ' submitted their resume for the referral you accepted.',
    jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id)
  );
end;
$$;

create or replace function mark_referral_submitted(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request referral_requests%rowtype;
  v_referrer_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from referral_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'referral request not found';
  end if;
  if v_request.referrer_id <> auth.uid() then
    raise exception 'only the referrer can mark this referral as submitted';
  end if;
  if v_request.status <> 'resume_submitted' then
    raise exception 'this request is not awaiting submission';
  end if;

  update referral_requests set status = 'referral_submitted' where id = p_request_id;

  select full_name into v_referrer_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'referral_submitted',
    'Referral submitted',
    coalesce(v_referrer_name, 'The referrer') || ' submitted your referral internally.',
    jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id)
  );
end;
$$;

create or replace function update_referral_outcome(p_request_id uuid, p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request referral_requests%rowtype;
  v_referrer_name text;
  v_title text;
  v_body text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if p_status not in ('interviewing', 'hired', 'rejected') then
    raise exception 'invalid outcome status';
  end if;

  select * into v_request from referral_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'referral request not found';
  end if;
  if v_request.referrer_id <> auth.uid() then
    raise exception 'only the referrer can update this outcome';
  end if;
  if v_request.status not in ('referral_submitted', 'interviewing') then
    raise exception 'this request is not at a stage that can be updated';
  end if;
  if v_request.status = 'interviewing' and p_status = 'interviewing' then
    raise exception 'this request is already marked interviewing';
  end if;

  update referral_requests set status = p_status::referral_request_status where id = p_request_id;

  select full_name into v_referrer_name from profiles where id = auth.uid();
  v_title := case p_status
    when 'interviewing' then 'Interview stage'
    when 'hired' then 'Congratulations!'
    else 'Referral update'
  end;
  v_body := case p_status
    when 'interviewing' then 'Your referral has moved to the interview stage.'
    when 'hired' then coalesce(v_referrer_name, 'Your referrer') || ' marked you as hired!'
    else 'Your referral was not successful this time.'
  end;

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.requester_id,
    'referral_outcome_updated',
    v_title,
    v_body,
    jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id, 'status', p_status)
  );
end;
$$;

create or replace function cancel_referral_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request referral_requests%rowtype;
  v_requester_name text;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_request from referral_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'referral request not found';
  end if;
  if v_request.requester_id <> auth.uid() then
    raise exception 'only the requester can cancel this request';
  end if;
  if v_request.status not in ('pending', 'accepted', 'resume_submitted') then
    raise exception 'this request can no longer be cancelled';
  end if;

  update referral_requests set status = 'cancelled' where id = p_request_id;

  select full_name into v_requester_name from profiles where id = auth.uid();

  insert into notifications (profile_id, type, title, body, data)
  values (
    v_request.referrer_id,
    'referral_cancelled',
    'Referral request cancelled',
    coalesce(v_requester_name, 'Someone') || ' cancelled their referral request.',
    jsonb_build_object('request_id', v_request.id, 'offer_id', v_request.offer_id)
  );
end;
$$;

-- ============================================================================
-- Realtime: status changes push live to both parties (spec section 7)
-- ============================================================================

alter publication supabase_realtime add table referral_requests;
