-- 20260709120200_event_write_rpcs.sql
-- The event write path. An event and its attendees are a multi-table write, so per
-- database.md #1/#2 they go through a single SECURITY DEFINER function (atomic rollback
-- on failure), never multi-step client calls. These run as the table owner and so
-- bypass RLS for the controlled write — which is why events / event_attendees grant
-- anon SELECT only, with no direct insert/update.
--
-- (No auth.uid() ownership checks yet — GoTrue is deferred. Add them with the auth
-- slice, alongside the contacts hardening tracked in issue #3.)

-- create -------------------------------------------------------------------
create or replace function public.create_event(
  p_title      text,
  p_event_date date,
  p_all_day    boolean,
  p_start_time time,
  p_end_time   time,
  p_location   text,
  p_notes      text,
  p_attendees  uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.events (title, event_date, all_day, start_time, end_time, location, notes)
  values (
    trim(p_title),
    p_event_date,
    coalesce(p_all_day, false),
    case when coalesce(p_all_day, false) then null else p_start_time end,
    case when coalesce(p_all_day, false) then null else p_end_time end,
    nullif(trim(p_location), ''),
    nullif(trim(p_notes), '')
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
  p_attendees  uuid[]
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
    notes      = nullif(trim(p_notes), '')
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

-- soft delete --------------------------------------------------------------
-- Single-table, but still a function for the same reason as soft_delete_contact: a
-- direct REST UPDATE that sets deleted_at fails the SELECT policy on PostgREST's
-- RETURNING re-check (42501). A SECURITY DEFINER function bypasses that.
create or replace function public.soft_delete_event(p_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.events
     set deleted_at = now()
   where id = p_id
     and deleted_at is null;
$$;

grant execute on function public.create_event(text, date, boolean, time, time, text, text, uuid[])
  to anon, authenticated;
grant execute on function public.update_event(uuid, text, date, boolean, time, time, text, text, uuid[])
  to anon, authenticated;
grant execute on function public.soft_delete_event(uuid)
  to anon, authenticated;
