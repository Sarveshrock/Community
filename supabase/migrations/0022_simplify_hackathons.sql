-- 0022_simplify_hackathons.sql
-- Product simplification: this app never hosts a hackathon (no dates,
-- prizes, rules, registration deadline, mode, location, or in-app
-- registration) — a hackathon here is just a lightweight named reference to
-- an external event (e.g. "Smart India Hackathon 2026") that people post
-- team requirements against. Registration for the real event happens on the
-- organizer's own site.

drop table if exists hackathon_participants;

alter table hackathons
  drop column if exists description,
  drop column if exists organizer,
  drop column if exists end_at,
  drop column if exists registration_deadline,
  drop column if exists mode,
  drop column if exists location,
  drop column if exists team_min_size,
  drop column if exists team_max_size,
  drop column if exists prize_description,
  drop column if exists theme,
  drop column if exists rules,
  drop column if exists registration_url,
  drop column if exists team_formation_enabled,
  drop column if exists status;

alter table hackathons drop constraint if exists hackathons_date_range;

alter table hackathons rename column start_at to event_date;
alter table hackathons alter column event_date type date using event_date::date;
alter table hackathons alter column event_date drop not null;
alter index if exists hackathons_start_at_idx rename to hackathons_event_date_idx;

alter table hackathons drop constraint if exists hackathons_host_id_fkey;
alter table hackathons rename column host_id to created_by;
alter table hackathons alter column created_by drop not null;
alter table hackathons add constraint hackathons_created_by_fkey
  foreign key (created_by) references profiles(id) on delete set null;

-- De-dup by name (case-insensitive) so "Smart India Hackathon 2026" typed by
-- two different people resolves to the same row instead of forking the team
-- listings across duplicates.
create unique index if not exists hackathons_name_lower_idx on hackathons (lower(name));

drop policy if exists hackathons_insert on hackathons;
drop policy if exists hackathons_update on hackathons;
drop policy if exists hackathons_delete on hackathons;

create policy hackathons_insert on hackathons for insert
  with check (created_by = auth.uid() or created_by is null);
create policy hackathons_update on hackathons for update
  using (created_by = auth.uid() or is_admin(auth.uid()))
  with check (created_by = auth.uid() or is_admin(auth.uid()));
-- Delete is admin-only: a hackathon is shared reference data once anyone
-- else has posted a team requirement against it, so the original poster
-- deleting it would silently orphan other people's posts.
create policy hackathons_delete on hackathons for delete
  using (is_admin(auth.uid()));

-- Atomic find-or-create so concurrent "type a new hackathon name" posts
-- resolve to one row instead of racing each other into duplicates.
create or replace function get_or_create_hackathon(p_name text, p_event_date date default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_name text := trim(p_name);
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;
  if v_name = '' then
    raise exception 'hackathon name is required';
  end if;

  select id into v_id from hackathons where lower(name) = lower(v_name);
  if v_id is not null then
    return v_id;
  end if;

  insert into hackathons (name, event_date, created_by)
  values (v_name, p_event_date, auth.uid())
  on conflict ((lower(name))) do nothing
  returning id into v_id;

  if v_id is null then
    -- Lost the insert race to a concurrent caller; the row now exists.
    select id into v_id from hackathons where lower(name) = lower(v_name);
  end if;

  return v_id;
end;
$$;
