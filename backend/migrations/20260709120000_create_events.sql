-- 20260709120000_create_events.sql
-- Calendar events. Forward-only; never edit after it has run somewhere — add a new
-- migration instead. Conventions: docs/database.md.
--
-- Unlike contacts, this table grants anon SELECT only — no direct insert/update/delete
-- policies. An event plus its attendees is a MULTI-TABLE write, so it goes through the
-- SECURITY DEFINER RPCs in the event-write-rpcs migration (database.md #1/#2, atomic).
-- Those functions run as the table owner and bypass RLS for the controlled write, so
-- the client never needs direct write access here.
--
-- Times are a plain date + two `time` values + an all_day flag (NOT timestamptz): no
-- auth, single user, all local — this dodges timezone complexity we don't need yet.
-- Trade-off: single-day, non-overnight events only (the CHECK requires end_time >
-- start_time on the same date). Revisit with timestamptz if overnight / multi-timezone
-- events ever matter.

create table public.events (
  id          uuid        primary key default gen_random_uuid(),
  title       text        not null check (length(trim(title)) > 0),
  event_date  date        not null,
  all_day     boolean     not null default false,
  start_time  time,
  end_time    time,
  location    text,
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,                        -- soft-delete: NULL = live row
  -- All-day events carry no times; timed events need both, end strictly after start.
  constraint events_time_valid check (
    (all_day and start_time is null and end_time is null)
    or
    (not all_day and start_time is not null and end_time is not null and end_time > start_time)
  )
);

-- keep updated_at honest on every mutation (reuse the shared fn from the contacts migration)
create trigger events_set_updated_at
  before update on public.events
  for each row
  execute function public.set_updated_at();

-- RLS on in the same migration as the table (database.md #5)
alter table public.events enable row level security;

create policy events_select on public.events
  for select to anon, authenticated
  using (deleted_at is null);

-- No insert/update/delete policy on purpose: every write goes through the SECURITY
-- DEFINER RPCs (create_event / update_event / soft_delete_event), which run as the
-- table owner and bypass RLS. Anon gets SELECT only (for reads + the attendee embed).

grant select on public.events to anon, authenticated;
