-- 20260710120300_events_rpc_add_type.sql
-- Slice 3 of event types: let create_event / update_event assign a type.
--
-- events.type_id already exists (20260710120100). Here the two write RPCs gain a trailing
-- `p_type_id uuid default null` and write it to type_id.
--
-- Why DROP + recreate (not `create or replace`): a function is identified by name + its
-- argument TYPES. Adding a parameter — even a defaulted one — is a NEW signature, so
-- `create or replace` would leave the old 8-arg overload in place alongside the new 9-arg
-- one. With both present, a PostgREST named-arg call could hit PGRST203 ("could not choose
-- the best candidate function"). Dropping the exact old signatures first avoids that.
--
-- DROP also removes the grants, so we re-`grant execute` on the new signatures below. And
-- because the client now always sends p_type_id, PostgREST resolves the NEW signature — so
-- this file ends with `notify pgrst, 'reload schema'` to refresh PostgREST's cached schema.
-- Without it, create/edit would 404 (PGRST202) in prod between deploy and a manual reload:
-- deploy-homebase.sh applies SQL over psql but never restarts/reloads PostgREST. (Earlier
-- RPC migrations got away without it only because they first ran on a fresh DB, via
-- init.sh, before PostgREST had started.)
--
-- (Still no auth.uid() ownership checks — GoTrue is deferred; add them with the auth slice,
-- alongside the hardening tracked in issue #3.)

drop function if exists public.create_event(text, date, boolean, time, time, text, text, uuid[]);
drop function if exists public.update_event(uuid, text, date, boolean, time, time, text, text, uuid[]);

-- create -------------------------------------------------------------------
create or replace function public.create_event(
  p_title      text,
  p_event_date date,
  p_all_day    boolean,
  p_start_time time,
  p_end_time   time,
  p_location   text,
  p_notes      text,
  p_attendees  uuid[],
  p_type_id    uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.events (title, event_date, all_day, start_time, end_time, location, notes, type_id)
  values (
    trim(p_title),
    p_event_date,
    coalesce(p_all_day, false),
    case when coalesce(p_all_day, false) then null else p_start_time end,
    case when coalesce(p_all_day, false) then null else p_end_time end,
    nullif(trim(p_location), ''),
    nullif(trim(p_notes), ''),
    p_type_id
  )
  returning id into v_id;

  -- unnest(NULL) and unnest('{}') both yield zero rows, so this is a safe no-op when
  -- there are no attendees. on conflict do nothing dedupes repeated ids.
  insert into public.event_attendees (event_id, contact_id)
  select v_id, a from unnest(p_attendees) as a
  on conflict do nothing;

  return v_id;
end;
$$;

-- update -------------------------------------------------------------------
create or replace function public.update_event(
  p_id         uuid,
  p_title      text,
  p_event_date date,
  p_all_day    boolean,
  p_start_time time,
  p_end_time   time,
  p_location   text,
  p_notes      text,
  p_attendees  uuid[],
  p_type_id    uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.events set
    title      = trim(p_title),
    event_date = p_event_date,
    all_day    = coalesce(p_all_day, false),
    start_time = case when coalesce(p_all_day, false) then null else p_start_time end,
    end_time   = case when coalesce(p_all_day, false) then null else p_end_time end,
    location   = nullif(trim(p_location), ''),
    notes      = nullif(trim(p_notes), ''),
    type_id    = p_type_id
  where id = p_id
    and deleted_at is null;

  -- Bail (rolling back the whole call) if the id is unknown or already soft-deleted —
  -- otherwise we'd silently rewrite a hidden event's attendee set and return success.
  if not found then
    raise exception 'event % not found or already deleted', p_id
      using errcode = 'no_data_found';
  end if;

  -- Replace the attendee set. Hard-DELETE of join rows is the annotated exception to
  -- "soft-delete by default" (database.md #4): membership is derived, not a
  -- soft-deletable entity with its own history.
  delete from public.event_attendees where event_id = p_id;

  insert into public.event_attendees (event_id, contact_id)
  select p_id, a from unnest(p_attendees) as a
  on conflict do nothing;

  return p_id;
end;
$$;

grant execute on function public.create_event(text, date, boolean, time, time, text, text, uuid[], uuid)
  to anon, authenticated;
grant execute on function public.update_event(uuid, text, date, boolean, time, time, text, text, uuid[], uuid)
  to anon, authenticated;

-- Refresh PostgREST's schema cache so the new signatures resolve immediately (see header).
notify pgrst, 'reload schema';
